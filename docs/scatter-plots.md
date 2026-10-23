# Scatter plots

This document gives the design for the chart kinds `:scatter` and `:bubble`, and the record
of their progress. A scatter plot shows each item as one mark, and the mark shows up to five
values of the item: its x position, its y position, its symbol, its color and its size. The
document records ten decisions, and each is settled. Issue #426 holds the same plan.

## The problem

A talk often compares many items on two or more measures, such as the cost and the speed of
each service, or the income and the life expectancy of each country. A bar chart and a line
chart put each value on a category, so they cannot show two numbers for one item. The author
must draw the plot in another tool and import it as an image, and then the plot cannot take
steps.

## The constraints

- The output stays one HTML file. The compiler calculates each place, and the presenter
  script calculates no layout.
- A scatter plot obeys the overlay contract: `at`, `on`, `effect`, `reveal`, `dim`, `class`
  and `morph`. See `docs/overlays.md`.
- The handout view and paper show each step that the present view can show.
- A screen reader gets each point with each of its values.
- The theme gives each color, so each theme and its dark variant work.

## The encodings

| Encoding | The data | The scale |
| --- | --- | --- |
| x position | A number | A linear axis from the data, or the `x_range` option. `x_scale :log` gives a logarithmic axis. |
| y position | A number | A linear axis from the data, or the `y_range` option. `y_scale :log` gives a logarithmic axis. |
| Symbol | A category, such as `"EU"` | A circle, a square, a triangle, a diamond, a cross and a star, in this order |
| Color | A category, or a number | A category takes `--chart-1` to `--chart-8` of the theme. A number takes the scale of the `color_scale` option. |
| Size | A number more than zero | The area of the mark grows in proportion to the number |

## The decisions

| Number | Question | Decision |
| --- | --- | --- |
| 1 | The name of the entity | Both: a `point` entity, and a `series` entity that groups points and gives them a default symbol and color. |
| 2 | A trend line | `trend :linear`, one least-squares line for each group. |
| 3 | A bubble chart | `:scatter` with `size`, and the kind `:bubble` too. `:bubble` needs a `size` for each point. |
| 4 | Overlap | Each of the three: `opacity`, a seeded `jitter`, and the larger marks drawn first. |
| 5 | A color from a number | An option for each scale: `color_scale :sequential` (the default), `:diverging`, or two roles of the theme. |
| 6 | The code | A new family `:points` in `Expresso.Element.Chart.Kinds`, and a new module `Expresso.Element.Chart.Scatter`. `Expresso.Element.Chart` sends each function of a scatter plot to that module, so the code of the other kinds does not change. |
| 7 | The marks | Each mark has its place in the channels of `Expresso.Element.Chart.Motion`, also in a chart with one frame. One code path then draws a chart without frames, a chart with frames and a chart with the effect `:grow`. |
| 8 | The groups of the steps | The check puts the points into groups, and each group is a child of the chart. A `series` is one group. Without series, each color category is one group. Without series and color categories, `reveal true` gives each point its own group, and a chart without `reveal` has one group. |
| 9 | A symbol and a color that are not a category | A point and a series take a symbol by its name, such as `:square`, and a color by its role, such as `:chart_3` or `:accent`. Such a mark is in no legend of the categories. |
| 10 | The order of the marks | Inside a group, the larger marks come first in the SVG. The groups keep the order of the data, because a group holds the steps of its marks. |

## The design

- `point "api", x: 1200, y: 840, symbol: "EU", color: "EU", size: 30_000` gives one point.
  The name is the label of the mark, and the `highlight` option uses it.
- `Expresso.Element.Point` is the struct of a point. A point takes the overlay options, so a
  point can show at its own step.
- `Expresso.Element.Series` gets the keys `elements`, `symbol` and `color`. A series of a
  scatter plot holds its points in `elements`, and a series of the other kinds keeps its
  `values`.
- `Expresso.Element.Chart.Scatter` checks the points, makes the groups, calculates the
  scales, the legends, the labels and the trend lines, and draws the marks. It uses `ref/2`,
  `grow/2`, `style/1` and `frame_label/1` of `Expresso.Element.Chart.Motion`.
