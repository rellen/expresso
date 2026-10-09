# The layout check

The layout check finds the parts of a deck that do not fit the window. `?check` at the
end of the address of the present view starts it, such as `deck.html?check`. The speaker
view does not run it.

For the steps of a check, see [Check that a deck fits the screen](../how-to/check-the-layout.md).

## When it runs

The check runs one time, after the load of the document and of its fonts. It shows each
step of each slide in sequence, with the time of each animation at zero, and it measures
the slide at that step. Then the presenter shows the step of the address again.

The check measures the window at that time. A change of the size of the window after the
check does not change the report. Reload the page for a new check.

## The problems

| Problem | When | The report gives |
| --- | --- | --- |
| Past an edge | The box of an element goes more than 1 pixel past the left, top, right or bottom edge of the window. | The edge, and the distance in pixels. For two or more edges, the edge with the largest distance. |
| A line breaks | A line of a code element is more than 1.5 times the line height of the element. | The number of lines that break in the code element. |

The check measures these elements, and the content of each:

- the heading of the slide,
- a text box, a text area, an image, a list, a table, a quotation, a code element, a
  formula, a diagram, an embed, a `columns` element, a `column` and a shape,
- the content of an element: a `math` element, an `img` element, an `svg` element, a
  `pre` element, an `iframe` element and a `table` element.

The `svg` element of a line or an arrow of [the shape element](shape-element.md) covers the
whole slide, so the check measures its `line` element, and not the `svg` element. The check
measures the `svg` element of [the chart element](chart-element.md). The table of a chart
is for a screen reader, so the check does not measure it.

The check measures what an element shows, and not its box. A tag of the content shows its
box. Each other element shows its text and its content, so the check measures the smallest
box that holds them. A text box is as wide as the slide, so its box goes past an edge when
it moves, while its text can stay in the window.

An element that does not show at the step, as an overlay specifies, is not measured. A part
of a diagram is not measured, because a part can move past the box of its diagram.

An element counts only when no element inside it goes past the same edge. Thus the report
names the innermost element: a formula in a column, and not the column.

The check gives each problem one time, at the first step that has it.

## The report

The report is an `aside` element with the id `layout-check`, in the lower right corner of
the window. It holds:

- the size of the window, and the number of problems, such as
  `Layout check at 1920 × 1080: 2 problems`,
- one link for each problem, such as
  `Slide 6, step 3: the math “s = o + x” goes 120 px past the right edge`. The link goes
  to the slide and the step of the problem,
- the button `Close`, which removes the report.

The name of an element is its kind and the first 40 characters of its text. An image gives
its `alt` text, and a diagram gives the `title` of its SVG.

The console of the browser gets one warning for each problem, with the text of its link.
The `body` element gets `data-layout="ok"` for no problem, and `data-layout="problems"`
for one or more problems.

The report does not show on paper.

## What the check does not find

The check reads the place and the size of each element. It does not find:

- a color with low contrast. The theme option checks the colors of a theme, and the
  compiler gives a warning for a color of a map under its minimum. See
  [The theme option](theme-option.md),
- text that is too small for the room,
- an element that covers another element inside the window.
