# Uses

Edit `index.md`. Activate tools with `devenv shell` at the repository root, then
from this directory run `make setup` to install locked dependencies, `make build`
to build, or `make dev` to watch and serve on port 8081. `make check` (also
`make lint`) checks site content and routing. See [development setup](../../docs/development.md)
for first-time activation.

`build.mjs` renders the Markdown into one HTML file with inline styles; there is
no application server or client JavaScript. The same build publishes `index.md`
from the source (with its canonical URL), adds discovery links to HTML, and copies
this directory’s editable `llms.txt` unchanged. Run `npm ci && npm run build` for
a standalone build in `dist/`, or pass an output directory to `node build.mjs`.
Generated files are ignored by Git.

The build uses the shared footer from `sites/shared/footer`, with Uses selected in
navigation. The inline styles in `build.mjs` match the homepage's system typography
and Nordic blue light palette. A `prefers-color-scheme: dark` media query applies
the homepage's dark surface and amber accents automatically, including the shared
footer, link states, and list markers. Print retains the light palette.

Level-two Markdown headings create sections and the category navigation.
Section labels sit beside their content on desktop and stack above it on mobile.
The layout supports light and dark system preferences, with no client JavaScript.
