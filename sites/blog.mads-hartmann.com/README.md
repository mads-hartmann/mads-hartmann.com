# Blog

Jekyll builds HTML and Markdown pages from `src`. The root development environment
provides Ruby, Bundler and Node.

## Edit

- Posts: `src/_posts/YYYY-MM-DD-title.md`; use an existing post's front matter as a starting point.
- Drafts: `src/_drafts`.
- Book reviews: `src/_book_reviews`.
- Layouts and includes: `src/_layouts` and `src/_includes`.
- Styles: `src/css/index.scss` and `src/_sass`.
- Site settings: `src/_config.yml`.
- Published content guide: `llms.txt`.

Site navigation and contact links come from the [shared footer](../shared/footer/README.md).

## Preview

Complete [first-time setup](../../docs/development.md#first-time-setup), then run
from the repository root:

```sh
devenv shell
cd sites/blog.mads-hartmann.com
make dev
```

Open http://localhost:4000. The server installs locked gems as needed, includes
drafts, and restarts when source files, `llms.txt` or the shared footer change.
Preview output goes to `.build/blog-preview` at the repository root. Stop it with Ctrl-C.

## Build and check

From this directory, inside the root devenv shell:

```sh
make build
make check
```

Production output goes to `.build/blog` at the repository root and excludes drafts.
`make check` builds and checks all three sites. See
[validation](../../docs/development.md#validation) for check scope and
[routing](../../docs/deployment.md#routing) for production redirects.

## Fonts

The blog self-hosts Muli 2.100, preserving the original Google Fonts design and
the six requested faces: weights 200, 400, and 700, upright and italic. Three
weight declarations share one variable font per style, so browsers download at
most two font files per page; only upright is preloaded. The discrete face
declarations preserve the original weight matching (including 300 mapping to
200), rather than introducing new intermediate weights.
`font-display: swap` keeps text visible during the first download. Production
builds fingerprint both the CSS font URLs and the preload through the shared
asset pipeline, enabling immutable caching without duplicate font downloads.

The checked-in WOFF2 files retain outlines, kerning, and layout features; legacy
TrueType hinting instructions are removed to reduce size. Small text may rasterize
slightly differently on systems that use these instructions. Their
Western Latin subset includes Danish letters, common accented letters,
combining accents, punctuation, arrows, and comparison symbols. Characters
outside this coverage use the existing sans-serif fallback. If a new language
needs additional Muli glyphs, regenerate the font files with broader coverage
and update the `unicode-range` declarations in `src/_sass/fonts.scss`. The subset covers
all Muli-supported non-code characters in the current published pages.

The font files were generated once from the upright and italic variable TTFs in
[Google Fonts revision 1afe120](https://github.com/google/fonts/tree/1afe12072a7fff0c8eaacb36fa4c8c722192d5e7/ofl/muli),
before the Mulish redesign, using FontTools 4.61.1 and Brotli 1.2.0. Subsetting
used the Unicode ranges in `src/_sass/fonts.scss`, removed hinting, and retained
the original variation axis. The SIL Open Font License is distributed alongside
the fonts in `src/fonts/OFL.txt`. Builds use the committed WOFF2 files directly;
no font generation tooling or access to Google Fonts is required.

## Markdown output

[jekyll-md](https://github.com/dblock/jekyll-md) generates Markdown during builds
and previews. Configure conversion in `src/_config.yml`; `src/_layouts/markdown.liquid`
adds the canonical HTML URL. The `src/_plugins/llms.rb` plugin copies `llms.txt`
unchanged. Restart a manually launched Jekyll server after editing that guide;
`make dev` watches it automatically.

`src/_plugins/agent_markdown.rb` extends jekyll-md's converter to separate archive
titles from dates, resolve links and image URLs against the canonical page, and
link directly to Markdown for published blog pages. It builds the link map from
Jekyll's eligible pages, so assets and external URLs aren't given invented `.md`
paths. Fragment links retain canonical HTML targets because custom heading IDs
aren't portable between Markdown renderers. Footnotes become native Markdown
references and definitions, including formatted or multi-paragraph notes. These
changes apply only to Markdown; HTML and code sample contents are preserved.

See [Markdown and agent discovery](../../docs/deployment.md#markdown-and-agent-discovery)
for URL conventions, discovery links and content negotiation.

## Article images

Use a literal source path as the first argument to the image include:

```liquid
{% include image.html src="/images/example.png" alt="Describe the screenshot" %}
{% include image.html src="/images/example-detail.png" alt="Describe the detail" loading="lazy" %}
```

The Jekyll generator finds these includes in pages and posts and invokes the locked
Sharp dependency to generate high-quality WebP variants from 320 to 1536 pixels wide
(without upscaling). This covers the article's 768px maximum width at 2x density.
The include supplies intrinsic dimensions, responsive `srcset`/`sizes`, and async
decoding. Its `sizes` mirrors the container breakpoints in `src/css/index.scss`;
update both together if the article layout changes. Keep the first visible image
eager (the default), and explicitly mark images well below the fold as lazy.
Browsers choose how far ahead to fetch lazy images; it is not an exact fold cutoff.

Use `link=true` to link a screenshot to its original full-resolution file.
Original images and existing links to them remain unchanged. Generated images live
in ignored `.build/blog-images` and are copied by Jekyll into the site artifact.
`make setup` and production builds install the locked Node dependency as well as
the gems. Run `make setup` before invoking Jekyll directly. Development watches the
image builder and Node manifests too. `make check` validates the generated image
files, dimension descriptors, aspect ratios, and first-image loading policy.
