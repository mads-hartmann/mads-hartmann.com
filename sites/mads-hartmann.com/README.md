# Homepage

Edit `src/index.html` for the page content, CSS and favicon. The build replaces
`<!-- shared-footer -->` with the footer from `sites/shared/footer`.
There is no framework, runtime JavaScript, font download or theme control.

Home includes the introduction, work history and education formerly split across
Home and the blog's About page, followed by social and contact links.

Activate tools with `devenv shell` at the repository root, then from this
directory run `make build` to build, `make dev` to watch and serve on port 8080,
or `make check` (also `make lint`) to check site content and routing.
See [development setup](../../docs/development.md) for first-time activation.

Terraform uploads only
`.build/homepage/index.html`; CloudFront handles redirects and HTTP error responses.
