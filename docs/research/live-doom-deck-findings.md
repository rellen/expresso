# Findings from the live-doom deck

This document records the problems that we found in Expresso when we made a deck about
LiveDoom. The deck is in the repository `rellen/live-doom`, in `talk/`. It has
43 slides, a theme of its own with a light and a dark variant, animated
diagrams and code from the files of that project.

We wrote each finding at the time that we found it. Each finding has a kind:

| Kind | Meaning |
| --- | --- |
| Sharp edge | Expresso does a thing that the user does not expect, or the error does not help. |
| Missing | The deck needed a feature that Expresso does not have. |
| Could be better | The feature works, but it needs more work from the user than necessary. |

Each finding also tells what we did in the deck, and what change to Expresso can help.

## The findings

### 1. A path is relative to the working directory, not to the deck

**Kind:** could be better.

Each path of a deck is relative to the working directory of the command: `src` of a code
element, an image, a diagram and the `css` file. The deck of this report is in another
repository, so a relative path in the deck breaks when the user renders it from the
directory of Expresso.

**In the deck:** a module attribute holds the root of the project, from `__DIR__`, and each
path is `Path.join(@root, "...")`. This works, because each option of the DSL is an
expression. The documents do not tell that a deck can do this.

**Change:** resolve a relative path against the directory of the deck file, or add a deck
option such as `root`. At a minimum, add the `__DIR__` pattern to
`docs/how-to/show-code.md`.

### 2. `mix expresso` runs only in the project of Expresso

**Kind:** could be better.

A deck in another project needs the Burrito binary, or a `cd` into a clone of Expresso.
There is no `mix archive.install` or escript that a project can use.

**In the deck:** the README of `talk/` tells the user to run `mix expresso` from a clone of
Expresso, with the path of the deck.

**Change:** publish an archive with the task, or document the binary as the way to render
a deck that is not in the project of Expresso.

### 3. A theme has one variant: there is no light and dark pair

**Kind:** missing.

The `theme` option takes one base16 scheme. The document does not follow
`prefers-color-scheme`, and the presenter has no key to change the variant. A talk in a
light room and a talk in a dark room need two renders of the deck.

**In the deck:** the `theme` option gives the dark variant. The `css` option adds the roles
of the light variant in `@media screen and (prefers-color-scheme: light)`. The deck makes
those declarations with `Expresso.Palette.new/3` and `Expresso.Palette.declarations/1`, so
the light roles also get their dimmed colors. An environment variable selects a fixed
variant for one render.

**Change:** accept `theme dark: ..., light: ...`. The renderer can write the second set of
roles in a media query, and `Expresso.ThemeVerifier` can check both. A key, such as `t`,
can change the variant during the talk.

### 4. A theme from a map is not adjusted

**Kind:** could be better.

`Expresso.Palette.Builtin` adjusts the lightness of each built-in theme until each role
meets its minimum. A theme from a map gets a warning for each role that fails, but no
adjustment. The user must then find each color by hand, and the warning does not give the
color that passes.

**In the deck:** a short script calls `Expresso.Palette.problems/1` for each candidate
scheme, and we changed the colors until the list was empty.

**Change:** give the passing color in the warning, from `Expresso.Color.adjust/4`. An
option such as `theme %{...}, adjust: true` can also apply the same adjustment as for a
built-in theme.

### 5. Line numbers break a code element without a lexer

**Kind:** sharp edge. This is a defect.

A code element with `line_numbers true` and a language that has no lexer, such as
`"toml"`, shows each number on one row and its line two rows below it. A code element
with no language and `line_numbers true` does the same. Without `line_numbers`, both show
the code correctly. The deck needed this for an excerpt of `fly.toml`.

The cause: without a lexer, `Expresso.Highlight.lines/2` returns the escaped text of the
line, with a line break at its end, and no `span`. The render function then writes the
line break and the white space of the template into the `pre` element, and
`white-space: pre-wrap` shows them. A line from a lexer is a sequence of `span`
elements, and Floki drops the white space between them.

**In the deck:** the excerpts of `fly.toml` have no line numbers.

**Change:** put a plain line into one `span`, with no line break, as for a lexed line. Add
a test that renders a code element with `line_numbers true` and no language.

### 6. An unknown language gives no warning

**Kind:** could be better.

`code "toml"` compiles with no warning, and the code then shows with no colors. The
documents list the languages, but a misspelled name, such as `"elixr"`, also gives no
warning. The deck shows Zig code from `c_src/build.zig` and TOML from `fly.toml`, and
Makeup has no lexer for either of them.

**In the deck:** `build.zig` shows with the C lexer, and `fly.toml` shows with no colors.

**Change:** give a compile warning for a language that no lexer registers, with the list of
the languages.

### 7. Each slide must name its own slide template

**Kind:** could be better.

The `template` option of a deck selects the deck template, which makes the header and the
footer. No option selects the slide template of each slide. The default slide template also
writes an inline `style` on the heading, `margin: 0.5rem 0; text-align: center`, so a rule
of the deck needs `!important` to align a heading at the left.

**In the deck:** the rules for the heading use `!important`.

**Change:** add a deck option for the default slide template, such as
`slide_template MyTemplate`. Move the inline style of the heading into the theme, so a
rule of the deck can replace it.

### 8. A font of the deck must be a data URI that the deck makes

**Kind:** could be better.

`Expresso.Font` puts the font of the theme into the document. A deck with its own font
must write the `@font-face` rule itself, with the bytes of the font in a data URI, because
the document is one file. The `css` option takes a style sheet or the path of one, and the
renderer does not put the files of `url()` into the document.

