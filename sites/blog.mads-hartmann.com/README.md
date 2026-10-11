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

Markdown output is provided by [jekyll-md](https://github.com/dblock/jekyll-md),
pinned to the 0.2 release series in the blog's Gemfile and lockfile. It is enabled
in `src/_config.yml`; `md.selector` scopes conversion to `.site`, and `md.strip`
removes scripts, comments, and media embeds (recordings have ordinary links in
the text). The gem adds HTML discovery links and produces Markdown during normal
Jekyll builds and development previews, including HTML pages and collections.
`src/_layouts/markdown.liquid` adds the canonical HTML URL.

The gem follows its own URL convention: `/` becomes `/index.md`, a directory page
such as `/talks/` becomes `/talks.md`, and dated `.html` permalinks become `.md`.
CloudFront's blog routing and this directory's `llms.txt` use the same convention.
Links inside the Markdown retain their source targets; the linked HTML pages
advertise their own Markdown versions.

The editable guide remains `llms.txt` in this directory. The small
`src/_plugins/llms.rb` generator registers it as a normal Jekyll static file,
so it is copied unchanged in production and development builds. It does not
generate Markdown; that belongs entirely to the upstream gem. The
`make dev` watcher includes the guide; restart a manually launched Jekyll server after
editing the file outside `src/`.

A direct Jekyll build produces all outputs:

```sh
bundle exec jekyll build --source src --destination dist
bundle exec ruby test/markdown_output_test.rb
```
