"""Import Nix tools and dependency metadata from the repository's shared pins."""

load("@rules_nixpkgs_core//:nixpkgs.bzl", "nixpkgs_package")

def _tools_impl(_ctx):
    for name, output in {
        "node": "bin/node",
        "python": "bin/python3",
        "actionlint": "bin/actionlint",
        "homepage": "tool.json",
        "uses": "tool.json",
        "computer": "tool.json",
        "blog": "tool.json",
        "checks": "tool.json",
    }.items():
        deps = ["//:devenv.yaml", "//:dev/shared/versions.nix", "//dev/bazel:nixpkgs.nix"]
        if output == "tool.json":
            deps += ["//:scripts/" + f for f in ["package.json", "package-lock.json"]]
        if name in ["homepage", "uses", "computer", "blog"]:
            directory = "mads-hartmann.com" if name == "homepage" else name + ".mads-hartmann.com"
            deps += ["//:sites/" + directory + "/" + f for f in ["package.json", "package-lock.json"]]
        if name == "blog":
            deps += ["//:sites/blog.mads-hartmann.com/" + f for f in ["Gemfile", "Gemfile.lock", "gemset.nix"]]
        nixpkgs_package(
            name = "nix_" + name,
            repository = "//dev/bazel:nixpkgs.nix",
            nix_file = "//dev/bazel:tools.nix",
            nix_file_deps = deps,
            attribute_path = name,
            nixopts = ["--extra-experimental-features", "nix-command flakes"],
            build_file_content = 'exports_files(["%s"], visibility = ["//visibility:public"])' % output,
        )

tools = module_extension(implementation = _tools_impl)
