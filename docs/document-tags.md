# The tags of the document for a search engine and for a link

This document gives the design for the `meta` elements in the `head` of the document of a
deck. Issue #566 asked for it. The document records a decision for each of 13 tags, and
the answers to five questions. The code contains the tags that need no address. Its
section "The result" tells what the code has, and "The work that follows" names the
issues for the other tags.

## The problem

The `head` of the document held a `meta charset`, the `title` and the style sheets. For a
deck on a web host, this had three effects:

1. A search engine had no description. Lighthouse 13.6 gave the document 90 for SEO,
   because the audit `meta-description` failed.
2. A link to the deck had no preview. A chat program makes a card for a link from the Open
   Graph tags of the page, and the document had none.
3. The document had no `meta name="viewport"`. Lighthouse gave the insight `viewport` the
   score 0.5.

## The constraints

- **The document names no address of a network.** `Expresso.FontTest` makes sure that the
  document holds no `http://` and no `https://`.
- **A deck is one file.** A tag cannot need a second file, unless the user asks for one.
- **A deck with no host needs no such tag.** Each tag that needs a value from the user
  stays optional.
- **Each default is safe.** A tag does not show a text that the user did not write.

## The decision for each tag

| Tag | Decision | Reason |
| --- | --- | --- |
| `meta name="description"` | Add it with the `description` option of the deck. | The user writes the summary. A deck with no option gets no tag. |
| `meta name="author"` | Add it with the `author` option of the deck. | Only the user knows the name. |
| `meta name="generator"` | Add it to each document: `Expresso` and its version. | It needs no value from the user, and it shows no text of the user. |
| `meta name="color-scheme"` | Add it to each document, from the theme: `light`, `dark` or `light dark`. | The scroll bars and the colors of the system then agree with the slides. |
| `meta name="theme-color"` | Add it to each document: the background color of the theme. | A browser on a phone can give its bar the color of the slide. |
| `meta name="viewport"` | Leave it out, until a slide fits a small window. | With `width=device-width`, the browser cuts the text of a slide on a phone. See "The viewport". |
| `og:title`, `og:description`, `og:type`, `og:locale` | Add them later, with the address of the deck. | A program makes a card only for a page on a host, and `og:url` is a part of the card. |
| `og:image`, `og:image:alt`, its width and its height | Add them later, with an option for the picture. | The picture must be a file at an absolute address. A data URI does not work. |
| `og:url` and `link rel="canonical"` | Add them later, with an option for the address of the deck. | The render does not know the host. |
| `twitter:card` and its tags | Add `twitter:card` later, with the picture. | X reads the Open Graph tags for the title, the text and the picture. Only the kind of the card needs a tag. |
| `link rel="icon"` | Add it later, with an option. | An icon as a data URI needs no address, but it needs a decision about the default icon. |
| `meta name="robots"` | Add it later, with an option. | It needs no address. No user asked for it. |
| JSON-LD, such as `PresentationDigitalDocument` | Leave it out. | The list of the structured data that Google Search uses has no type for a presentation. |

The facts about a card and about Google Search come from these pages, on 2026-11-15:

