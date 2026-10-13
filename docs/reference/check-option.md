# The check option

The option `--check` of `mix expresso` and of the binary checks a deck, and writes a report
to the standard output. The exit status is 1 for a problem, so a continuous integration job
can run it.

```sh
mix expresso <input> [output] --check
mix expresso <input> [output] --check=layout
mix expresso <input> [output] --check=a11y
mix expresso <input> [output] --check=browser
mix expresso <input> [output] --check=layout --size 1920x1080 --size 1024x768
```

For the steps and the installation of the tools, see
[Check a deck before the talk](../how-to/check-a-deck.md).

## The arguments

| Argument | Effect |
| --- | --- |
| `<input>` | The deck file, or `-` for the standard input. The check needs it. |
| `[output]` | The file for the HTML. Without it, the check writes no HTML. `-` is an error, because the report goes to the standard output. |
| `--size <width>x<height>` | A size of the page for a browser level, such as `1024x768`. Each side is from 200 to 8000 pixels. Give the option more than one time for more sizes. The default is `1920x1080`. `--size` with `--check` alone, or with no `--check`, is an error. |

`--check` with `--watch` is an error, and so is a level that is not `layout`, `a11y` or `browser`.

## The levels

| Level | The checks |
| --- | --- |
| `--check` | The render, the theme, the size of the document, and the text for a screen reader |
| `--check=layout` | The checks of `--check`, and [the layout check](layout-check.md) at each step |
| `--check=a11y` | The checks of `--check=layout`, and the rules of axe-core at each step and in each view |
| `--check=browser` | The checks of `--check=a11y` in Playwright, and the keys of the presenter |

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
the rule, and the name of each element that fails. The name of an element of a slide is its
kind and the first 40 characters of its text, such as `the text area “Grey on grey”`, as
the layout check gives it. Another element, such as an entry of the menu, gives the CSS
selector of axe-core. The time of each animation is zero, so axe-core reads the final color
of each element.

The check gives each rule on each element one time, at the first step or view that has it.
The overview and the handout view hold a copy of each slide, and a copy has the name of its
element. Therefore a view gives only the elements that no step gave. Two elements with the
same kind and the same text count as one element.

### Sizes of the page

A browser level checks the page at each size of `--size`, in sequence, and at 1920 × 1080
without the option. The `Checks:` line gives each size, such as
`the layout at 1920 × 1080 and 1024 × 768`.

A slide grows and shrinks with the page, so two sizes with the same proportions, such as
1920 × 1080 and 1280 × 720, give the same layout. Give a size with other proportions, such
as 1024 × 768 for a projector of 4:3, to find the problems of that room.

A problem of each size gives one line. A problem of some sizes names them before the first
colon, such as `Slide 1 “wide”, step 1 (1024 × 768): the image “A wide image” goes 524 px past
the right edge`. A problem of the layout gives its distance in pixels, so the same element at two sizes
gives two lines. `--check=browser` presses the keys one time, at the first size.

### Two variants of a theme

For a deck with a light and a dark variant, each browser level runs the checks of the page
two times: one time with `?scheme=light` and one time with `?scheme=dark`. The `Checks:`
line of the report then ends with `in the light and the dark variants`.

A problem of the two variants gives one line. A problem of one variant gives the name of
the variant before the first colon, such as
`Slide 1 “start”, step 1 (dark): color-contrast, …`. With more than one size, the name holds
the size and the variant, such as `(1024 × 768, dark)`. `--check=browser` presses the keys
one time, in the variant of the document, because the keys do not change with the colors.

The check with no tool already checks the colors of each variant, as
[the theme option](theme-option.md) does.

### The keys of the presenter

`--check=browser` opens the document in the Chromium of Playwright, in a page of
1920 × 1080 with reduced motion. First it runs the layout check and axe-core with
`?check=a11y`, as `--check=a11y` does. Then it opens the document again, and it uses the
keys of the list of keys:

| Action | A problem when |
| --- | --- |
| Open the deck. | The present view does not show step 1 of slide 1. |
| Press `j` at each step, to the last step. | The view does not show the next entry of the list of the steps. The check stops at the first such step. |
| Press `Home`, then `m`, then `Escape`. | The menu does not open, does not take the focus, does not close, or keeps the focus. |
| Press `/`, then `Escape`. | The list of keys does not open, does not take the focus, does not close, or keeps the focus. |
| Press `o`, then `Escape`. | The overview does not open or does not close. |
| Press `p`. | The handout view does not open. |

The keys come from the program of the presenter, so the check presses the keys that the list
of keys shows. A key changes the view in a frame of the browser, so the check waits up to
2 s for each change.

Each error of the script of the page, each rejected promise with no handler, and each call of
`console.error` during these actions is a problem too, such as
`The script: TypeError: x is undefined`.

## The tools

