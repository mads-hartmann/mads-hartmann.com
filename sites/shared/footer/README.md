# Shared footer

Home, Blog and Uses render the same footer at build time. Edit `footer.html` for
its structure, `footer.css` for its appearance, and the site/social link arrays in
`render.mjs` for navigation. There is no browser JavaScript or image dependency.

`renderFooter('home' | 'blog' | 'uses')` returns a semantic `<footer>` containing
`<mh-site-footer>` with a Declarative Shadow DOM template. The browser creates the
shadow tree and scopes the CSS while parsing. Identical light-DOM content provides
a fallback for browsers without Declarative Shadow DOM; only one copy is visible.

The homepage build replaces `<!-- shared-footer -->`. The Uses Markdown build
calls `renderFooter('uses')`. Jekyll's `shared_footer.rb` invokes the same renderer
as a CLI, reads its JSON output, and exposes `site.data.shared_footers.blog` to the
default layout. Every blog layout inherits that footer.

Site links are absolute so they work across domains and from nested articles.
Home and Uses use `aria-current="page"`; Blog uses `aria-current="location"` for
its entire section. Explore and Elsewhere are separately labelled navigation
landmarks, links have visible keyboard focus, and the footer is hidden for print.

The footer inherits semantic palette properties across the shadow boundary:

| Property | Default | Use |
| --- | --- | --- |
| `--mh-color-text` | `#292923` | Name and navigation |
| `--mh-color-muted` | `#626258` | Group headings |
| `--mh-color-border` | `#e3e2db` | Divider |
| `--mh-color-accent` | `#375a42` | Email, active underline and focus |

`--mh-footer-width` defaults to `632px`, and `--mh-footer-gutter` to `24px` per
side. The blog places its footer inside the content container and overrides these
with `100%` and `0px` so the divider aligns with the articles. Below 600px the name
and email occupy a full row above the two navigation groups.

Home starts with its introduction and links to Blog and Uses. Blog starts with its
title and Highlights, with a small blog-root link on other pages. Uses starts with
its title and description. Site switching and social/contact links live here,
replacing the former shared header and separate Elsewhere/contact sections.

Run `scripts/build.sh` and `node scripts/check-sites.mjs` from the repository root.
Footer changes are included in all three builds, so deploy all affected sites.
