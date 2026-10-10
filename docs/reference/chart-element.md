# The chart element

The `chart` element draws a bar chart, a line chart or a pie chart from numbers in the deck
or in a CSV file. The document holds the chart as SVG, so it needs no script and it prints.

```elixir
slide "orders" do
  chart :bar do
    title "Orders and returns each year"
    categories ["2023", "2024", "2025"]
    reveal true
    series "Orders", [180, 240, 310]
    series "Returns", [22, 19, 25]
  end
end
```

`Expresso.Builder` takes the same options, such as
`chart(:bar, title: "Orders", categories: ["2025"], elements: [series("Orders", [310])])`.

## The options of the chart

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | `:bar`, `:line` or `:pie` | The kind of the chart. |
| `title` | A string, required | The name of the chart for a screen reader, and the caption of its table. |
| `categories` | A list of strings | The name of each category, such as each year. |
| `src` | The path of a CSV file | The categories and the series, in place of `categories` and `series`. A path is relative to [the root option](root-option.md) of the deck, or to the working directory of the command. |
| `values` | `true` or `false` | Show the value of each bar. The default is `true`. |
| `reveal` | `true` or `false` | Show each series at its own step. The default is `false`. A pie takes no `reveal`. |
| `dim` | `true` or `false` | Dim each series when a later series shows. The default is `false`. |
| `frames` | A string | The heading of the column of the CSV file that names the frame of each row. Requires `src`. |
| `frame_label` | `:top_right`, `:top_left` or `:none` | The place of the label of the frame in a chart with frames. The default is `:top_right`. |
| `sort` | `true` or `false` | Put the categories of a bar chart in order of their totals, from the largest, in each frame. The default is `false`. |
| `count` | `true` or `false` | Count each number from the value of one frame to the value of the next. The default is `false`, and the numbers fade. |
| `thumbnail` | `:first`, `:last` or the number of a frame | The frame that the overview and the menu of the slides show. The default is `:first`. |
| `width` | A CSS width, such as `"900px"` or `"70%"` | The width of the chart. A percentage is a part of the width of the slide. The default is `80%`. |
| `class` | CSS class names | See [the class option](class-option.md). |

The chart also takes the overlay options, such as `at`, `effect` and the `on` entity. See
[the overlay options](overlay-options.md).

## The options of a series

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | A string | The name of the series. |
| The second argument | A list of numbers | One value for each category, in the order of the categories. |
| `class` | CSS class names | See [the class option](class-option.md). |

A series also takes the overlay options, so a series can show at its own step without
`reveal`.

## The frames

A `frame` entity holds the values of the series at one point in time. Its argument is the
label of the frame, such as `"2024"`, and it holds one `series` entity for each series of the
chart. A chart with frames holds no `series` of its own:

```elixir
slide "regions" do
  chart :bar do
    title "Orders by region each year"
    categories ["North", "South"]

    frame "2024" do
      series "Orders", [120, 180]
    end

    frame "2025" do
      series "Orders", [210, 170]
    end
  end
end
```

`Expresso.Builder` takes the frames in the `timeline` key, such as
`chart(:bar, title: "Orders", categories: ["North"], timeline: [frame("2024", elements: [series("Orders", [120])])])`.

These rules apply to the frames:

- The first frame shows at each step of the chart until the second frame. Each later frame
  takes one step, after the steps of the series, and shows until the next frame. The last
  frame shows to the last step of the slide.
- When the chart takes no step of its own, the first frame takes one, so the second frame
  does not show at the first step of the chart.
- The frames of a chart with an absolute step, such as `at 3`, start at that step, and the
  counter of the slide does not change.
- Each frame holds the series of the first frame, with the same names in the same order.
- Only the series of the first frame take the overlay options and the `class` option. The
  `reveal` and `dim` options of the chart apply to them.
- The axis holds each value of each frame, so it does not change from frame to frame.
- The label of the frame goes into the row of the legend. Each frame has a copy of the
  label, and the copies fade. With `frame_label :top_left`, the legend starts after the
  label.

