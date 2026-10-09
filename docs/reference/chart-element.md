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

The watch mode renders the deck again after a change to the file.

## The errors

The compiler gives an error for these:

- a series with a different number of values than the categories;
- a chart with no categories and no `src`, or with both;
- a chart with no series, or with more than 8 series;
- a pie with more than one series, with more than 8 categories, with a negative value, or
  with `reveal`.

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
