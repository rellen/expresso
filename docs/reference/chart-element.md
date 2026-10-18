# The chart element

The `chart` element draws a chart from numbers in the deck or in a CSV file.
[The kinds](#the-kinds) gives each kind of chart. The document holds the chart as SVG, so the
chart needs no script, and it prints.

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
| The first argument | `:bar`, `:line`, `:pie`, `:treemap`, `:sunburst`, `:sankey`, `:alluvial`, `:parallel_sets` or `:chord` | The kind of the chart. |
| `title` | A string, required | The name of the chart for a screen reader, and the caption of its table. |
| `categories` | A list of strings | The name of each category, such as each year. A category of a treemap or a sunburst can also be a list of its levels. A category of a chart of flows is a path of nodes. |
| `category_label` | A string | The name of the categories, such as `"Year"`. See [the names of the axes](#the-names-of-the-axes). A chart with `src` takes the first heading of its file. |
| `value_label` | A string | The name of the values, such as `"Widgets an hour"`. See [the names of the axes](#the-names-of-the-axes). |
| `src` | The path of a CSV file or a TSV file | The categories and the series, in place of `categories` and `series`. A path is relative to [the root option](root-option.md) of the deck, or to the working directory of the command. |
| `delimiter` | One character, such as `";"` | The character between two cells of the `src` file. The default is a tab for a file that ends in `.tsv`, and a comma for each other file. Requires `src`. |
| `values` | `true` or `false` | Show the value of each bar. The default is `true`. |
| `reveal` | `true` or `false` | Show each series at its own step. A chart of flows has its own steps, which [reveal](#reveal) gives. The default is `false`. A pie takes no `reveal`. |
| `dim` | `true` or `false` | Dim each series when a later series shows. The default is `false`. See [a dimmed series](#a-dimmed-series). |
| `highlight` | A list of groups, such as `["Returns", ["Orders", "Repairs"], "2024"]` | Each series shows at each step. Each group of series or of categories is in focus at its own step, and the rest of the chart dims. A chart of flows takes the names of nodes in place of categories. Each kind of chart takes it. See [the highlight option](#the-highlight-option). |
| `whole_first` | `true` or `false` | With `highlight`, the whole chart shows in full color for one step before the first group. The default is `false`. |
| `separator` | A string | The text between two levels of a category of a treemap or a sunburst. The default is `"/"`. |
| `levels` | A list of strings | The headings of the CSV columns that hold the levels of a treemap or a sunburst, from the top level down. For a chart of flows, the headings of the CSV columns that hold the nodes of each path. Requires `src`, but an alluvial chart or a parallel sets chart can take `levels` without `src` to give the title of each column. |
| `frames` | A string | The heading of the column of the CSV file that names the frame of each row. Requires `src`. |
| `frame_label` | `:top_right`, `:top_left` or `:none` | The place of the label of the frame in a chart with frames. The default is `:top_right`. |
| `sort` | `true` or `false` | Put the categories of a bar chart in order of their totals, from the largest, in each frame. A bar chart without frames, and each copy in the handout view and on paper, also uses this order. The default is `false`. |
| `count` | `true` or `false` | Count each number from the value of one frame to the value of the next. The default is `false`, and the numbers fade. |
| `thumbnail` | `:first`, `:last` or the number of a frame | The frame that the overview and the menu of the slides show. The default is `:first`. |
| `width` | A CSS width, such as `"900px"` or `"70%"` | The width of the chart. A percentage is a part of the width of the slide. The default is `80%`. |
| `class` | CSS class names | See [the class option](class-option.md). |
| `morph` | A string | A key of the morph. See [the morph option](morph-option.md). |

The chart also takes the overlay options, such as `at`, `effect` and the `on` entity. See
[the overlay options](overlay-options.md).

## The options of a series

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | A string | The name of the series. |
| The second argument | A list of numbers | One value for each category, in the order of the categories. |
| `class` | CSS class names | See [the class option](class-option.md). |
| `morph` | A string | A key of the morph. See [the morph option](morph-option.md). |

A series also takes the overlay options, so a series can show at its own step without
`reveal`.

## The highlight option

The `highlight` option puts one group of series or of categories in focus at each step.
Each series shows at each step:

```elixir
slide "repairs" do
  chart :bar do
    title "Orders, returns and repairs"
    categories ["2023", "2024", "2025"]
    highlight ["Returns", ["Orders", "Repairs"], "2024"]
    series "Orders", [180, 240, 310]
    series "Returns", [22, 19, 25]
    series "Repairs", [60, 75, 90]
  end
end
```

| Step | The group | The rest of the chart |
| --- | --- | --- |
| The step of the group | Full color | Dimmed. See [a dimmed series](#a-dimmed-series). |
| A step of no group | Full color | Full color |

A group is the name of a series or of a category, or a list of names. The names of one
group are all series or all categories. The groups take their steps from the counter of
the slide, one step each, as the items of a list with `reveal true` do. The first group is
thus in focus at the first step of the slide. `whole_first true` gives the chart one step
with no group in focus before the first group, as a `pause()` in front of the chart does.
See [the overlay options](overlay-options.md).

A group of categories keeps these marks in full color, and each other mark of a category
dims:

| Kind | The marks of a category | Each step of a group of categories also dims |
| --- | --- | --- |
| `:bar` | Its bars, their values and its label under the axis | – |
| `:line` | The dot of each line at the category and its label under the axis. The last category also keeps the label at the end of each line. | Each line |
| `:pie` | Its slice and its part of the legend | – |
| `:treemap` | The box and the label of the part, of each group above it and of each part under it | – |
| `:sunburst` | The arc and the label of the part, of each group above it and of each part under it, and the part of the legend of its group of the top level | – |
| `:sankey`, `:alluvial` | The node, its label, and each link into the node or out of it | – |
| `:parallel_sets` | The node, its label, and each ribbon through the node | – |
| `:chord` | The arc of the node, its label, and each chord to the node or from it | – |

A category of a treemap or a sunburst is a part or a group. Give its levels with the
`separator` of the chart, such as `"Production/Press"` for the part "Press" of the group
"Production", or `"Production"` for the whole group. A group in focus thus keeps each of
its parts in full color, and a part in focus keeps the groups around it.

A chart of flows takes the names of nodes in place of categories. Give the name of a node
as its flows give it, and not its `label`. A name in an alluvial chart or in a parallel
sets chart puts the node with that name in each column in focus. A node in focus keeps
its links in full color, and the nodes at the other end of the links dim.

The legend of a bar chart or a line chart names the series, so it stays in full color at
the step of a group of categories.

Each kind of chart takes the option. A chart with `src` takes the names of the series and
of the categories of its file. The key `d` shows each series and each category in full
color until the next step, as it does for code. See [the key d](code-element.md#the-key-d).

## A dimmed series

A series dims at a step of `highlight` at which it is not in focus, and at a step at which
`dim true` dims it. A mark of a category dims in the same way at the step of a group of
other categories:

- Each mark of the series, such as a bar, a line, a dot and its color in the legend, fades
  to the opacity `--chart-dim-opacity`. The default is 0.3.
- Each text of the series, such as a value and its name in the legend, takes the dimmed
  color of the text, `--text-dim`. The label of a category under the axis takes
  `--muted-dim`. The text thus stays at the contrast of a dimmed text. See
  [the dim_contrast option](dim-contrast-option.md).

A deck can set `--chart-dim-opacity` in [the css option](css-option.md), such as `0.5`
for a lighter dim. The handout view and paper show the dimming of each step.

## The names of the axes

| Option | Bar chart and line chart | Each chart, in its table |
| --- | --- | --- |
| `category_label` | Under the axis of the categories, in the color `--muted`. | The header of the column of the categories. Without it, the corner of the table is an empty cell. |
| `value_label` | Beside the axis of the values, turned to read from the bottom up, in the color `--muted`. | After the title in the caption, such as `Orders (Widgets an hour)`. |

The plot gets smaller to make room for each name. A pie, a treemap and a sunburst have no
axis, so the names go into the table only.

A chart with `src` takes the first heading of its file as `category_label`. In a file with a
column of frames, it takes the first heading of the other columns. With `levels`, it takes
the headings of the levels, joined by `/`. An empty heading gives no name. The
`category_label` option wins over the heading of the file.

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
- The frames of a chart with an absolute step, such as `at from: 3`, start at that step, and
  the counter of the slide does not change.
- Each frame starts at a step of the chart. A closed specification, such as `at 3` or
  `at :next`, shows the chart at one step only, so the verifier refuses the second frame.
  Write `at from: 3` or `at from: :next`.
- Each frame holds the series of the first frame, with the same names in the same order.
- Only the series of the first frame take the overlay options and the `class` option. The
  `reveal` and `dim` options of the chart apply to them.
- The axis holds each value of each frame, so it does not change from frame to frame.
- The label of the frame goes into the row of the legend. Each frame has a copy of the
  label, and the copies fade. With `frame_label :top_left`, the legend starts after the
  label.

At a change of the frame, a bar moves to its new value, a line moves each point, and a slice
of a pie changes its angle. A number fades to its new value, or counts to it with `count true`.
A count stops on each digit of the value of its frame, such as `1.34`.
The marks move with the `speed` and the `easing` of the chart. See
[the overlay options](overlay-options.md).

On paper and in the handout view, a chart with frames shows each frame as a small chart in a
grid, with its label under it. The present view, the speaker view and the overview show the
chart that moves.

## The effect `:grow`

A chart or a series with the effect `:grow` grows at the step at which it shows. A bar grows
from the base line, a line opens from the left, and a pie and a sunburst open clockwise from
the top. A box of a treemap grows from its top left corner. The labels of a treemap and of a
sunburst show after their boxes and arcs grow. The
chart does not change its size. With `count true`, a number counts from zero.

## The browsers

The marks of a chart with frames or with the effect `:grow` move with registered custom
properties. Chrome 85, Safari 16.4 and Firefox 128 support them. An earlier browser shows the
first frame. The numbers with `count true` need the script of the presenter.

A label of a value or of the axis has each digit of its number and no exponent, such as
`0.00025`. The axis of very small values, such as `0.0000001`, has round ticks, and each tick has a label in the same form.

## The kinds

| Kind | The series | The labels |
| --- | --- | --- |
| `:bar` | One or more. Each category has a group of bars, one for each series. | The value of each bar, and the categories under the axis. |
| `:line` | One or more. Each series is a line with a dot for each value. | The name and the last value at the end of each line. |
| `:pie` | Exactly one. Each category is a slice, from the top and clockwise. | The name and the part in percent of each slice, in a legend at the right. |
| `:treemap` | Exactly one. Each category is a box, and a group holds its parts. | The name and the value of each part, and the name of each group in a strip at its top. |
| `:sunburst` | Exactly one. Each level of the groups is a ring, and each category is an arc of the outer rings. | The name of each arc, and the part in percent of each group of the top level, in a legend at the right. |
| `:sankey` | Exactly one. Each category is a path of nodes, and its value goes along each link of the path. | The name and the value of each node. See [the labels](#the-labels). |
| `:alluvial` | Exactly one. Each category is a path with one name for each column. | As a sankey, and a title over each column. See [an alluvial chart](#an-alluvial-chart). |
| `:parallel_sets` | Exactly one. Each category is a path with one name for each column, and it is one ribbon through the columns. | As an alluvial chart. See [a parallel sets chart](#a-parallel-sets-chart). |
| `:chord` | Exactly one. Each category is a path of nodes, as in a sankey, and each link is a chord between two arcs of a ring. | The name and the total of each node, outside its arc. See [a chord chart](#a-chord-chart). |

A bar chart and a line chart have one axis, which starts at zero and holds each value, with
approximately five round ticks. The axis stays the same at each step, so it does not move
when a series shows. A chart with two or more series has a legend above the plot, and each
item of the legend shows and dims with its series.

## The groups of a treemap and a sunburst

A slash in a category names a part of a group. The category `"Production/Press"` is the part
"Press" of the group "Production", and a category can have more levels, such as
`"Production/Line 4/Press"`. A category with no slash is a part of the top level. The value
of a group is the sum of its parts. The spaces next to a slash do not count.

Three other forms give the same groups:

- The `separator` option gives a different text between two levels, such as `" > "` in
  `"I/O > Disks"`. The default is `"/"`.
- A category can be a list of its levels, such as `["I/O", "Disks"]`. A list needs no
  separator, so a level can hold any text.
- The `levels` option names the columns of a CSV file that hold the levels. See "The CSV
  file".

These rules apply to the groups:

- The top level has at most 8 groups, one for each color. The parts of a group have tints
  of its color, lighter for a deeper level.
- Each level has a name.
- A category is not also a group. A category `"Office"` and a category `"Office/IT"` give an
  error, because "Office" then has a value and parts.
- The parts of a group can be anywhere in the list of the categories.
- The order of the parts comes from the values of the first frame, from the largest. The
  order stays the same in each frame, so a box or an arc moves and changes its size.
- A label shows only when it fits its box or its arc. The table for a screen reader holds
  each value.
- A treemap and a sunburst take no `reveal` and no `sort`. The `values` option of a treemap
  shows or hides the values of the parts.

A treemap divides its box into rectangles that are close to squares. A sunburst has a hole in
its center, and each level is a ring of the same width. A treemap with frames has the label of
the frame in a row above the boxes.

## The charts of flows

A **chart of flows** shows how an amount goes between the nodes of a graph. A sankey, an
alluvial chart, a parallel sets chart and a chord chart are charts of flows. In this section, a **flow** is an item of the data, and a **link** is the mark
that shows one or more flows.

### The flows

A `flow` entity gives one flow: the node where it starts, the node where it ends, and its
value. A chart with flows holds no `categories`, no `series` and no `src`:

```elixir
slide "energy" do
  chart :sankey do
    title "Energy in a year"
    value_label "GWh"
    flow "Coal", "Electricity", 120
    flow "Gas", "Electricity", 95
    flow "Electricity", "Homes", 215
  end
end
```

| Option of `flow` | Value | Effect |
| --- | --- | --- |
| The first argument | A string | The node where the flow starts. |
| The second argument | A string | The node where the flow ends. |
| The third argument | A number, zero or more | The value of the flow. |

The categories and one series give the same data. A category is a path of two nodes or more.
Examples are `["Coal", "Electricity"]`, `"Gas/Electricity/Homes"` with the `separator`, and a
row of a CSV file with the `levels` option. The value of a category goes along each link of
its path. The values of the same link add. In a sankey, a name is one node in the whole chart.

The table for a screen reader holds one row for each link. Its headers are "From", "To" and
the `value_label`, or "Value".

### The node entity

A `node` entity changes how the chart shows one node:

| Option of `node` | Value | Effect |
| --- | --- | --- |
| The first argument | A string | The name of the node in the flows. |
| `label` | A string | The text of the label and of the table. The default is the name. |
| `column` | An integer, 1 or more | The column of the node, from the left. The default comes from [the layout](#the-layout-of-a-sankey). A column that puts the target of a flow in the column of its source, or before it, makes the flow a back link. |
| `order` | An integer | The place of the node in its column, from the top. A node without `order` has the number of its place in the data. Thus `order: 0` puts a node at the top. |
| `class` | CSS class names | The classes of the `rect` of the node. See [the class option](class-option.md). |

`Expresso.Builder` takes the node entities in the `flows:` list of the chart, with the flows.
An example is
`chart(:sankey, title: "Energy", flows: [flow("A", "B", 1), node("B", label: "Bee")])`.

### The layout of a sankey

The layout obeys these rules:

1. A node with no flow into it is in the first column. Each other node is one column after
   its last source. A back link does not count, as [loops](#loops) tells. Thus a link can go across a column. The `column` option of a node entity
   sets the column of its node, and the columns after it move.
2. The height of a node is the larger of the flow into it and the flow out of it. One scale
   sets the height of each node. The nodes of each column are in the vertical middle of the
   chart.
3. The nodes of a column have the order of the data, or the `order` of their node entity. At
   each node, the links have the order of the nodes at their other ends, so few links cross.
4. A link is a ribbon between two Bézier curves. It leaves and enters each node
   horizontally, and its height is its value at each point.

A node has a color of the theme, in the order of the nodes in the data. The `order` option
does not change the color of a node. A link has a light color, made
from the color of its source and the color of the background.

### Loops

A flow back to an earlier node makes a loop. A loop has no first column, so the layout obeys
these rules:

1. A depth-first search from each node, in the order of the data, finds each flow back to a
   node on its path. These flows are the **back links**.
2. The layout finds the columns from the other links.
3. A link to the column of its source, or to an earlier column, is also a back link. A
   `column` of a node entity can make such a link.
4. A back link leaves the right side of its source, and it goes down to a lane under the
   nodes. It goes to the left in its lane, and it goes up into the left side of its target.
5. A shorter back link has a lane nearer to the nodes, so two back links do not cross.
6. The back links draw first, so the other links are on top of them.

A flow from a node to the same node gives an error.

### An alluvial chart

An alluvial chart is a sankey with one node for each name in each column. The place of a name
in its path sets its column. These rules apply:

- A name can go to the same name, such as "Car" to "Car".
- The nodes of one name have one color, and they have the same place in each column.
- The `levels` option gives a title to each column. The title is above the nodes. Without
  `src`, `levels` gives only the titles.
- A `flow` entity gives a path of two columns.
- A `node` entity applies to the name in each column. It takes no `column`.
- A row of the table names the column of each node, such as "Car (2020)", or "Car (Column 1)"
  without `levels`.

### A parallel sets chart

A parallel sets chart has the nodes of an alluvial chart. Each category is one ribbon from
the first column to the last. These rules apply:

- Each category names the same number of columns.
- Two categories with the same path add their values.
- A ribbon has the color of its node in the first column. Only the nodes of the first column
  have colors. The nodes of the other columns are gray.
- At each node, a ribbon has one place in one stack, so it does not break at the node.
- The stack of a node has the order of the nodes of each path, from the first column. Thus
  the ribbons of one first node stay together.
- The table has one row for each category. It has a column for each column title and a
  column for each frame.

### A chord chart

A chord chart takes the flows, the node entities and the table of a sankey. Only the drawing
is different. These rules apply:

- Each node is an arc of a ring. The arcs start at the top and go clockwise, in the order of
  the data or the `order` of their node entities.
- The length of an arc is the sum of the flow out of its node and the flow into it.
- A flow is a **chord** between two arcs. A chord has the width of its value at each end. Two
  quadratic Bézier curves join the two ends, with their control point at the center of the
  ring.
- In an arc, the chords out of the node come first, then the chords into it. Each part has
  the counterclockwise order of the other nodes, from the nearest one. Thus the chords of an
  arc do not cross.
- A chord has the color of its source.
- A label is outside its arc. It shows when its arc is 14 units long or more.
- The frames share one scale for the angles. A smaller total in a later frame thus leaves an
  empty part at the end of the ring.
- A node entity takes no `column`.

### The labels

A label shows the name of its node and, with `values true`, its value. Each label is at the
right of its node. The layout keeps space at the right edge for the widest label of the last
column. This space is a maximum of one third of the width.

A label shows when its node is 16 units high or more. A label of a shorter node shows when
its middle is one line or more from the middle of each other label in its column.

### The frames of a chart of flows

A `frame` holds `flow` entities, or one series. The frames share these items:

- the columns, the order and the colors of the nodes, from the links of all the frames;
- one scale for the heights.

A frame that does not hold a link has the value 0 for it. A node or a link with no value in a
frame does not show in that frame. The chart has one layer for each frame, and the links do
not move. At each step, the opacity of the previous layer decreases to 0, and the opacity of
the next layer increases to 1. The table has a column for each frame.

On paper and in the handout view, the small chart of a frame draws the layout of that frame
from the layout of all the frames. Thus a node has the same color, the same scale and the
same column in the small chart and in the present view.

A flow with the value 0 does not show, and the checks of the chart do not count it. Thus a
`node` entity for a node with no other flow gives an error. The `levels` option of an
alluvial chart gives a title for each column that holds a link with a value more than 0.

### Reveal

With `reveal true`, a sankey or an alluvial chart has one series for each source column of
the links. The links of a column show at their own step. The `column` of a `node` entity
sets the column of its node, as in the drawing. A node shows with the first link that
touches it. `dim true` dims the links of a column when a later column shows.

With `reveal true`, a parallel sets chart has one series for each node of the first column.
The nodes and their labels show with the chart. Then the ribbons of each node of the first
column show at their own step.

With `reveal true`, a chord chart has one series for each source. The arcs and their labels
show with the chart. Then the chords of each source show at their own step.

## The CSV file

The first row holds a heading for the categories, then the name of each series. Each other
row holds a category, then one number for each series. A comma divides two cells:

```
Month,Web,Phone,Shop
Jan,420,310,150
Feb,450,360,140
```

These rules apply to each file:

- A file that ends in `.tsv` has a tab between two cells. The `delimiter` option gives a
  different character, such as `";"` or `"|"`.
- A cell in double quotes can hold the delimiter, a line break, and a quote, which two
  quotes give: `"The ""new"" line"`. The text in the quotes stays as it is.
- The spaces around a cell do not count. A line with only spaces is not a row.
- A number can have a comma between each group of three digits, such as `1,250` or
  `12,500.5`. A CSV file holds such a number in quotes. A period is the decimal mark.
- The message of an error names the first line of the row.

The categories of a treemap and of a sunburst hold the separator in the same column, such as
`Production/Press,62`. A file needs no other change.

With the `levels` option, the columns with these headings hold the levels of each category,
from the top level down. The other columns keep their order, and each one holds a series.
An empty cell at the end of a row ends the category at a higher level. An empty cell before
a cell with a name is an error:

```
Division,Team,Hours
Production,Press,62
Office,,20
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
  with `reveal`;
- a treemap or a sunburst with more than one series, with a negative value, with `reveal`,
  or with more than 8 groups at the top level;
- a category with a level with no name, a category that shows two times, and a category
  that is also a group;
- a list of levels or the `levels` option on a bar chart, a line chart or a pie, `levels`
  without `src`, and an empty `separator`;
- a chart with frames and a `series` of its own;
- a frame with series that are not the series of the first frame, in the same order;
- a series of a later frame with an overlay option or a `class`;
- `sort` on a line chart or a pie, `count` on a chart without frames, and `frames` without
  `src`;
- `delimiter` without `src`, and a `delimiter` that is not one character, or that is a
  quote or a line break;
- a `thumbnail` with the number of a frame that the chart does not have;
- a `flow` in a chart that is not a chart of flows, also in a frame;
- a chart of flows with flows and also `categories`, a `series` or `src`;
- a frame with flows and also a series;
- a chart of flows with more than one series, with the effect `:grow` or with `count`;
- a chart of flows with frames and `reveal`;
- a category with one node, a node with no name, a flow from a node to the same node, and a
  negative value;
- a chart of flows with `levels` that names one column;
- an alluvial chart or a parallel sets chart with `levels` that does not give one title for
  each column;
- a category of a parallel sets chart that names a different number of columns from the
  first category;
- a `node` in a chart that is not a chart of flows;
- two `node` entities for one node, and a `node` with a name that no flow has;
- a `node` with `column` in a chart of flows that is not a sankey;
- `highlight` with `reveal`, with `dim`, with frames, or with a series that has an overlay
  option;
- an empty `highlight`, an empty group, a name that is not the name of a series or of a
  category, a name of a series and of a category, and a group of series and categories;
  for a treemap or a sunburst, the message gives each part and each group, and for a
  chart of flows, each node;
- `whole_first` without `highlight`;
- a group of `highlight` at a step at which the chart does not show.

The compiler gives an error for a file that it cannot read, for a quote with no closing
quote, for text after a closing quote, and for a row with a cell that is not a number. The
message names the line. `Expresso.Builder.deck/2` raises a `Spark.Error.DslError` with the
same message.

## The colors

The theme gives the colors of the series as `--chart-1` to `--chart-8`, in a fixed order:
blue, orange, aqua, yellow, magenta, green, violet and red. A light theme and a dark theme
get different steps of the same colors. A reader with a deficit of color vision can tell
each pair of neighbors apart. A chart has at most 8 series, so put the smallest into a
series "Other".

The text of a chart has the colors of text, and only a mark has the color of its series. A
deck can set `--chart-1` to `--chart-8`, `--chart-width`, `--chart-height`, the largest
height, and `--chart-dim-opacity` in [the css option](css-option.md). The default height
is `72vh`. A chart also takes at most the height that is left in the slide, under the
heading, the name of the deck and the other elements. Thus a chart fits in a small window.

## The HTML

The document writes a `figure` element with the classes `chart` and `chart-bar`,
`chart-line`, `chart-pie`, `chart-treemap`, `chart-sunburst`, `chart-sankey`,
`chart-alluvial`, `chart-parallel-sets` or `chart-chord`. It holds an
`svg` element with `role="img"` and the `title` as its `aria-label`. It also holds a `table`
with the class `chart-table` that holds each value. The style sheet hides the table from the
eye and not from a screen reader. The table has a column header for each series and a row
header for each category. Its top left corner is a `td` cell, because it names nothing. Each
series is a `g` element with the class `chart-series`.

A chart of flows writes these elements:

| Mark | Element | Classes |
| --- | --- | --- |
| A node | `rect` | `chart-node`, `chart-c1` to `chart-c8`, and the `class` of its node entity |
| A link | `path` | `chart-link` |
| A back link | `path` with a `stroke-width`, because it is a stroke and not a filled shape | `chart-link` and `chart-back` |
| The labels of a series | `g`, after the series, with the same steps | `chart-labels` |
| A label | `text` | `chart-node-label` |
| A frame | `g` | `chart-layer` |
| The title of a column | `text` | `chart-column` |
| The nodes of a parallel sets chart, after the series | `g` | `chart-nodes` |
| A node of a parallel sets chart after the first column | `rect` | `chart-node` and `chart-node-plain` |
| An arc of a chord chart, in the group `chart-nodes` | `path` | `chart-node` and `chart-c1` to `chart-c8` |
| A chord | `path` | `chart-link` and `chart-chord` |

A chart with frames, with the effect `:grow` or with `highlight` has a `data-el` attribute.
The marks of a chart with frames or with the effect `:grow` have the class `chart-mark`,
`chart-segment`, `chart-arc` or `chart-gap`, and the label of the frame has the class
`chart-frame`. A number with `count true` is a `tspan` with the class `chart-count`. The
grid of the frames is a `div` with the class `chart-frames`, and each small chart is a
`figure` with the class `chart-copy`.

Each series of a chart with `highlight` has `data-series` with its number, from 1. With a
group of categories, each mark of a category has `data-keys` with its key, such as `c2`
for the second category, and a line has an empty `data-keys`. A mark of a treemap or a
sunburst has the key of its part, of each group above it and of each part under it, such
as `p1 p3`. A node of a chart of flows and its label have the key of the node, such as
`n2`. A link or a chord has the keys of its two nodes, and a ribbon of a parallel sets
chart has the key of each node of its path. The generated style block dims a series by its
number and a mark by its key.

A box of a treemap is a `rect` with the class `chart-tile` for a part or `chart-group` for a
group. An arc of a sunburst is a `circle` with the class `chart-ring` and `chart-depth-1`,
`chart-depth-2` or `chart-depth-3` for its level. A group of the top level is a `g` element
with the class of its color, such as `chart-c1`.