At a change of the frame, a bar moves to its new value, a line moves each point, and a slice
of a pie changes its angle. A number fades to its new value, or counts to it with `count true`.
The marks move with the `speed` and the `easing` of the chart. See
[the overlay options](overlay-options.md).

On paper and in the handout view, a chart with frames shows each frame as a small chart in a
grid, with its label under it. The present view, the speaker view and the overview show the
chart that moves.

## The effect `:grow`

A chart or a series with the effect `:grow` grows at the step at which it shows. A bar grows
from the base line, a line opens from the left, and a pie opens clockwise from the top. The
chart does not change its size. With `count true`, a number counts from zero.

## The browsers

The marks of a chart with frames or with the effect `:grow` move with registered custom
properties. Chrome 85, Safari 16.4 and Firefox 128 support them. An earlier browser shows the
first frame. The numbers with `count true` need the script of the presenter.

## The kinds

| Kind | The series | The labels |
| --- | --- | --- |
| `:bar` | One or more. Each category has a group of bars, one for each series. | The value of each bar, and the categories under the axis. |
| `:line` | One or more. Each series is a line with a dot for each value. | The name and the last value at the end of each line. |
| `:pie` | Exactly one. Each category is a slice, from the top and clockwise. | The name and the part in percent of each slice, in a legend at the right. |

A bar chart and a line chart have one axis, which starts at zero and holds each value, with
approximately five round ticks. The axis stays the same at each step, so it does not move
when a series shows. A chart with two or more series has a legend above the plot, and each
item of the legend shows and dims with its series.

## The CSV file

The first row holds a heading for the categories, then the name of each series. Each other
row holds a category, then one number for each series. A cell is the text between two
commas, with no quotes:

```
Month,Web,Phone,Shop
Jan,420,310,150
Feb,450,360,140
```

With the `frames` option, one more column names the frame of each row. Of the other
columns, the first holds the category, and each other column holds a series. The frames have
the order of their first row. Each frame holds each category of the first frame one time, in
any order:

```
year,month,Web,Shop
2024,Jan,420,150
2024,Feb,450,140
2025,Jan,480,140
2025,Feb,560,120
```

The watch mode renders the deck again after a change to the file.

## The errors

The compiler gives an error for these:

- a series with a different number of values than the categories;
- a chart with no categories and no `src`, or with both;
- a chart with no series, or with more than 8 series;
- a pie with more than one series, with more than 8 categories, with a negative value, or
  with `reveal`.
- a chart with frames and a `series` of its own;
- a frame with series that are not the series of the first frame, in the same order;
- a series of a later frame with an overlay option or a `class`;
- `sort` on a line chart or a pie, `count` on a chart without frames, and `frames` without
  `src`;
- a `thumbnail` with the number of a frame that the chart does not have.

The render gives an error for a CSV file that it cannot read, and for a row with a cell
that is not a number. The message names the line.

## The colors

The theme gives the colors of the series as `--chart-1` to `--chart-8`, in a fixed order:
blue, orange, aqua, yellow, magenta, green, violet and red. A light theme and a dark theme
get different steps of the same colors. A reader with a deficit of color vision can tell
each pair of neighbors apart. A chart has at most 8 series, so put the smallest into a
series "Other".

The text of a chart has the colors of text, and only a mark has the color of its series. A
deck can set `--chart-1` to `--chart-8`, `--chart-width` and `--chart-height`, the largest
height, in [the css option](css-option.md). The default height is `72vh`, which leaves room
for the heading.

## The HTML

The document writes a `figure` element with the classes `chart` and `chart-bar`,
`chart-line` or `chart-pie`. It holds an `svg` element with `role="img"` and the `title`
as its `aria-label`, and a `table` with the class `chart-table` that holds each value. The
style sheet hides the table from the eye and not from a screen reader. Each series is a
`g` element with the class `chart-series`.

A chart with frames or with the effect `:grow` has a `data-el` attribute. Its marks have the
class `chart-mark`, `chart-segment`, `chart-arc` or `chart-gap`, and the label of the frame
has the class `chart-frame`. A number with `count true` is a `tspan` with the class
`chart-count`. The grid of the frames is a `div` with the class `chart-frames`, and each small
chart is a `figure` with the class `chart-copy`.
