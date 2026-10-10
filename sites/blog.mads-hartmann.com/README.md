# blog.mads-hartmann.com

Requires Node 24 as well as Ruby and Bundler. The Jekyll plugin invokes the shared
footer renderer once per build; the default layout selects the Blog version.
It works with both `scripts/build.sh blog` and Jekyll's development server.

The former About content lives on Home. CloudFront redirects `/about`, `/about/`
and `/about/index.html` to `https://www.mads-hartmann.com/`.

Redirects for Home and Blog are grouped by site in `routing/redirects.json` and
embedded into their CloudFront functions by `scripts/build-routing.mjs`.

```sh
devenv shell # from the repository root
cd sites/blog.mads-hartmann.com
make dev
```

`make setup`, `make build`, and `make dev` install the locked gems as needed.
The server watches changes, includes drafts, and listens on port 4000.
`make build` produces the production artifact. See [development setup](../../docs/development.md) for
first-time activation and tool versions.

`make check` (also `make lint`) checks site content and routing.

The development server also restarts after editing `sites/shared/footer`, which is
outside Jekyll's watched source directory.

Markdown output belongs to Jekyll. `markdown_output` in `src/_config.yml` enables
`src/_plugins/markdown_output.rb`, which emits a `.md` sibling for every HTML
page, post, and output collection document. It converts the rendered main content
with `reverse_markdown`, preserving Liquid output, titles, dates, code, and media
links. The default layout advertises the Markdown alternative. Jekyll writes and
cleans up both representations, including in development previews with drafts.

The `llms_txt` setting points to this directory's tracked `llms.txt`, which Jekyll
publishes unchanged at the site root. The devenv watcher includes it; restart a
manually launched Jekyll server after editing this file outside `src/`.

A direct Jekyll build produces all three outputs without a root build step:

```sh
bundle exec jekyll build --source src --destination dist
bundle exec ruby test/markdown_output_test.rb
```
