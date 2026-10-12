# The check option

The option `--check` of `mix expresso` and of the binary checks a deck, and writes a report
to the standard output. The exit status is 1 for a problem, so a continuous integration job
can run it.

```sh
mix expresso <input> [output] --check
mix expresso <input> [output] --check=layout
mix expresso <input> [output] --check=a11y
```

For the steps and the installation of the tools, see
[Check a deck before the talk](../how-to/check-a-deck.md).

## The arguments

| Argument | Effect |
| --- | --- |
| `<input>` | The deck file, or `-` for the standard input. The check needs it. |
| `[output]` | The file for the HTML. Without it, the check writes no HTML. `-` is an error, because the report goes to the standard output. |

`--check` with `--watch` is an error, and so is a level that is not `layout` or `a11y`.

## The levels

| Level | The checks |
| --- | --- |
| `--check` | The render, the theme, the size of the document, and the text for a screen reader |
| `--check=layout` | The checks of `--check`, and [the layout check](layout-check.md) at each step |
| `--check=a11y` | The checks of `--check=layout`, and the rules of axe-core at each step and in each view |

### The checks with no tool

| Check | Kind | Finds |
| --- | --- | --- |
| The render | Error | A deck file that does not compile, or does not return a deck |
| The theme | Problem | Each role of a theme of 16 colors under its minimum of contrast. The text is the warning of the compiler. See [The theme option](theme-option.md). |
| The size | Note | The size of the document, and the type and the size of its three largest files |
| An image | Note | An image with no `alt` option. A screen reader skips it. |
| A diagram | Note | A diagram with no `alt` option. A screen reader reads the text of its SVG. |
| A hidden heading | Note | A slide with no visible heading. A screen reader reads [the hidden heading](accessibility.md). |
| No `h1` | Note | A slide with `sr_heading false` and no heading. A screen reader finds no name for it. |

### The checks in a browser

`--check=layout` and `--check=a11y` open a copy of the document in a headless Chrome or
Chromium, with `?check` or `?check=a11y` in the address. The page of the copy has the size
1920 × 1080.

The layout check finds each element that goes past an edge of the window, and each line of
code that breaks, at each step. Its problems have the same text as the report of
`?check`, such as `Slide 6, step 3: the math “s = o + x” goes 120 px past the right edge`.

The accessibility check runs axe-core on the slide of each step. Then it runs axe-core on
the whole document in these views:

- the present view,
- the menu,
- the list of keys,
- the overview,
- the handout view.

A problem of axe-core gives the step or the view, the id of the rule, the description of
the rule, and a CSS selector for each element that fails. The check gives each rule on each
element one time, at the first step or view that has it. The time of each animation is
zero, so axe-core reads the final color of each element.

## The tools

| Variable | Gives | Without it |
| --- | --- | --- |
| `EXPRESSO_CHROMIUM` | The path of Chrome or Chromium | The check looks for `google-chrome`, `google-chrome-stable`, `chrome`, `chrome-headless-shell`, `headless_shell`, `chromium` and `chromium-browser` on the `PATH`, in this sequence. Then it looks for Chrome and Chromium in the folder `Applications` of macOS, and then in the cache of Playwright. |
| `EXPRESSO_AXE` | The path of `axe.min.js` | The check looks for `node_modules/axe-core/axe.min.js` in the current directory, in the directory of the deck, and in each parent of them. |

The check finds each tool before it renders the deck. A missing tool gives an error that
tells how to install it.

The browser runs with `--no-sandbox`, as the browser of Playwright does. It opens only the
copy of the document, in a temporary directory with its own profile. The check removes the
directory after the run.

## The report

The report has these parts, in this sequence:

1. `Check of <input>:` and the number of slides.
2. `Checks:` and the checks of the level. A browser level gives the size of the page.
3. `Notes:` and one line for each note. The part is absent when the deck has no note.
4. `Problems:` and one line for each problem. The part is absent when the deck has no
   problem.
5. `No problems.`, or the number of problems.

```text
Check of deck.exs: 3 slides
Checks: the render, the theme, the text for a screen reader, the layout at 1920 × 1080, and axe-core at each step and in each view

Notes:
  - The document is 291 KB.

Problems:
  - Slide 2, step 2: 1 line breaks in the code “const a = 1; const b = [1, 2, 3, 4, 5, 6…”
  - Slide 3, step 1: color-contrast, Elements must meet minimum color contrast ratio thresholds: #slide-3 > div:nth-child(2) > .slide-body > .slide-main > .low.text-area > div

2 problems.
```

## The exit status

| Status | When |
| --- | --- |
| 0 | The report has no problem. A note does not change the status. |
| 1 | The report has a problem, or the check stopped for an error. An error goes to the standard error, and the standard output then holds no report. |

## The time

`--check` takes the time of a render. A browser level adds the start of the browser two
times: one time to measure its window, and one time for the check. The check stops a
browser that does not end in 30 s for the measure, or in 10 minutes for the check, and
gives an error. Then give a different browser in `EXPRESSO_CHROMIUM`. For the Line 4 deck of
`examples/line4`, with 28 slides, `--check` took 3 s, `--check=layout` took 5 s and
`--check=a11y` took 49 s, after the compile.
