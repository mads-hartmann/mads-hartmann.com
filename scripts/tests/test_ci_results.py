"""The merge gate must fail closed when required checks do not succeed."""
import os
from pathlib import Path
import subprocess
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "check-ci-results.sh"


class CheckResultsTests(unittest.TestCase):
    def check(self, **overrides):
        env = dict(os.environ, BUILD_RESULT="success", TERRAFORM_REQUIRED="true",
                   TERRAFORM_RESULT="success", PLAN_REQUIRED="true", PLAN_RESULT="success")
        env.update(overrides)
        return subprocess.run(["bash", str(SCRIPT)], env=env, capture_output=True, text=True)

    def test_successful_required_jobs_pass(self):
        self.assertEqual(self.check().returncode, 0)

    def test_required_jobs_must_succeed(self):
        for job in ["BUILD", "TERRAFORM", "PLAN"]:
            for result in ["failure", "cancelled", "skipped", "pending", ""]:
                with self.subTest(job=job, result=result):
                    self.assertNotEqual(self.check(**{f"{job}_RESULT": result}).returncode, 0)

    def test_intentionally_skipped_jobs_pass(self):
        for terraform_required in ["true", "false"]:
            for plan_required in ["true", "false"]:
                with self.subTest(terraform=terraform_required, plan=plan_required):
                    result = self.check(
                        TERRAFORM_REQUIRED=terraform_required,
                        TERRAFORM_RESULT="success" if terraform_required == "true" else "skipped",
                        PLAN_REQUIRED=plan_required,
                        PLAN_RESULT="success" if plan_required == "true" else "skipped",
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)

    def test_unexpected_optional_results_fail(self):
        for job in ["TERRAFORM", "PLAN"]:
            for result in ["success", "failure", "cancelled", ""]:
                with self.subTest(job=job, result=result):
                    self.assertNotEqual(self.check(**{
                        f"{job}_REQUIRED": "false", f"{job}_RESULT": result,
                    }).returncode, 0)

    def test_missing_or_invalid_requirements_fail(self):
        for job in ["TERRAFORM", "PLAN"]:
            for required in ["", "unknown"]:
                with self.subTest(job=job, required=required):
                    self.assertNotEqual(self.check(**{f"{job}_REQUIRED": required}).returncode, 0)
