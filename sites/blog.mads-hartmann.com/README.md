# blog.mads-hartmann.com

Requires Node 24 as well as Ruby and Bundler. The Jekyll plugin invokes the shared
header renderer once per build; the default layout selects the Blog version.
It works with both `scripts/build.sh blog` and Jekyll's development server.

The former About content lives on Home. CloudFront redirects `/about`, `/about/`
and `/about/index.html` to `https://www.mads-hartmann.com/`.

Redirects for Home and Blog are grouped by site in `routing/redirects.json` and
embedded into their CloudFront functions by `scripts/build-routing.mjs`.

```sh
cd sites/blog.mads-hartmann.com
devenv shell
devenv up
```

Activation installs the locked gems automatically. The server watches changes,
includes drafts, and listens on port 4000. `devenv tasks run blog:build` produces
the production artifact. See [development setup](../../docs/development.md) for
first-time activation and tool versions.

The devenv server also restarts after editing `sites/shared/header`, which is
outside Jekyll's watched source directory.
