# Shared header

The homepage and blog use the same static header. Edit `header.html` for the brand,
`header.css` for its appearance, and the `links` array in `render.mjs` for navigation.
`portrait.jpg` is a 96px thumbnail of the existing blog portrait, embedded as a data
URL so the header needs no image request.

`renderHeader('home' | 'blog' | 'about' | 'uses')` returns ordinary HTML containing
a Declarative Shadow DOM template. There is no browser JavaScript or custom-element
registration. The browser creates the shadow tree while parsing the page and scopes
the stylesheet to that tree. Light-DOM navigation provides a fallback for browsers
without Declarative Shadow DOM. Only one navigation is visible in either case.

The Node homepage build inserts the rendered header at `<!-- shared-header -->`.
The Jekyll plugin calls `node sites/shared/header/render.mjs` to get the same headers
as JSON and exposes them through `site.data.shared_headers`. Other site generators
can call the renderer or consume its JSON output; the template has no Jekyll syntax.

The host is `<mh-site-header>` inside a semantic `<header>` landmark. Navigation
uses native links, a visible keyboard focus outline, and `aria-current`. All URLs
are absolute so they work across domains and on nested blog pages. The Blog link
uses `aria-current="location"` for the blog section; Home and About use `page`.

The header consumes a fixed set of semantic color properties. Each site defines
its palette on `:root`; the values inherit through the shadow boundary. Every
header color uses these properties, with homepage colors as defaults when omitted.

| Property | Role | Default |
| --- | --- | --- |
| `--mh-color-surface` | Header background | `#faf9f6` |
| `--mh-color-text` | Brand and navigation text | `#292923` |
| `--mh-color-border` | Bottom divider | `#e3e2db` |
| `--mh-color-accent` | Keyboard focus outline; also used for site links | `#375a42` |
| `--mh-color-accent-subtle` | Active navigation background | `#e7ece5` |
| `--mh-color-on-accent-subtle` | Text on the active navigation background | `#375a42` |

For example, a site can define a red palette in its own stylesheet:

```css
:root {
  --mh-color-surface: #fff;
  --mh-color-text: #2e303a;
  --mh-color-border: #e0dedd;
  --mh-color-accent: #ad141e;
  --mh-color-accent-subtle: #f8e5e7;
  --mh-color-on-accent-subtle: #ad141e;
}
```

These properties can also be overridden on `mh-site-header` to scope a palette to
one instance. Foreground/background pairs are separate so a site can choose legible
colors for each surface. Use the same semantic properties in other shared components.
The header's layout and selectors remain inside its shadow tree.

`--mh-header-width` controls the maximum content width. The header sets its own
system font, wraps into two rows on mobile, and is hidden for print.

Run `scripts/build.sh` and `node scripts/check-sites.mjs` from the repository root.
Changes are incorporated into both sites at build time, so deploy both after edits.
