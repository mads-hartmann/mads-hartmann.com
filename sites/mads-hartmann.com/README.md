# Homepage

Edit `src/index.html` for the page content, CSS and favicon. The build replaces
`<!-- shared-header -->` with the header from `sites/shared/header`.
There is no framework, runtime JavaScript, font download or theme control.

Home includes the introduction, work history and education formerly split across
Home and the blog's About page, followed by social and contact links.

From this directory, run `devenv shell` to activate tools, `devenv tasks run
homepage:build` to build, or `devenv up` to watch and serve on port 8080.
See [development setup](../../docs/development.md) for first-time activation.

Terraform uploads `.build/homepage/index.html`, its generated `index.md`, and
`llms.txt`. CloudFront handles content negotiation, redirects, and HTTP errors.
