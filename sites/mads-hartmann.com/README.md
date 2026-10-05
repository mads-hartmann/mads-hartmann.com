# Homepage

Edit `src/index.html` for the page content, CSS and favicon. The build replaces
`<!-- shared-header -->` with the header from `sites/shared/header`.
There is no framework, runtime JavaScript, font download or theme control.

Run `scripts/build.sh homepage` from the repository root. Terraform uploads only
`.build/homepage/index.html`; CloudFront handles redirects and HTTP error responses.
