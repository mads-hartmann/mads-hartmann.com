# Homepage

Edit `src/index.html` for the page content, CSS and favicon. The build replaces
`<!-- shared-footer -->` with the footer from `sites/shared/footer`.
`build.mjs` also generates `index.md` from the main content, adds discovery links
to HTML, and copies this directory’s editable `llms.txt` unchanged. Its dependencies
and lockfile live here. Run `npm ci && npm run build` for a standalone build in
`dist/`, or pass an output directory to `node build.mjs`.

There is no framework, runtime JavaScript, font download or theme control.

Home includes the introduction, work history and education formerly split across
Home and the blog's About page, followed by social and contact links.

Activate tools with `devenv shell` at the repository root, then from this
directory run `make build` to build, `make dev` to watch and serve on port 8080,
or `make check` (also `make lint`) to check site content and routing.
See [development setup](../../docs/development.md) for first-time activation.

Terraform uploads `.build/homepage/index.html`, its generated `index.md`, and
`llms.txt`. CloudFront handles content negotiation, redirects, and HTTP errors.