**In the deck:** a function reads the WOFF2 file, encodes it with Base64 and writes the
`@font-face` rule. The `css` option gets that rule, the rules of the light variant and the
rules of the deck as one string.

**Change:** let the `css` option put a local file of `url()` into the document, as
`Expresso.Font` does for the theme.

### 9. A deck cannot add a transition

**Kind:** missing.

A slide takes `:fade`, `:slide`, `:zoom` or `:none`. An effect of an element can use a
`@keyframes` rule of the deck, but a transition cannot. The deck wanted the screen melt of
Doom between the levels.

**In the deck:** the template of a level card has a `::after` curtain with a `@keyframes`
rule. The presenter shows a slide with `display: flex`, so the browser starts the
animation again each time that the slide shows. The slides of the levels have
`transition :none`.

**Change:** read a `[data-transition="name"]` rule from the `css` option, as the
`EffectVerifier` does for an effect.

### 10. A video needs an embed

**Kind:** missing.

The deck shows 17 seconds of the game. An `image` can be a GIF, but the document holds one
copy of an image for the present view and one for each page of the handout view. A GIF of
that length is also large.

**In the deck:** a local HTML file holds a `video` element with the WebM file as a data
URI. An `embed` shows the file, and the document holds the file one time. A PNG is the
fallback for the handout view and for paper. This works well, and the documents can
give it as a pattern.

**Change:** add a `video` element that writes its source one time, as an embed does, with
a poster image for paper.

### 11. A slide of the present view has no space at the sides

**Kind:** sharp edge.

The theme gives a page of the handout view a padding of `1vh 1vw`, but a slide of the
present view gets none. A heading at the left therefore touches the edge of the window,
and so does a list in the right column. A centered heading, as in the deck of Line 4,
hides the problem.

**In the deck:** `.slide-body { padding: 0 1rem; }`.

**Change:** give the slide body a padding in the theme, with a custom property such as
`--slide-padding`.

### 12. A slide is only as wide as its content

**Kind:** sharp edge.

`docs/architecture.md` tells that a slide of the present view takes the width of its
content. A `columns` element then divides that width, and not the width of the window. On
one slide, a line of 90 characters broke in the right column, although the window had 300
pixels to spare. The layout check reported the break, but the cause was not clear from the
report.

**In the deck:** `.screen .slide-body { width: 100vw; }`. The layout check then gave no
problems.

**Change:** give each slide the full width of the window. The slide number already has a
fixed position, so it does not need the narrow slide.

### 13. A code element centers itself and takes the free height

**Kind:** could be better.

The theme gives `.code` `flex-grow: 1` and `align-items: center`. Two code elements in one
column, or two excerpts one above the other, therefore do not share a left edge, and each
takes half of the free height, so a large gap separates them.

**In the deck:** `.column .code { flex-grow: 0; align-items: flex-start; }`, and a class for
the slides with stacked excerpts.

**Change:** do not let a code element grow, and align the excerpts of one parent on one
left edge.

### 14. Line numbers are a fragile anchor for an excerpt

**Kind:** could be better.

The deck shows 20 excerpts of the files of LiveDoom, with `lines` ranges. A change above an
excerpt moves its lines, and the slide then shows other lines with no error. The deck is in
the same repository as the code, so the problem occurs at each change of the code. The
layout check does not find it.

**In the deck:** a comment at the top of the deck tells the user to look at the code slides
after a change.

**Change:** let `lines` take a start text and an end text, such as
`lines from: "def start(", to: "\n  end"`, or a named region between two marker comments.
The compiler can then give an error when the text is not in the file.

### 15. A template cannot read a custom value of a slide

**Kind:** could be better.

The header of the deck shows the level of each slide, such as "E1M3 · Toxin Refinery".
A deck template gets `@slide`, but a slide takes no option for a value of the deck, and
the DSL refuses an unknown option.

**In the deck:** the name of each slide starts with its level, such as `"e1m3 threads"`, and
the template reads the level from the name.

**Change:** add a slide option such as `meta level: "E1M3"`, and give it to the templates in
`@metadata`.

### 16. `highlight` puts a group in focus at the first step

**Kind:** could be better.

The first group of `highlight` is in focus at step 1, so the audience never sees the whole
code in full color first. The guide tells the user to put `pause()` in front of the code
element, and 8 slides of the deck needed it. The design is documented, but the default
does not agree with the usual order of a talk: the whole code first, then each part.

**Change:** add an option to show the whole code first, or make it the default.

## What worked well

- **The layout check.** The first render had 10 problems at 1920 × 1080: lines of code that
  broke, a formula past an edge and a listing past the bottom. Each report had a link to its
  step. The last render had no problems, in both variants.
- **Diagrams with the colors of the theme.** The SVG files are part of the document, so a
  class on a shape and a rule of the deck give each shape a role color. Each diagram follows
  the light and the dark variant with no second file.
- **`move_to`.** The packets of the fan-out diagram move from each encoder to the players,
  and the deck gives no coordinates.
- **`highlight`, `reveal` and `dim`.** They gave each code slide and each list one point at
  a time, as the segmenting and signaling principles of Mayer ask.
- **`Expresso.Palette` as an API.** `new/3`, `problems/1` and `declarations/1` checked the
  two schemes and made the roles of the light variant, with their dimmed colors.
- **The embed of a local file.** A page with a video in a data URI plays in the present view,
  and the document holds it one time.
