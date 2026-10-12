# Check a deck before the talk

This guide shows how to check a deck with one command, on your computer or in a continuous
integration job. `mix expresso deck.exs --check` renders the deck, writes a report, and
exits with the status 1 for a problem. For each value of the report, see
[The check option](../reference/check-option.md).

## Choose a level

The check has three levels. Each level runs the checks of the level before it, and it needs
one more tool:

| Command | Checks | Needs |
| --- | --- | --- |
| `mix expresso deck.exs --check` | The render, the contrast of the theme, and the text for a screen reader | Nothing |
| `mix expresso deck.exs --check=layout` | Each element in the window, and each line of code on one line, at each step at 1920 × 1080 | Chrome or Chromium |
| `mix expresso deck.exs --check=a11y` | The rules of axe-core at each step, and in the menu, the list of keys, the overview and the handout view | Chrome or Chromium, and axe-core |

Start with `--check`. Install the tools of a higher level when the deck is ready for the
room. The binary takes the same options, such as `expresso deck.exs --check=a11y`.

## Run the check with no tool

1. Run the check:

   ```sh
   mix expresso deck.exs --check
   ```

2. Read the report. The last line gives the number of problems.
3. Correct each problem, and run the check again.

The report also gives notes. A note tells of a choice that can be correct, such as an image
with no `alt` text, which a screen reader skips. A note does not change the exit status.

To write the document in the same run, give the output file:

```sh
mix expresso deck.exs deck.html --check
```

## Install a browser for the layout check

`--check=layout` runs the layout check of the presenter in a headless browser. Install
Chrome or Chromium:

| System | Command |
| --- | --- |
| Debian or Ubuntu | `sudo apt install chromium` |
| Fedora | `sudo dnf install chromium` |
| macOS with Homebrew | `brew install --cask chromium` |
| Each system with Node | `npx playwright install --only-shell chromium` |

The check looks for the browser on the `PATH`, in the folder `Applications` of macOS, and
in the cache of Playwright. When it does not find the browser, give its path:

```sh
export EXPRESSO_CHROMIUM=/path/to/chrome
mix expresso deck.exs --check=layout
```

The check measures each step at 1920 × 1080. To correct a problem of the layout, see
[Check that a deck fits the screen](check-the-layout.md).

## Install axe-core for the accessibility check

`--check=a11y` also runs [axe-core](https://github.com/dequelabs/axe-core) at each step
and in each view. It needs the browser of the layout check, and the npm package
`axe-core`:

1. Go to the directory of the deck, or to a parent directory of it.
2. Install the package:

   ```sh
   npm install --save-dev axe-core
   ```

3. Run the check:

   ```sh
   mix expresso deck.exs --check=a11y
   ```

The check looks for `node_modules/axe-core/axe.min.js` in the current directory, in the
directory of the deck, and in each parent of them. To use a different copy, give its path
in `EXPRESSO_AXE`.

## Read a report

This deck has a text in grey on a grey background:

```elixir
defmodule Examples.CheckDeck do
  use Expresso

  css ".quiet { color: #8a8a8a; background: #6b6b6b; padding: 0.2em 0.4em; }"

  slide "the plan" do
    heading "The plan"

    list do
      item "Measure the line"
      item "Find the slowest station"
    end

    text_area(text: "Notes for the speaker go in the notes, not here.", class: "quiet")
  end
end

Examples.CheckDeck
```

![A slide with the heading "The plan", two items, and a box of grey text on a grey background that is hard to read](https://raw.githubusercontent.com/rellen/expresso/media/check-deck.png)

`--check=a11y` gives the low contrast as a problem, at the step and in the view that has
it:

```text
Check of check_deck.exs: 1 slide
Checks: the render, the theme, the text for a screen reader, the layout at 1920 × 1080, and axe-core at each step and in each view

Notes:
  - The document is 259 KB.

Problems:
  - Slide 1, step 1: color-contrast, Elements must meet minimum color contrast ratio thresholds: #slide-1 > div:nth-child(2) > .slide-body > .slide-main > .text-area.quiet > div
  - The overview: color-contrast, Elements must meet minimum color contrast ratio thresholds: .handout-page > div:nth-child(2) > .slide-body > .slide-main > .text-area.quiet > div

2 problems.
```

A problem of axe-core names the step or the view, the rule, and a CSS selector for each
element that fails. The selector `.text-area.quiet` names the text area with the class
`quiet`. To correct the deck, give that class a color with more contrast, or remove the
class. Then run the check again, until it gives `No problems.`

The most frequent problem is dimmed text. To correct it, see
[Keep dimmed text readable](make-a-deck-accessible.md#keep-dimmed-text-readable).

## Check a deck in a continuous integration job

This job of GitHub Actions runs each level for a deck in a Mix project. The runner of
GitHub has Chrome on its `PATH`:

```yaml
jobs:
  deck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: erlef/setup-beam@v1
        with:
          version-file: .tool-versions
          version-type: strict
      - uses: actions/setup-node@v7
        with:
          node-version: 24
      - run: mix deps.get
      - run: npm install --no-save axe-core
      - run: mix expresso deck.exs deck.html --check=a11y
```

The job fails when the report has a problem. The step also writes `deck.html`, so a later
step can publish it.
