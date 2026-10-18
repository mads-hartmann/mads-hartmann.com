# Uses

A Markdown page rendered as HTML with inline styles and no browser JavaScript.

## Edit

Edit `index.md` for content. Level-two headings create sections and category
navigation. Edit `build.mjs` for the HTML template and styles; dark mode follows
the system preference, and print uses the light palette.
Update the explicit **Content updated** date in `index.md` when changing the
inventory. It appears in both HTML and Markdown and records content edits, not
builds, deployments, or a claim that the equipment was re-reviewed. Its initial
value is the date of the last existing inventory edit (11 October 2026).
Site navigation and contact links come from the [shared footer](../shared/footer/README.md).

Edit `llms.txt` for the published guide to the site's content.
`robots.txt` permits crawling and points to `sitemap.xml`, which lists the canonical
Uses page. Keep those files in sync if the site gains more pages.

## Preview

Complete [first-time setup](../../docs/development.md#first-time-setup), then run
from the repository root:

```sh
devenv shell
cd sites/uses.mads-hartmann.com
make dev
```

Open http://localhost:8081. The server installs locked dependencies as needed and
rebuilds when source files or the shared footer change. Stop it with Ctrl-C.

## Build and check

From this directory, inside the root devenv shell:

```sh
make build
make check
```

`build.mjs` produces `index.html`, publishes `index.md` with its canonical URL,
and copies `llms.txt`, `robots.txt`, and `sitemap.xml` unchanged into `.build/uses`
at the repository root.
For a standalone build into local `dist/`, run `npm ci && npm run build`.

`make check` builds and checks all four sites. See
[validation](../../docs/development.md#validation) for check scope and
[deployment](../../docs/deployment.md) for production routing and Markdown negotiation.
