# Computer

How I set up my Mac. `index.md` is v4: a single-page setup reference for a person or agent, with
installation preferences and configuration snippets for the shell, Git, and
macOS keyboard shortcuts, plus a link to 1Password for SSH key management. The software inventory
lives on [Uses](https://uses.mads-hartmann.com/).

`v1.md`, `v2.md`, and `v3.md` preserve the historical notes recovered from
`35ab080^`, immediately before the AWS migration removed this site. The v3
archive retains the HTML and heading IDs from the Notion export. V4 follows
v3's stated preference to return to Homebrew for system-wide packages.

Edit the Markdown files directly. The old Notion sync and its generated-file
warning are retired; building needs no Notion credentials.

Activate the root `devenv shell`, then use `make build`, `make check`, or
`make dev` from this directory. The development server runs on port 8082.
See [development setup](../../docs/development.md) for activation and validation.
`npm ci && npm run build` also produces a standalone build in `dist/`.

Like Uses, `build.mjs` renders Markdown into self-contained HTML with inline
styles, responsive sections, system dark mode, and the shared static footer.
Code blocks and tables scroll within the content column on small screens.
There is no client JavaScript or application server.

The build publishes a Markdown alternative for each page and copies the tracked
`llms.txt`, `robots.txt`, and `sitemap.xml`. The guide in `llms.txt` separates the
current baseline from the archives. Keep discovery files in sync with page changes.
CloudFront supports `Accept: text/markdown` and the original archive URL forms.

The Computer Terraform stack follows the same private S3/CloudFront/DNS setup
as Uses. Apply the manual kernel changes before deploying this new stack to
create its OIDC roles and GitHub variables; see [deployment](../../docs/deployment.md).

## Content sources

The current page consolidates setup preferences from v3 and the dotfiles repositories:

- [gitpod-dotfiles](https://github.com/mads-hartmann/gitpod-dotfiles): Git aliases,
  automatic upstream setup and current fzf integration.
- [dotfilesv2](https://github.com/mads-hartmann/dotfilesv2): Git pull/pager defaults,
  unstaging, personal scripts, GNU sed, and macOS text keybindings.
- [dotfiles](https://github.com/mads-hartmann/dotfiles): Git history aliases
  and fzf shortcuts.

V4 adapts Homebrew paths for Apple Silicon and Intel and uses current fzf
integration. Historical version navigation stays on the archive pages.