- A mark is a group with the class `chart-mark` at the origin of the SVG. The channels
  `--x<n>` and `--y<n>` give its place, `--r<n>` its scale, and `--h<n>` the place of its
  color on the scale of a number. A frame changes the channels at its steps, and the
  registered properties of the theme move the mark.
- Each mark has a `data-keys` attribute with the key of its point, of its color category, of
  its symbol category and of its series. A group of the `highlight` option names these keys,
  so the rules of the highlight of a chart dim the other marks.
- A trend line is a line from 0 to 1 that a matrix moves to its two ends, as a segment of a
  line chart. It shows at the steps of the last point of its group.
- The table for a screen reader has one row for each point, with its name and each value.
- `docs/reference/chart-element.md` gives the options. A how-to guide gives the tasks, with
  example decks and their GIFs.

## The stack

1. This document.
2. The kind `:scatter`, the `point` entity, the axes, `x_range`, `y_range`, `x_scale`,
   `y_scale`, the table, and the errors of a point.
3. The symbol, the color of a category, the size, the kind `:bubble`, the legends, `opacity`,
   and the order of the marks.
4. The `series` of points.
5. The CSV file.
6. The labels.
7. The steps: `reveal`, `dim`, the effect `:grow` and `highlight`.
8. The frames.
9. The trend lines and `jitter`.
10. The color from a number and `color_scale`.
11. The guide, the example decks and their GIFs.

## The progress

| Pull request | State |
| --- | --- |
| 1. This document | Done |
| 2. The points and the axes | Done. `Expresso.Element.Chart.Scale` gives the ticks of a linear axis without zero and of a logarithmic axis. `Plot.step/1` is public, so the two kinds of axis use the same round steps. |
| 3. The symbol, the color and the size | Done. `Expresso.Element.Chart.Encoding` gives the symbols, the colors and the radii, and `Expresso.Element.Chart.Scatter.Legend` draws the legends in a column at the right. Each category of the color is one group. A mark takes its color as an inline `--series`, so a category and a role use one rule. A linear axis now has a margin of 5 percent at each end. |
| 4. The series of points | Done. The `values` of a series are optional. `Expresso.Builder` takes a list as the keyword list only when it is empty or starts with a tuple, so `series("Orders", [1, 2])` keeps its values. A point of a series takes no category, because the series is its category. |
| 5. The CSV file | Done. `Expresso.Element.Chart.Scatter.Data` reads the points from the rows of `Expresso.Element.Chart.Csv.rows/3`. The check of the points runs without the options of the file, and the chart keeps them. |
| 6. The labels | Done. `Expresso.Element.Chart.Scatter.Labels` tries eight places for each label, in the order of the points, and takes the first place that covers no label and no mark inside the plot. A label reads the channels of its mark, so it moves with the mark. |
| 7. The steps | Done. With `reveal` and without categories of the color, each point is a group. Each mark has `data-keys` with the keys of its point, its categories and its series, so the rules of the highlight of a chart dim the other marks. A point with an overlay has a group around its mark and its label. A browser test makes sure of the visibility at each step of `reveal`, and of the dimmed marks at each step of `highlight`. The list of the formatter now holds the options of the stack. |
| 8. The frames | Done. A later frame holds the points of the first frame by name. The marks and the labels read the channels of each frame, and `Expresso.Element.Chart.Motion.rules/3` writes the rules of the frames, as for the other kinds. The `frames` option names a column of the CSV file. A browser test makes sure that a mark moves to its place in the next frame. |
| 9. The trend lines and `jitter` | Done. `Expresso.Element.Chart.Scatter.Trend` fits the line in the fractions of the axes, cuts it at the ends of the plot, and gives the move of the jitter from `:erlang.phash2/2`. A line has four channels, so it moves between frames. A chart without groups has one line, in `--muted`. A test makes sure that the ends of a line of points on a line are the marks of the first and the last point. |
| 10. The color from a number | To do |
| 11. The guide, the example decks and their GIFs | To do |
