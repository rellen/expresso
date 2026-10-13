# Check a deck before the talk

This guide shows how to check a deck with one command, on your computer or in a continuous
integration job. `mix expresso deck.exs --check` renders the deck, writes a report, and
exits with the status 1 for a problem. For each value of the report, see
[The check option](../reference/check-option.md).

## Choose a level

The check has four levels. Each level runs the checks of the level before it, and it needs
one more tool:

| Command | Checks | Needs |
| --- | --- | --- |
| `mix expresso deck.exs --check` | The render, the contrast of the theme, and the text for a screen reader | Nothing |
| `mix expresso deck.exs --check=layout` | Each element in the window, and each line of code on one line, at each step at 1920 × 1080 | Chrome or Chromium |
| `mix expresso deck.exs --check=a11y` | The rules of axe-core at each step, and in the menu, the list of keys, the overview and the handout view | Chrome or Chromium, and axe-core |
| `mix expresso deck.exs --check=browser` | The checks of `--check=a11y`, and the keys of the presenter: each step, each view, the focus and the errors of the script | Node, Playwright, axe-core, and the Hex package `playwright_ex` |

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

## Install the tools with one command

The levels `--check=layout`, `--check=a11y` and `--check=browser` need a browser and the
npm packages `axe-core` and `playwright`. One command installs each of them. The deck does
not need a `node_modules`, so a Mix project with no Node can use the tools:

1. Install [Node](https://nodejs.org), and make sure that `node` and `npm` are on the
   `PATH`.
2. Install the tools:

   ```sh
   mix expresso --install-check-tools
   ```

   With the binary, run `expresso --install-check-tools`.

3. In a Mix project, add the Hex package `playwright_ex` to the deps in `mix.exs`, and run
   `mix deps.get`. Only `--check=browser` needs it, and the binary holds it:

   ```elixir
   {:playwright_ex, "~> 0.14", only: :dev, runtime: false}
   ```

4. Run the check:

   ```sh
   mix expresso deck.exs --check=browser
   ```

The command puts the npm packages into `~/.cache/expresso` on Linux, or
`~/Library/Caches/expresso` on macOS. `EXPRESSO_TOOLS` gives a different directory. The
Chromium and the headless shell go into the cache of Playwright. Run the command again to
get the versions of a new release of Expresso.

The sections below tell how to install each tool in its own way.

## Install a browser for the layout check

`--check=layout` runs the layout check of the presenter in a headless browser. Install
Chrome or Chromium with the command of the system, or with
`mix expresso --install-check-tools`:

| System | Command |
| --- | --- |
| Debian or Ubuntu | `sudo apt install chromium` |
| Fedora | `sudo dnf install chromium` |
| macOS with Homebrew | `brew install --cask chromium` |
| Each system with Node | `npx playwright install --only-shell chromium` |

The check looks for the browser in the cache of Playwright, on the `PATH`, and in the
folder `Applications` of macOS. The line `Browser:` of the report gives the browser that
ran. When the check does not find the browser, or finds a different one, give its path:

```sh
export EXPRESSO_CHROMIUM=/path/to/chrome
mix expresso deck.exs --check=layout
```

The check measures each step at 1920 × 1080. To correct a problem of the layout, see
[Check that a deck fits the screen](check-the-layout.md).

## Check the screen of the room

A projector can have other proportions than 16:9, such as 4:3. Give the size of each screen
of the talk with `--size`:

```sh
mix expresso deck.exs --check=layout --size 1920x1080 --size 1024x768
```

A problem of one size names it, such as `Slide 1 “wide”, step 1 (1024 × 768): …`. A slide
grows with the page, so only the proportions of a size change the layout. 1280 × 720 thus
gives the same result as 1920 × 1080.

## Install axe-core for the accessibility check

`--check=a11y` also runs [axe-core](https://github.com/dequelabs/axe-core) at each step
and in each view. It needs the browser of the layout check, and the npm package
`axe-core`. `mix expresso --install-check-tools` installs it. To install it in the
directory of the deck in place of that:

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
directory of the deck, in each parent of them, and then in the directory of
`--install-check-tools`. To use a different copy, give its path in `EXPRESSO_AXE`.

## Install Playwright for the browser check

`--check=browser` opens the deck in the Chromium of [Playwright](https://playwright.dev),
and uses the presenter as you do. It presses the key of the next step from the first step
to the last step, and it opens and closes the menu, the list of keys, the overview and the
handout view with their keys. It also runs the checks of `--check=a11y` in the same browser,
so it needs no other Chrome. `mix expresso --install-check-tools` installs its tools. To
install them in the directory of the deck in place of that:

1. Install [Node](https://nodejs.org), and make sure that `node` is on the `PATH`.
2. Go to the directory of the deck, or to a parent directory of it.
3. Install the npm packages and the browser:

   ```sh
   npm install --save-dev playwright axe-core
   npx playwright install chromium
   ```

4. In a Mix project, add the Hex package `playwright_ex` to the deps in `mix.exs`, and run
   `mix deps.get`:

   ```elixir
   {:playwright_ex, "~> 0.14", only: :dev, runtime: false}
   ```

   The binary holds this package, so the binary needs no step 4.

5. Run the check:

   ```sh
   mix expresso deck.exs --check=browser
   ```

The check looks for `node_modules/playwright/cli.js` as it looks for axe-core. To use a
different copy, give its path in `EXPRESSO_PLAYWRIGHT`. To use a different browser than the
Chromium of Playwright, give its path in `EXPRESSO_CHROMIUM`.

A problem of the keys names the key and the step, such as
`The keys: j at 2.1 shows 2.1, and not the next step 2.2`. A problem of the script gives
the message of the error, such as `The script: TypeError: x is undefined`.

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

`--check=a11y` gives the low contrast as a problem, at the first step that has it:

```text
Check of check_deck.exs: 1 slide
Checks: the render, the theme, the text for a screen reader, the layout at 1920 × 1080, and axe-core at each step and in each view
Browser: /home/user/.cache/ms-playwright/chromium_headless_shell-1194/chrome-linux/headless_shell

Notes:
  - The document is 259 KB.

Problems:
  - Slide 1 “the plan”, step 1: color-contrast, Elements must meet minimum color contrast ratio thresholds: the text area “Notes for the speaker go in the notes, n…”

1 problem.
```

A problem of axe-core names the step or the view, the rule, and each element that fails.
The name of an element is its kind and the first 40 characters of its text, as the layout
check gives it. To correct the deck, give the class `quiet` of that text area a color with
more contrast, or remove the class. Then run the check again, until it gives
`No problems.`

The most frequent problem is dimmed text. To correct it, see
[Keep dimmed text readable](make-a-deck-accessible.md#keep-dimmed-text-readable).

## Check a deck in a continuous integration job

This job of GitHub Actions runs the accessibility check for a deck in a Mix project. The
runner of GitHub has Chrome on its `PATH`:

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

For `--check=browser`, install Playwright and its Chromium in place of the step of
axe-core, and add `playwright_ex` to the deps of the project:

```yaml
      - run: npm install --no-save playwright axe-core
      - run: npx playwright install --with-deps chromium
      - run: mix expresso deck.exs deck.html --check=browser
```