- [Structured data markup that Google Search supports](https://developers.google.com/search/docs/appearance/structured-data/search-gallery)
  has 25 features, and no feature for a presentation or for a document.
- [The Open Graph protocol](https://ogp.me/) gives `og:image` as an address of an image.

## The answers to the questions

1. **Which tags does each document get with no option?** `generator`, `color-scheme` and
   `theme-color`. The viewport is not one of them.
2. **One option for the address of the deck, or one option for each tag?** One option for
   the address. `og:url`, `link rel="canonical"` and the address of the picture come from
   it. This is a part of the work that follows.
3. **Does the render make a description from the first slide?** No. The description comes
   from the `description` option only. The first slide is often a title, which the
   `title` element already holds.
4. **Who makes the picture of the card?** The user, with `--png`, and an option gives its
   path. A render with no browser cannot make the picture. This is a part of the work
   that follows.
5. **Does the viewport tag change the layout of a slide on a phone?** Yes. See "The
   viewport".

## The viewport

The text of a slide has a fixed size: the `html` element has `font-size: 48px` on a screen
of each size. A slide thus needs a window of a sufficient width, and `--check` measures
the layout at the sizes that the user gives.

A test in Chromium with the emulation of a phone of 390 by 844 pixels gave these results:

| Measurement | With no tag | With `width=device-width, initial-scale=1` |
| --- | --- | --- |
| The width of the layout | 980 px, which the browser shows at a scale of 0.4 | 390 px |
| The heading "Orders each year" of `chart.exs` | The whole heading shows, with a height of 38 px on the screen. | The browser cuts the heading at the right edge. |
| The width of the page of `code_config.exs` | 980 px | 811 px, so the page moves to the left and to the right. |

With no tag, a phone shows the whole slide at a smaller scale. With the tag, the slide is
as wide as the phone and the text does not fit.

Lighthouse 13.6 gave these results for a deck of one slide with each value of the tag:

| Tag | The insight `viewport` | Cumulative Layout Shift | Performance |
| --- | --- | --- | --- |
| No tag | 0.5 | 0 | 100 |
| `width=980` | 0.5 | 0 | 100 |
| `width=device-width, initial-scale=1` | 1 | 1 | 75 |

A tag with a fixed width, such as `width=980`, gives the layout of a document with no tag,
and it does not change the insight. Lighthouse reads the value `is_mobile_optimized` of
the browser for the insight. The tag with `width=device-width` passes the insight, but the
slide then moves after it shows, and the performance score is lower.

The tag thus needs a change of the layout first: the text of a slide must become smaller
in a small window. That change also changes what `--check` measures, so it is a design of
its own.

## The rule of "no address of a network"

No tag of this change holds an address, so the rule stays as it is. The work that follows
changes it in this way:

- Expresso itself writes no address into the document. This part stays.
- A value that the user gives can be an address: the address of the deck. The document
  then holds that address in `og:url`, in `link rel="canonical"` and in `og:image`.
- `Expresso.FontTest` then examines a deck with no such option.

## The result

The code has these parts:

1. **Two options of the deck.** `description` and `author` take a text. The renderer puts
   a text of more than one line on one line, and an empty text gives no tag.
2. **Three tags with no option.** `Expresso.Renderer` writes `generator`, `color-scheme`
   and `theme-color` after the `title`. `meta charset` stays the first element of the
   `head`.
3. **A theme with two variants.** `color-scheme` is `light dark`, and each variant has a
   `theme-color` tag with the media query of its scheme. A rule gives `:root[data-scheme]`
   the `color-scheme` property, so the scheme of the browser follows the key `t`.
4. **Paper.** A deck with a dark variant gets the rule `color-scheme: light` for paper,
   because paper has the default theme.

A test in a browser examined each computed color of four decks, with and without the tag
`color-scheme`, in the present view, in the menu and in the list of keys. No color of an
element changed, because the style sheet sets each color. The colors of the system
changed: with the theme `:dracula`, `Canvas` went from white to `rgb(18, 18, 18)`.

Lighthouse 13.6 gave these scores for a deck of one slide, on a local server with gzip:

| Deck | Performance | Accessibility | Best practices | SEO |
| --- | --- | --- | --- | --- |
| With no `description` option | 100 | 100 | 100 | 90 |
| With the `description` option | 100 | 100 | 100 | 100 |

The insight `viewport` has the score 0.5 in the two decks.

## The limits

- The key `t` does not change `theme-color`. The tag follows the scheme of the screen.
- Reports say that Safari 26 does not use `theme-color` for the bar of the browser. It
  uses the background color of the page, which is the background color of the theme.
- A phone shows a slide at a small scale, as before.

## The work that follows

| Issue | Tags |
| --- | --- |
| #589 | The address of the deck, the Open Graph tags, the picture of the card, `twitter:card`, the icon and `robots`. |
| #590 | A slide that fits a small window, and then the viewport tag. |
