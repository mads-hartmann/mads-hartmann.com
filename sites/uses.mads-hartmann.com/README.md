# Uses

Edit `index.md`. Run `scripts/build.sh uses` from the repository root.
`build.mjs` renders the Markdown into one HTML file with inline styles; there is
no application server or client JavaScript. Generated files are ignored by Git.

The build uses the shared header from `sites/shared/header`, with Uses selected in
navigation. Its semantic color palette is defined in the inline `:root` styles in
`build.mjs`, matching the homepage's green palette.
