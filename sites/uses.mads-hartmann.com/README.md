# Uses

Edit `index.md`. From this directory, run `devenv shell` to activate tools and
install locked dependencies, `devenv tasks run uses:build` to build, or `devenv up`
to watch and serve on port 8081. See [development setup](../../docs/development.md)
for first-time activation.

`build.mjs` renders the Markdown into one HTML file with inline styles; there is
no application server or client JavaScript. Generated files are ignored by Git.

The build uses the shared header from `sites/shared/header`, with Uses selected in
navigation. Its semantic color palette is defined in the inline `:root` styles in
`build.mjs`, matching the homepage's green palette.
