# Check that a deck fits the screen

This guide shows how to find the parts of a deck that do not fit the screen of the talk:
an element that goes past an edge, and a line of code that breaks. The layout check of the
presenter finds them at each step. For each value of the check, see
[The layout check](../reference/layout-check.md).

## Check a deck in a browser

1. Render the deck:

   ```sh
   mix expresso deck.exs deck.html
   ```

2. Open `deck.html?check` in the browser.
3. Make the window the size of the screen of the talk, such as 1920 × 1080. The size of the
   window changes the layout. A full screen with the key `f` gives the size of the screen.
4. Reload the page. The check runs after the load.
5. Read the report in the lower right corner. The first line gives the size of the window
   and the number of problems.
6. Click a problem. The presenter goes to its slide and its step.
7. Correct the deck, and do the steps again until the report gives no problems.

The console of the browser gets the same lines as the report.

## Correct a line of code that breaks

A line breaks when it is longer than the width of its code element. Do one of these:

- Put a line break into the line. Two short lines are easier to read than one long line.
- Give the code element more width. Remove the `columns`, or put the code element in a
  wider `column`.
- Make the code smaller for the whole deck with the `css` option:

  ```elixir
  css ~S"""
  .code pre {
    font-size: 0.46rem;
  }
  """
  ```

## Correct an element that goes past an edge

The report names the innermost element that goes past the edge, such as a formula in a
column. Do one of these:

- Give an image or a diagram a `width` option, such as `width "70%"`.
- Move the element out of a `columns` element, so it gets the full width of the slide.
- Put fewer elements on the slide, or divide the slide into two slides.

## Check a deck with no window

A browser with no window can run the check, for example in a continuous integration job.
Chromium writes the document after the check with `--dump-dom`, and the `body` element
then has `data-layout="ok"` or `data-layout="problems"`:

```sh
chromium --headless --window-size=1920,1167 --virtual-time-budget=10000 \
  --dump-dom "file:///path/to/deck.html?check" | grep -o 'Layout check at [0-9][^<]*'
```

The window of a headless Chromium is larger than its page, so the height in
`--window-size` is more than 1080. Read the size in the report, and change the height until
the report gives the size of the talk. The difference can change with the version of
Chromium. `--virtual-time-budget` makes Chromium wait for the fonts and the check.

To stop a job on a problem, look for the value `ok`:

```sh
chromium --headless --window-size=1920,1167 --virtual-time-budget=10000 \
  --dump-dom "file:///path/to/deck.html?check" | grep -q 'data-layout="ok"'
```

The name of the command can be `google-chrome` or `chrome`.
