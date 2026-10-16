# Blog

Jekyll builds HTML and Markdown pages from `src`. The root development environment
provides Ruby, Bundler and Node.

## Edit

- Posts: `src/_posts/YYYY-MM-DD-title.md`; use an existing post's front matter as a starting point.
- Drafts: `src/_drafts`.
- Book reviews: `src/_book_reviews`.
- Layouts and includes: `src/_layouts` and `src/_includes`.
- Styles: `src/css/index.scss` and `src/_sass`.
- Site settings: `src/_config.yml`.
- Published content guide: `llms.txt`.

Site navigation and contact links come from the [shared footer](../shared/footer/README.md).

## Preview

Complete [first-time setup](../../docs/development.md#first-time-setup), then run
from the repository root:

```sh
devenv shell
cd sites/blog.mads-hartmann.com
make dev
```

Open http://localhost:4000. The server installs locked gems as needed, includes
drafts, and restarts when source files, `llms.txt` or the shared footer change.
Preview output goes to `.build/blog-preview` at the repository root. Stop it with Ctrl-C.

## Build and check

From this directory, inside the root devenv shell:

```sh
make build
make check
```

Production output goes to `.build/blog` at the repository root and excludes drafts.
`make check` builds and checks all three sites. See
[validation](../../docs/development.md#validation) for check scope and
[routing](../../docs/deployment.md#routing) for production redirects.

## Markdown output

[jekyll-md](https://github.com/dblock/jekyll-md) generates Markdown during builds
and previews. Configure conversion in `src/_config.yml`; `src/_layouts/markdown.liquid`
adds the canonical HTML URL. The `src/_plugins/llms.rb` plugin copies `llms.txt`
unchanged. Restart a manually launched Jekyll server after editing that guide;
`make dev` watches it automatically.

See [Markdown and agent discovery](../../docs/deployment.md#markdown-and-agent-discovery)
for URL conventions, discovery links and content negotiation.
