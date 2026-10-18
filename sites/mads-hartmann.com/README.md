# Homepage

A single HTML page with inline styles and no browser JavaScript.

## Edit

Edit `src/index.html` for content, styles and the favicon. The `--mh-color-*`
properties define the palette; dark mode follows the system preference, and print
uses the light palette. The build inserts the [shared footer](../shared/footer/README.md)
at `<!-- shared-footer -->`.

Edit `llms.txt` for the published guide to the site's content.
`robots.txt` permits crawling and points to `sitemap.xml`, which lists the canonical
homepage. Keep those files in sync if the site gains more pages.

## Preview

Complete [first-time setup](../../docs/development.md#first-time-setup), then run
from the repository root:

```sh
devenv shell
cd sites/mads-hartmann.com
make dev
```

Open http://localhost:8080. The server rebuilds when source files or the shared
footer change. Stop it with Ctrl-C.

## Build and check

From this directory, inside the root devenv shell:

```sh
make build
make check
```

`build.mjs` produces `index.html`, generates `index.md` from the main content,
and copies `llms.txt`, `robots.txt`, and `sitemap.xml` unchanged into `.build/homepage`
at the repository root.
For a standalone build into local `dist/`, run `npm ci && npm run build`.

`make check` builds and checks all four sites. See
[validation](../../docs/development.md#validation) for check scope and
[deployment](../../docs/deployment.md) for production routing and Markdown negotiation.