| Variable | Gives | Without it |
| --- | --- | --- |
| `EXPRESSO_CHROMIUM` | The path of Chrome or Chromium | The check looks in [the sequence of the search](#the-search-for-the-browser). |
| `EXPRESSO_AXE` | The path of `axe.min.js` | The check looks for `node_modules/axe-core/axe.min.js` in the current directory, in the directory of the deck, in each parent of them, and then in the directory of the tools. |
| `EXPRESSO_PLAYWRIGHT` | The path of `cli.js` of the npm package `playwright` | The check looks for `node_modules/playwright/cli.js` in the same directories as axe-core. |
| `EXPRESSO_TOOLS` | The directory of the tools | `--install-check-tools` uses `expresso` in the cache directory of the user, such as `~/.cache/expresso` on Linux and `~/Library/Caches/expresso` on macOS. |

### Install the tools

`mix expresso --install-check-tools`, or `expresso --install-check-tools` with the binary,
installs the tools of the browser levels. It needs `node` and `npm` on the `PATH`, and it
takes no other argument. It runs these commands, in sequence:

1. `npm install --prefix <directory> playwright axe-core`, with the directory of
   `EXPRESSO_TOOLS`. `Expresso.Check.Tools.packages/0` gives the version of each package.
2. `node <directory>/node_modules/playwright/cli.js install chromium`, which puts the
   Chromium and the headless shell into the cache of Playwright.

The exit status is 1 when a command fails. The error of a missing tool of a level gives
this command.

### The search for the browser

Without `EXPRESSO_CHROMIUM`, `--check=layout` and `--check=a11y` look for the browser in
this sequence:

1. The headless shell of Playwright, and then its Chromium, in the directory of
   `PLAYWRIGHT_BROWSERS_PATH`, or in the cache of Playwright without it. The headless shell
   starts fast, and it gives the page its size exactly.
2. `google-chrome`, `google-chrome-stable`, `chrome`, `chrome-headless-shell`,
   `headless_shell`, `chromium` and `chromium-browser` on the `PATH`. The check skips a
   command that runs or installs a snap, such as `chromium` on Ubuntu, because that command
   does not end.
3. Chrome and Chromium in the folder `Applications` of macOS.

The line `Browser:` of the report gives the path of the browser that ran.

`--check=browser` also needs `node` on the `PATH`, the Chromium of Playwright, and the Hex
package `playwright_ex`. Expresso gives `playwright_ex` as an optional dependency, so a Mix
project adds it to its own deps. The binary holds it. With `EXPRESSO_CHROMIUM`, Playwright
starts that browser in place of its own.

The check finds each tool before it renders the deck. A missing tool gives an error that
tells how to install it.

The browser runs with `--no-sandbox`, as the browser of Playwright does. It opens only the
copy of the document, in a temporary directory with its own profile. The check removes the
directory after the run.

## The report

The report has these parts, in this sequence:

1. `Check of <input>:` and the number of slides.
2. `Checks:` and the checks of the level. A browser level gives the size of the page.
3. `Browser:` and the path of the browser, for a browser level. `--check=browser` gives
   `the Chromium of Playwright` without `EXPRESSO_CHROMIUM`.
4. `Notes:` and one line for each note. The part is absent when the deck has no note.
5. `Problems:` and one line for each problem. The part is absent when the deck has no
   problem.
6. `No problems.`, or the number of problems.

A line about one slide gives the number and the name of the slide, such as
`Slide 14 “resHit”, step 3`. A slide with no name gives its number only.

```text
Check of deck.exs: 3 slides
Checks: the render, the theme, the text for a screen reader, the layout at 1920 × 1080, and axe-core at each step and in each view
Browser: /home/user/.cache/ms-playwright/chromium_headless_shell-1194/chrome-linux/headless_shell

Notes:
  - The document is 291 KB.

Problems:
  - Slide 2 “long”, step 2: 1 line breaks in the code “const a = 1; const b = [1, 2, 3, 4, 5, 6…”
  - Slide 3 “low”, step 1: color-contrast, Elements must meet minimum color contrast ratio thresholds: the text area “Grey on grey”

2 problems.
```

## The exit status

| Status | When |
| --- | --- |
| 0 | The report has no problem. A note does not change the status. |
| 1 | The report has a problem, or the check stopped for an error. An error goes to the standard error, and the standard output then holds no report. |

## The time

`--check` takes the time of a render. `--check=layout` and `--check=a11y` add the start of
the browser two times: one time to measure its window, and one time for the check.
Playwright gives the page its size, so `--check=browser` starts its browser one time. A
deck with two variants of a theme runs the checks of the page two times, so these levels
take about two times as long. Each size of `--size` adds one more run of the checks of the
page, for each variant. The check stops a
browser that does not end in 30 s for the measure, or in 10 minutes for the check, and
gives an error. Then give a different browser in `EXPRESSO_CHROMIUM`.

Most of the time of `--check=a11y` goes to axe-core, at about 0.2 s for each step. During
the steps, the check takes the menu, the list of keys and the copies of the slides out of
the document, because axe-core reads the whole document at each run. For the Line 4 deck
of `examples/line4`, with 28 slides and 74 steps, these were the times after the compile:

| Level | Time |
| --- | --- |
| `--check` | 2 s |
| `--check=layout` | 11 s |
| `--check=a11y` | 36 s |
| `--check=browser` | 30 s |
