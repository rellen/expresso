# Check that a deck fits the screen

This guide shows how to find the parts of a deck that do not fit the screen of the talk:
an element that goes past an edge, a line of code that breaks, and a chart or a diagram
with text that is too small to read. The layout check of the presenter finds them at each
step. For each value of the check, see
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

## Read a report

This deck has two problems. The code of slide 1 has a line that is too long, and the box of
slide 2 moves too far at step 2:

```elixir
defmodule Examples.LayoutCheck do
  use Expresso

  slide "a long line" do
    heading "A long line"

    code "elixir" do
      text ~S"""
      def total(orders), do: orders |> Enum.filter(&paid?/1) |> Enum.map(& &1.amount) |> Enum.sum()
      """
    end
  end

  slide "a long move" do
    heading "A long move"

    text_box do
      on 2, set: [x: "12rem"]
      text_area(text: "This box moves past the right edge at step 2")
    end
  end
end

Examples.LayoutCheck
```

The check gives one line for each problem, with the slide and the step:

![The report in the lower right corner gives a line of code that breaks on slide 1, and a text that goes 407 px past the right edge at step 2 of slide 2](https://raw.githubusercontent.com/rellen/expresso/media/layout-check.png)

To correct the deck, put a line break into the code, and give the box a smaller distance,
such as `x: "4rem"`. The next two sections give more ways.

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
- Give a smaller distance to an element that moves with `set: [x: ...]` or `set: [y: ...]`.
  The check measures the text of the element, so the distance can be as large as the space
  next to the text.
- Put fewer elements on the slide, or divide the slide into two slides.

## Correct a chart or a diagram with small text

A chart or a diagram takes the height that is left in the slide, and its text becomes
smaller with it. The report gives the size of the smallest text, such as
`the text in the chart “Energy” is 10.2 px, less than 1/60 of the window height (12 px)`.
Do one of these:

- Make the heading shorter. At 1280 × 720, a heading of three lines takes approximately one
  half of the window.
- Move the other elements of the slide, such as a text area or a footnote, to a different
  slide.
- Move the element out of a `columns` element, so it gets the full width of the slide.
- For a diagram, give its text a larger font size in its SVG file.

## Check a deck with no window

`mix expresso deck.exs --check=layout` runs the check in a headless browser at
1920 × 1080, writes the problems, and exits with the status 1 for a problem. A continuous
integration job can run it. See [Check a deck before the talk](check-a-deck.md).
