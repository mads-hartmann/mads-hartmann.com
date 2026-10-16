"""Offline regression tests for deployment selection and Terraform exit handling."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("changes", ROOT / "scripts/deployment-changes.py")
changes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(changes)


class SelectionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.cwd = Path.cwd()
        os.chdir(self.repo)
        self.addCleanup(os.chdir, self.cwd)
        self.git("init", "-q")
        self.git("config", "user.name", "CI test")
        self.git("config", "user.email", "ci@example.com")
        self.base = self.commit("README.md")
        self.env = {
            "GITHUB_EVENT_NAME": "push", "GITHUB_RUN_ATTEMPT": "1",
            "GITHUB_REPOSITORY": "owner/repo", "GITHUB_RUN_NUMBER": "12",
            "GITHUB_SHA": self.base,
        }
        self.run = {"id": 100, "run_number": 11, "status": "completed",
                    "conclusion": "success", "head_sha": self.base}
        self.jobs = [{"name": f"{site} / apply", "conclusion": "success"}
                     for site in ["shared", *changes.SITES]]

    def git(self, *args):
        return subprocess.check_output(["git", *args], text=True).strip()

    def commit(self, path):
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(target.read_text() + "change\n" if target.exists() else "change\n")
        self.git("add", ".")
        self.git("commit", "-qm", "Test change")
        return self.git("rev-parse", "HEAD")

    def baseline(self, runs=None, jobs=None):
        with patch.object(changes, "github", side_effect=[
            {"workflow_runs": runs if runs is not None else [self.run]},
            {"jobs": jobs if jobs is not None else self.jobs},
        ]) as api:
            result = changes.deployment_base(self.env)
            self.assertIn("event=push", api.call_args_list[0].args[0])
            return result

    def test_input_dependencies(self):
        all_sites = set(changes.SITES)
        cases = {
            "sites/mads-hartmann.com/src/index.html": {"homepage"},
            "sites/blog.mads-hartmann.com/Gemfile.lock": {"blog"},
            "sites/uses.mads-hartmann.com/build.mjs": {"uses"},
            "sites/uses.mads-hartmann.com/package-lock.json": {"uses"},
            "routing/blog.js": {"blog"},
            "terraform/stacks/homepage/.terraform.lock.hcl": {"homepage"},
            "sites/shared/footer/footer.html": all_sites,
            "routing/markdown.js": all_sites,
            "routing/redirects.json": all_sites,
            "terraform/modules/static-site/main.tf": all_sites,
            "terraform/stacks/shared/main.tf": all_sites,
            "scripts/build.sh": all_sites,
            "scripts/smoke-test.py": all_sites,
            ".github/workflows/apply-stack.yml": all_sites,
            "docs/deployment.md": set(),
            "terraform/kernel/main.tf": set(),
        }
        for path, expected in cases.items():
            with self.subTest(path=path):
                parent = self.git("rev-parse", "HEAD")
                head = self.commit(path)
                selected = changes.affected_sites(parent, head)
                self.assertEqual({site for site, value in selected.items() if value}, expected)

    def test_deletions_and_cross_site_renames(self):
        base = self.commit("sites/mads-hartmann.com/src/old.html")
        target = self.repo / "sites/uses.mads-hartmann.com/new.html"
        target.parent.mkdir(parents=True)
        (self.repo / "sites/mads-hartmann.com/src/old.html").rename(target)
        head = self.commit("docs/note.md")
        self.assertEqual(changes.affected_sites(base, head),
                         {"homepage": True, "blog": False, "uses": True})
        target.unlink()
        deleted = self.commit("docs/note.md")
        self.assertTrue(changes.affected_sites(head, deleted)["uses"])

    def test_successful_baseline_ignores_current_and_newer_runs(self):
        head = self.commit("sites/uses.mads-hartmann.com/index.md")
        self.env["GITHUB_SHA"] = head
        runs = [dict(self.run, run_number=13), dict(self.run, run_number=12), self.run]
        self.assertEqual(self.baseline(runs=runs), self.base)

    def test_skipped_sites_remain_a_valid_baseline(self):
        # GitHub can represent a skipped reusable workflow by its caller name.
        jobs = [self.jobs[0], self.jobs[1], {"name": "blog", "conclusion": "skipped"},
                {"name": "uses / apply", "conclusion": "skipped"}]
        self.assertEqual(self.baseline(jobs=jobs), self.base)

    def test_failed_or_incomplete_runs_force_all(self):
        for result in ["failure", "cancelled", "timed_out", None]:
            with self.subTest(result=result):
                self.assertIsNone(self.baseline(runs=[dict(self.run, conclusion=result)]))
        self.assertIsNone(self.baseline(runs=[dict(self.run, status="in_progress")]))

    def test_disabled_or_missing_deployments_are_not_baselines(self):
        self.assertIsNone(self.baseline(jobs=[dict(job, conclusion="skipped") for job in self.jobs]))
        self.assertIsNone(self.baseline(jobs=self.jobs[:1]))
        self.assertIsNone(self.baseline(runs=[]))

    def test_missing_git_history_forces_all(self):
        self.assertIsNone(self.baseline(runs=[dict(self.run, head_sha="a" * 40)]))

    def test_rerun_and_manual_dispatch_bypass_history(self):
        with patch.object(changes, "github") as api:
            self.env["GITHUB_RUN_ATTEMPT"] = "2"
            self.assertIsNone(changes.deployment_base(self.env))
            self.env.update(GITHUB_EVENT_NAME="workflow_dispatch", GITHUB_RUN_ATTEMPT="1")
            self.assertIsNone(changes.deployment_base(self.env))
            api.assert_not_called()

    def test_failed_partial_deployment_followed_by_revert(self):
        self.commit("sites/uses.mads-hartmann.com/index.md")
        self.git("revert", "--no-edit", "HEAD")
        self.env["GITHUB_SHA"] = self.git("rev-parse", "HEAD")
        self.assertFalse(any(changes.affected_sites(self.base, self.env["GITHUB_SHA"]).values()))
        self.assertIsNone(self.baseline(runs=[dict(self.run, conclusion="failure")]))

    def test_outputs_manual_selection_and_api_failure(self):
        for event, stack, expected in [
            ("workflow_dispatch", "uses", {"uses"}),
            ("workflow_dispatch", "shared", set()),
            ("workflow_dispatch", "all", set(changes.SITES)),
            ("push", "", set(changes.SITES)),
        ]:
            with self.subTest(event=event, stack=stack):
                output = self.repo / "outputs"
                output.write_text("")
                env = dict(self.env, GITHUB_EVENT_NAME=event, REQUESTED_STACK=stack,
                           GITHUB_OUTPUT=str(output))
                with patch.dict(os.environ, env), patch.object(changes, "github", side_effect=OSError("offline")):
                    changes.main()
                selected = {line.split("_changed=")[0] for line in output.read_text().splitlines()
                            if line.endswith("=true")}
                self.assertEqual(selected, expected)


class DeployScriptTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        (self.repo / "scripts").mkdir()
        shutil.copy(ROOT / "scripts/deploy-stack.sh", self.repo / "scripts/deploy-stack.sh")
        for site in ["shared", *changes.SITES]:
            (self.repo / f"terraform/stacks/{site}").mkdir(parents=True)
        self.bin = self.repo / "bin"
        self.bin.mkdir()
        fake = self.bin / "fake"
        fake.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
command = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["CALL_LOG"], "a") as log:
    log.write(json.dumps([command, *args]) + "\\n")
if command == "terraform":
    root = Path(args[0].split("=", 1)[1])
    if args[1] == "workspace": print("default")
    if args[1] == "plan":
        (root / "deploy.tfplan").write_text("saved plan")
        sys.exit(int(os.environ["PLAN_STATUS"]))
    if args[1] == "apply": sys.exit(int(os.environ.get("APPLY_STATUS", "0")))
    if args[1] == "output": print("test-" + args[-1])
elif command == "aws":
    if "create-invalidation" in args: print("invalidation-id")
elif command == "python3":
    status = "CACHE_STATUS" if args[0] == "scripts/check-http-cache.py" else "SMOKE_STATUS"
    sys.exit(int(os.environ.get(status, "0")))
'''.replace("#!/usr/bin/env python3", f"#!{os.sys.executable}", 1))
        fake.chmod(0o755)
        for command in ["terraform", "aws", "python3"]:
            (self.bin / command).symlink_to(fake)

    def deploy(self, stack, status, **extra):
        log = self.repo / "calls"
        log.write_text("")
        output = self.repo / "outputs"
        output.write_text("")
        result = subprocess.run(
            ["bash", str(self.repo / "scripts/deploy-stack.sh"), stack],
            env=dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}",
                     CALL_LOG=str(log), PLAN_STATUS=str(status), GITHUB_OUTPUT=str(output), **extra),
            capture_output=True, text=True,
        )
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        self.assertFalse((self.repo / f"terraform/stacks/{stack}/deploy.tfplan").exists())
        return result, calls, output.read_text()

    def test_no_changes_skips_apply_and_invalidation_but_checks_site(self):
        result, calls, _ = self.deploy("uses", 0)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any("apply" in call or call[0] == "aws" for call in calls))
        self.assertIn(["python3", "scripts/smoke-test.py", "uses", "https://test-distribution_domain"], calls)
        self.assertIn(["python3", "scripts/check-http-cache.py", "https://test-distribution_domain"], calls)

    def test_no_changes_still_exports_shared_outputs(self):
        result, calls, output = self.deploy("shared", 0)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output, "changed=false\nzone_id=test-zone_id\ncertificate_arn=test-certificate_arn\n")
        self.assertFalse(any("apply" in call or call[0] in ("aws", "python3") for call in calls))

    def test_shared_changes_signal_downstream_deployments(self):
        result, calls, output = self.deploy("shared", 2)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(any("apply" in call for call in calls))
        self.assertIn("changed=true\n", output)
        self.assertIn("certificate_arn=test-certificate_arn\n", output)

    def test_changes_apply_saved_plan_then_invalidate_and_smoke_test(self):
        result, calls, _ = self.deploy("homepage", 2)
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = next(call for call in calls if "plan" in call)
        self.assertIn("-detailed-exitcode", plan)
        apply = next(call for call in calls if "apply" in call)
        self.assertEqual(apply[-1], "deploy.tfplan")
        invalidation = next(call for call in calls if "create-invalidation" in call)
        wait = next(call for call in calls if "wait" in call)
        self.assertLess(calls.index(apply), calls.index(invalidation))
        self.assertLess(calls.index(invalidation), calls.index(wait))
        smoke = ["python3", "scripts/smoke-test.py", "homepage", "https://test-distribution_domain"]
        cache = ["python3", "scripts/check-http-cache.py", "https://test-distribution_domain"]
        self.assertIn(smoke, calls)
        self.assertIn(cache, calls)
        self.assertLess(calls.index(wait), calls.index(smoke))
        self.assertLess(calls.index(wait), calls.index(cache))

    def test_plan_failure_never_applies_invalidates_or_smoke_tests(self):
        for status in [1, 17]:
            with self.subTest(status=status):
                result, calls, output = self.deploy("blog", status)
                self.assertEqual(result.returncode, status)
                self.assertEqual(output, "")
                self.assertEqual(calls[-1][2], "plan")

    def test_apply_failure_never_invalidates(self):
        result, calls, _ = self.deploy("blog", 2, APPLY_STATUS="1")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(calls[-1][2], "apply")

    def test_no_change_smoke_failure_is_reported(self):
        result, _, _ = self.deploy("homepage", 0, SMOKE_STATUS="1")
        self.assertEqual(result.returncode, 1)

    def test_cache_failure_is_reported_with_or_without_changes(self):
        for status in [0, 2]:
            with self.subTest(plan_status=status):
                result, calls, _ = self.deploy("homepage", status, CACHE_STATUS="1")
                self.assertEqual(result.returncode, 1)
                self.assertIn(["python3", "scripts/check-http-cache.py", "https://test-distribution_domain"], calls)


if __name__ == "__main__":
    unittest.main()
