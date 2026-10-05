# Homepage

Edit `src/index.html`. It is the complete page, including CSS, favicon and portrait.
There is no framework, runtime JavaScript, font download or theme control.

Run `scripts/build.sh homepage` from the repository root. Terraform uploads only
`.build/homepage/index.html`; CloudFront handles redirects and HTTP error responses.
