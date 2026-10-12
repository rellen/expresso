# Notes from the new talk about Line 4

This document records what we found on 2026-10-12, when we made the talk about Line 4 again
with the latest Expresso. We wrote each note at the time that we found it.

The talk is `talks/line-4/deck.exs` in [iso-factories](https://github.com/rellen/iso-factories).
It is a Mix project with Expresso as a dev dependency from GitHub, pinned to commit
`3acb139`. `examples/line4/line4.exs` is a copy of it. The talk has 28 slides and uses
these features:

- sections and a `toc`,
- `stat`, with `count` and a `morph` key,
- `callout`, `icon` and `qr_code`,
- a `chart` from a CSV file and a `chart` from the deck,
- `diagram` with `alt`, `video` with `captions`, and the deck option `lang`,
- `embed` of a local page, which puts the factory into the document,
- `code` with `src`, `lines` from a text, and `highlight`.

## The result

| Item | Result |
| --- | --- |
| Slides | 28, in 8 sections |
| Time to render | 2.5 s |
| Size of the document | 3.9 MB |
| `?check` at 1920 × 1080 | No problem |
| axe-core 4.14.0 on each slide, the menu, the list of keys, the overview and the handout view | No violation with #207. Without it, one violation on each chart. |

### The accessibility problems of the old deck

| Problem | Cause | Status |
| --- | --- | --- |
| The first slide had no `h1`. | The slide template of the old deck wrote the heading as an `h2`. | Solved by the deck. The new deck uses the slide template of Expresso, and each slide has an `h1`. |
| A comment of the code had a contrast of 3.56:1. | The comment was on a dimmed line. Expresso dims each role of text to 3:1, by design. axe-core asks 4.5:1 for text under 24 px. | Not solved by Expresso. The deck sets its own dimmed colors. See [Minus 3](#3-dimmed-text-has-a-contrast-of-31). |

A new problem came from the charts: an empty header cell in the table of values. #207 fixes it.

## Plus

What worked well:

1. **The first render had no error.** The deck compiled at the first attempt, and the
   errors of the DSL were not necessary.
2. **`lines` from a text.** Each code slide finds its excerpt in the factory page by the
   text of its first and last line. The page changes each day, and the excerpts stay
   correct.
3. **A local page in an `embed`.** The renderer puts the page into the document. The cover
   of the talk runs the factory itself, with no network.
4. **Sections and `toc`.** Eight `section` options give the agenda, with a link to each
   section.
5. **`stat` with `count` and `morph`.** A number counts up on one slide, and moves to its
   place on the next slide with no extra code.
6. **A chart from a CSV file.** Three lines of the DSL make a line chart from a file of
   five lines.
7. **`video` with `captions`.** A WebVTT file of three cues gives a track that shows by
   default.
8. **`?check`.** The report names the slide, the step and the element of each problem.
   We found each problem of the layout with it.
9. **A module attribute in the DSL.** `@page "line-4.html"` and `src @page` work. The copy
   in this repository thus differs from its source in one line.
10. **The menu, the overview and the list of keys.** axe-core finds no violation in them.

## Minus

What did not work well:

### 1. A dependency from GitHub does not compile

**Kind:** bug, and a blocker. Fixed by #206.

The presenter bundle is not in Git, so a dependency must make it. The compiler read the
esbuild profile from `config/config.exs`, and a dependency does not load that file. The
compile stopped with "unknown esbuild profile". The dependency test took Expresso from the
working tree, which holds a bundle, so it did not find the defect.

**In the deck:** a temporary `config/config.exs` with the profile.

### 2. Each chart has an empty header cell

**Kind:** bug. Fixed by #207.

The top left corner of the table of values was an empty `th`. axe-core gave the violation
`empty-table-header` for each chart in each view. The deck of the accessibility test says
that it holds a chart, but it held none.

### 3. Dimmed text has a contrast of 3:1

**Kind:** a decision to make. The maintainer chose a deck option: `dim_contrast 4.5`.

`Expresso.Palette` dims each role of text to the strongest dimming that keeps 3:1 and
Lc 30. The `@moduledoc` gives criterion 1.4.11 as the reason, but that criterion is for
parts that are not text. Dimmed code is still text, so criterion 1.4.3 asks 4.5:1 for text
under 24 px. axe-core finds a violation on each dimmed line of code.

The same `@moduledoc` tells why a theme does not use the smaller minimum of large text: a
projector and the light of a room lower the contrast. The minimum of the dimmed text is
the minimum of large text.

**In the deck:** the `css` option sets the 16 dimmed colors, each at 4.5:1.

**Change:** one of these.

| Option | Effect |
| --- | --- |
| A minimum of 4.5:1 for dimmed text | Each deck passes axe-core. A theme with a role near 4.5:1 then has almost no dimming, and the bar of `highlight` must show the focus. |
| A deck option, such as `dim_contrast 4.5` | The default stays. A deck can ask for 4.5:1 with one line in place of 16 colors. |
| No change | The documents tell that dimmed text fails criterion 1.4.3, and why. |

### 4. Each image is in the document many times

**Kind:** could be better. The document now holds each large file one time.

`screen.jpg` is 250 KB. The document holds it six times, as a data URI for each place that
shows it, such as the slide, the fallback of the embed, the overview, the menu and the
handout view. Two images make 2 MB of the 3.9 MB.

**Change:** put each file into the document one time, and refer to it from each place.

### 5. A real line of code is too long for a slide

**Kind:** sharp edge. The code element now takes `trailing_comments false` and `wrap true`.

The lines of the factory page have up to 190 characters, with a comment at the end. At a
size that a room can read, `?check` reported a broken line on six slides.

**In the deck:** a class `dense` with a font of 0.34rem on five slides, wider columns, and
a code element without a column on one slide.

**Change:** an option of `code` that removes a comment at the end of a line, or that
breaks a long line at an indent.

### 6. `highlight` takes line numbers

**Kind:** sharp edge. A group can now be texts, and `relative true` counts from the excerpt.

`lines from:` finds the excerpt by text, so the excerpt follows the file. But `highlight`
and `reveal` take the numbers of lines in the file, such as `[3589..3590, 3593..3593]`.
When the page changes above the excerpt, the groups select other lines, and no error
occurs.

**Change:** groups in the same form as `lines`, such as `highlight [[from: "let hit"], ...]`,
or numbers relative to the first line of the excerpt.

## Interesting

1. **The code follows the page, but a diagram does not.** The old `oee.svg` gave a rated
   cycle of 0.78 s and a quality of stale rejects only. Both changed in the page. Each code
   excerpt was still correct, because it comes from the file. We drew `oee.svg` again.
2. **The cover runs the factory.** The embed has `sandbox="allow-scripts"`, so the page
   has no `localStorage`. The page catches the error, because it also runs as a claude.ai
   artifact.
3. **The `h1` problem was in the deck, not in Expresso.** A custom slide template can leave
   out the heading. Expresso can tell the user when a slide has no `h1`.
4. **The talk found defects in the factory page.** The description of the canvas tells of
   one robot arm and four widgets to a carton: the page has two arms and six. A comment of
   the paint order tells of a depth key, which the code does not use. The stall watchdog
   reads a variable `bp` that does not exist, in a branch that cannot run. We reported
   these in the pull request of iso-factories.
5. **The checks need a script.** We wrote a Playwright script to run `?check`, to run
   axe-core on each slide and each view, and to take a picture of each slide. Each deck
   that wants these checks in CI needs the same script.
6. **The talk is a Mix project beside pages with no build.** The Pages workflow of
   iso-factories publishes only the rendered `index.html` of the talk.

## Missing features

1. A deck option for the contrast of dimmed text. See Minus 3.
2. One copy of each file in the document. See Minus 4.
3. An option of `code` for long lines. See Minus 5.
4. `highlight` and `reveal` groups by text. See Minus 6.
5. A headless check, such as `mix expresso deck.exs --check`, that runs `?check` and
   axe-core on each slide and exits with an error for a problem. A CI job can then run it.
6. A warning for a slide with no `h1`.
7. The name of the categories of a chart (now `category_label`, from the first heading of the file). The first heading of the CSV file, such as
   `commit`, can name the corner of the table of values and the axis of the categories.
8. A title for the axis of the values of a chart, such as "widgets an hour" (now `value_label`).
