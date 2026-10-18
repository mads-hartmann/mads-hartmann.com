"""Small artifact rules for the existing site generators and checks."""

def _site_impl(ctx):
    output = ctx.actions.declare_directory(ctx.label.name + ".content")
    ctx.actions.run(
        executable = ctx.file._python,
        arguments = [ctx.file._builder.path, ctx.attr.site, output.path, ctx.file.runtime.path] +
                    [f.path for f in ctx.files.srcs],
        inputs = ctx.files.srcs + [ctx.file._builder],
        tools = [ctx.file.runtime],
        outputs = [output],
        env = {"TZ": "UTC", "LANG": "C.UTF-8"},
        execution_requirements = {"no-remote-exec": "1"},
        mnemonic = "SiteBuild",
        progress_message = "Building %s with Nix tools" % ctx.attr.site,
    )
    return [DefaultInfo(files = depset([output]))]

site_build = rule(
    implementation = _site_impl,
    attrs = {
        "site": attr.string(mandatory = True),
        "srcs": attr.label_list(allow_files = True),
        "runtime": attr.label(allow_single_file = True, mandatory = True, cfg = "exec"),
        "_python": attr.label(default = "@nix_python//:bin/python3", allow_single_file = True, cfg = "exec"),
        "_builder": attr.label(default = "//:scripts/bazel-build-site.py", allow_single_file = True),
    },
)

def _routing_impl(ctx):
    output = ctx.actions.declare_file("routing/" + ctx.attr.site + ".js")
    ctx.actions.run(
        executable = ctx.file._node,
        arguments = [ctx.file._builder.path, ctx.attr.site, output.dirname],
        inputs = ctx.files.srcs + [ctx.file._builder],
        outputs = [output],
        execution_requirements = {"no-remote-exec": "1"},
        mnemonic = "SiteRouting",
    )
    return [DefaultInfo(files = depset([output]))]

site_routing = rule(
    implementation = _routing_impl,
    attrs = {
        "site": attr.string(mandatory = True),
        "srcs": attr.label_list(allow_files = True),
        "_node": attr.label(default = "@nix_node//:bin/node", allow_single_file = True, cfg = "exec"),
        "_builder": attr.label(default = "//:scripts/build-routing.mjs", allow_single_file = True),
    },
)

def _manifest_impl(ctx):
    output = ctx.actions.declare_file("manifests/" + ctx.attr.site + ".json")
    ctx.actions.run(
        executable = ctx.file._python,
        arguments = [
            ctx.file._script.path,
            ctx.attr.site,
            ctx.file.content.path,
            ctx.file.routing.path,
            output.path,
        ] + [f.path for f in ctx.files.infrastructure],
        inputs = [ctx.file._script, ctx.file.content, ctx.file.routing] + ctx.files.infrastructure,
        outputs = [output],
        execution_requirements = {"no-remote-exec": "1"},
        mnemonic = "SiteManifest",
    )
    return [DefaultInfo(files = depset([output]))]

site_manifest = rule(
    implementation = _manifest_impl,
    attrs = {
        "site": attr.string(mandatory = True),
        "content": attr.label(allow_single_file = True, mandatory = True),
        "routing": attr.label(allow_single_file = True, mandatory = True),
        "infrastructure": attr.label_list(allow_files = True),
        "_python": attr.label(default = "@nix_python//:bin/python3", allow_single_file = True, cfg = "exec"),
        "_script": attr.label(default = "//:scripts/site-manifest.py", allow_single_file = True),
    },
)

def _check_impl(ctx):
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")

    # The launcher and all of its tools/data are declared runfiles. The Python
    # harness stages them in TEST_TMPDIR, leaving cached artifacts read-only.
    ctx.actions.write(executable, """#!/bin/sh
set -eu
cd "$TEST_SRCDIR/$TEST_WORKSPACE"
exec '%s' '%s' '%s' '%s' %s
""" % (
        ctx.file._python.short_path,
        ctx.file._harness.short_path,
        ctx.attr.mode,
        ctx.file.runtime.short_path,
        " ".join(["'%s'" % f.short_path for f in ctx.files.data]),
    ), is_executable = True)
    return [DefaultInfo(
        executable = executable,
        runfiles = ctx.runfiles(files = ctx.files.data + [ctx.file.runtime, ctx.file._python, ctx.file._harness]),
    )]

site_test = rule(
    implementation = _check_impl,
    test = True,
    attrs = {
        "mode": attr.string(mandatory = True),
        "data": attr.label_list(allow_files = True),
        "runtime": attr.label(allow_single_file = True, mandatory = True, cfg = "exec"),
        "_python": attr.label(default = "@nix_python//:bin/python3", allow_single_file = True, cfg = "exec"),
        "_harness": attr.label(default = "//:scripts/bazel-check.py", allow_single_file = True),
    },
)
