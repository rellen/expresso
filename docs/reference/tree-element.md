# The tree element

The `tree` element shows a hierarchy of nodes as boxes and lines, such as an org chart or
the folders of a disk. The root is at the top, and the nodes under each node are in a row
under it.

```elixir
slide "the plant" do
  tree do
    title "The plant"

    node "Ana" do
      detail "Plant manager"

      node "Ben" do
        detail "Production"
        node "Cy", detail: "Press"
        node "Di", detail: "Paint"
      end

      node "Eve", detail: "Quality"
    end
  end
end
```

A tree holds one `node` entity, the root. Each node holds the nodes under it, to each depth.
A node with nodes under it gives its options in its block, such as `detail "Production"`. A
node with no nodes under it can give its options after its name, such as
`node "Cy", detail: "Press"`.

`Expresso.Builder` takes the same options. A tree and a node take the nodes under them in
the `elements` key:

```elixir
slide "the folders" do
  tree do
    title "The folders"
    box [[width: 260, height: 96], [width: 200, height: 72]]

    node "/" do
      node "home" do
        node "photos"
        node "code"
      end

      node "var"
    end
  end
end
```

```text
tree(title: "The folders", elements: [
  node("/", elements: [node("home", elements: [node("photos"), node("code")]), node("var")])
])
```

## The options of the tree

| Option | Value | Effect |
| --- | --- | --- |
| `title` | A string, required | The name of the tree for a screen reader. |
| `color` | `:branch` or `{:field, name}` | The colors of the boxes from the palette. See [the colors](#the-colors). The default is no color. |
| `layout` | `:top_down`, `:left_right` or `:stacked` | How the nodes under each node go. See [the layout](#the-layout). The default is `:top_down`. |
| `src`, `delimiter`, `separator`, `fields` | | The CSV file of the nodes. See [the data](#the-data). |
| `reveal` | `:levels`, `:branches` or `:nodes` | Show the nodes in steps. See [the steps](#the-steps). |
| `dim` | `true` or `false` | Dim the boxes of the earlier steps. The default is `false`. |
| `reflow` | `true` or `false` | Calculate the layout at each step from the boxes that show. The default is `false`. |
| `stack_from` | A level of 2 or more | The first level that the tree stacks, with `1` for the root. |
| `sum` | `true` or `false` | Give a node with no `value` the sum of the values under it. The default is `true`. |
| `value_format` | `:number`, `:bytes` or `:percent` | The text of a value, such as `1,250`, `412 GB` or `12.5%`. The default is `:number`. |
| `sort` | `:value` or `:none` | The order of the nodes under each node. `:value` puts the largest value first. The default is `:none`, the order of the data. |
| `bar` | `true` or `false` | A bar along the bottom of each box, with the part of the value of the root. The default is `false`. |
| `limit` | A positive integer | The most nodes under each node. One more node, such as "3 more", holds the total of the rest. |
| `depth` | A positive integer | The most levels, with `1` for the root only. A node at the last level shows the total of the values under it. |
| `box` | One size, or a list of sizes | The size of the boxes of each level, from the root down, such as `[[width: 280, height: 120], [width: 220, height: 96]]`. The last size applies to each deeper level. One size, such as `[width: 200, height: 80]`, applies to each level. The default is `[width: 220, height: 96]`. |
| `width` | A CSS length | The width of the tree, such as `"900px"` or `"70%"`. The default is 80% of the width of the slide. |
| `class` | CSS class names | See [the class option](class-option.md). |

The sizes of `box` are in the units of the drawing. The drawing scales to the width of the
element, and it keeps its proportions. Thus a larger box gives more space to its text, and
a smaller font. The height of the tree is at most 72% of the height of the slide.

The element also takes the overlay options, such as `at`, `effect` and the `on` entity. See
[the overlay options](overlay-options.md).

A slide, a text box, a column and a callout can hold a tree.

## The options of a node

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | A string, required | The identity of the node. It is also the text of the first line of the box. |
| `label` | A string | The text of the first line of the box in place of the name. |
| `detail` | A string | The second line of the box, such as a role or a size. |
| `image` | A path | An image that the box shows in a circle at its left, such as `"ana.jpg"`. A relative path starts from the `root` option of the deck. |
| `icon` | A name | An icon that the box shows at its left, in place of an image, such as `"factory"`. The names are the names of [the icon element](icon-element.md). |
| `fields` | A keyword list | Short facts, one line each under the detail, such as `[team: "42 people", floor: 3]`. A name can also be a string, such as `[{"Cost center", "4100"}]`. A text is a string or a number. |
| `color` | A role of the theme | The color of the box and of each box under it: `:text`, `:muted`, `:accent`, `:success`, `:emphasis`, `:warning` or `:danger`. |
| `at`, `effect`, `speed`, `easing` and the `on` entity | | The steps of the box. See [the steps](#the-steps) and [the overlay options](overlay-options.md). |
| `parent` | A name | The node above this node, in place of nesting. See [the parent option](#the-parent-option). |
| `value` | A number that is not negative | A size or a count, such as `412_000_000_000`. See [the values](#the-values). |
| `layout` | `:top_down`, `:left_right` or `:stacked` | How the nodes under this node go, and the nodes under them. See [the layout](#the-layout). |
| `class` | CSS class names | The classes of the box. |
| Nested `node` entities | | The nodes under this node, from the left. |

The name is the identity of the node, so two nodes of one tree cannot have the same name.
Give a different name and a label to the second node, such as
`node "home/docs", label: "docs"`.

The `node` entity is also the entity of a node of a chart of flows. See
[the chart element](chart-element.md). A chart takes the options `column` and `order`, and a
tree does not. A tree takes `detail`, `image`, `icon`, `fields`, `color`, `value`,
`layout`, `parent`, the overlay options, the `on` entity and nested nodes, and a chart does
not.

## The data

A tree can come from a CSV file in place of node entities. The `src` option names the file,
and the file has a row for each node. The file has one of two forms:

| Form | Columns | Example row |
| --- | --- | --- |
| Parent | `id`, `parent`, and the other columns. An empty `parent` makes the root. | `ben,ana,Ben,Production` |
| Path | `path`, and the other columns. The `separator` option divides a path. | `/home/photos,412000000000` |

The other columns have the names of the options of a node: `label`, `detail`, `image`,
`icon`, `value`, `color`, `layout` and `class`. An empty cell gives no option. The tree
does not read a different column, unless its `fields` option names the column. Each column
of `fields` becomes a field of each box, with its heading as the name of the field.

```text
id,parent,label,detail,value,team
ana,,Ana,Plant manager,,
ben,ana,Ben,Production,42,40 people
eve,ana,Eve,Quality,7,6 people
```

```elixir
slide "the team" do
  tree do
    title "The team"
    src "team.csv"
    fields ["team"]
    bar true
  end
end
```

In the path form, the identity of a node is its path without a separator at the start or at
the end, such as `home/photos`. A level without a row of its own becomes a node with no
options, just before the first row under it. When the paths start with two or more levels,
such as `/home` and `/var`, a root with the label `/` holds them. A row with the path `/`
gives the options of that root.

```text
path,value
/var,21000000000
/home/photos,412000000000
/home/code,38000000000
```

The options of the file are these:

| Option | Value | Effect |
| --- | --- | --- |
| `src` | A path | The CSV file, from the `root` option of the deck. A file that ends in `.tsv` has a tab between two cells. |
| `delimiter` | One character | The character between two cells, such as `";"`. The default is a comma. |
| `separator` | A string | The text between two levels of a path. The default is `"/"`. |
| `fields` | A list of headings | The columns that become the fields of each box, in that order. |

A tree with `src` takes no node entities. The watch mode renders the deck again after a
change to the file.

### The parent option

The `parent` option of a node puts the node under the node that it names, so you can type a
flat list in place of nesting:

```elixir
slide "the flat list" do
  tree do
    title "The plant"
    node "Ana"
    node "Ben", parent: "Ana"
    node "Cy", parent: "Ben"
    node "Eve", parent: "Ana"
  end
end
```

Only a node at the top of the tree takes the option. The nodes under one parent keep their
order, after the nodes that the parent holds in its block.

## The steps

Each box takes the overlay options of a node, so `at` and the `on` entity work as for each
element. A box is not inside the box of its parent in the HTML, so the compiler gives each
box the steps of its node, or of the nearest node above it with steps. Thus `at` on a node
shows the node and the nodes under it at that step, unless they have their own `at`. The
line to a node shows with the node.

The `reveal` option of the tree gives the steps for the usual orders:

| Value | The steps |
| --- | --- |
| `:levels` | The root shows first, then level 2, then level 3, and so on. |
| `:branches` | The root shows first, then each node under the root with its branch, in order. |
| `:nodes` | One node at each step, in the order of the tree. With `sort :value`, the largest node of a row comes first. |

A node with its own `at` option keeps it, and the nodes under it take its steps. A `:next`
in such an `at` takes a step after the steps of `reveal`.

```elixir
slide "the plant in steps" do
  tree do
    title "The plant"
    reveal :levels
    dim true

    node "Ana" do
      detail "Plant manager"

      node "Ben" do
        detail "Production"
        node "Cy", detail: "Press"
      end

      node "Eve", detail: "Quality"
    end
  end
end
```

`dim true` dims each box from the first step of a later box, as the `dim` option of a list
does. A dimmed box moves its text to the dimmed colors of the theme, and its border, its
tint, its icon, its bar and its line fade.

### The reflow option

With `reflow false`, the default, the layout keeps a place for each box from the first step.
A box fades in at its place, and no box moves.

With `reflow true`, the compiler calculates the layout at each step from the boxes that show
at that step. When a box shows, the other boxes move to the new layout, with the `speed` and
the `easing` of the tree. The layout of each step is at the center of the full layout: across
for `:top_down`, and down for `:left_right`. A node that does not show keeps its place when a
node under it shows.

```elixir
slide "a tree that grows" do
  tree do
    title "The plant"
    reveal :branches
    reflow true
    effect :grow

    node "Ana" do
      node "Ben" do
        node "Cy"
        node "Di"
      end

      node "Eve"
    end
  end
end
```

The effect `:grow` draws each line from its parent to its box when the box shows, and the
box grows into its place.

The node of the rest of a `limit` shows with the last node that the limit keeps.

## The box

A box shows its parts in this order:

1. The image or the icon, in a circle at the left. A box without them centers its text.
2. The label, in bold.
3. The detail, in the muted color.
4. A line for each field, with the name in the muted color.
5. The value, in bold.
6. With `bar true`, a bar along the bottom edge.

Each line that is longer than its box ends with an ellipsis. The list for a screen reader
holds the full text, such as `Ben, Production, team: 42 people`.

```elixir
slide "the team" do
  tree do
    title "The team"
    box [[width: 260, height: 110], [width: 230, height: 110]]

    node "Ana" do
      detail "Plant manager"
      image "logo.png"

      node "Ben" do
        detail "Production"
        icon "factory"
        fields team: "42 people", shifts: 3
      end

      node "Eve", detail: "Quality", icon: "shield-check"
    end
  end
end
```

## The values

A node can have a value, such as the size of a folder or the number of people in a team. The
tree applies the options of the values in this order:

1. `depth` cuts the tree. A node at the last level gets the total of the values under it.
2. `sum` gives each node with no value the sum of the values of the nodes under it. A value
   of a node comes first, so a folder can show its own size.
3. `sort :value` puts the nodes under each node in the order of their values, from the
   largest. A node with no value goes last.
4. `limit` keeps that number of nodes under each node. One more node holds the rest, with
   the label "N more" and the total of their values.

```elixir
slide "the disk" do
  tree do
    title "The use of the disk"
    value_format :bytes
    sort :value
    bar true
    limit 3

    node "/" do
      node "home" do
        node "photos", value: 412_000_000_000
        node "music", value: 95_000_000_000
        node "code", value: 38_000_000_000
        node "docs", value: 4_200_000_000
      end

      node "var", value: 21_000_000_000
    end
  end
end
```

The formats of a value are these:

| Format | Example | Text |
| --- | --- | --- |
| `:number` | `1250.456` | `1,250.46`, with at most two decimals |
| `:bytes` | `412_000_000_000` | `412 GB`, in units of 1000. A value under 10 units has one decimal, such as `4.2 MB`. |
| `:percent` | `25` of a root of `200` | `12.5%`, with at most one decimal |

The bar of a box has the part of the value of the root, so the bar of the root is full. A
box without a color has a bar in the accent color.

## The colors

The color of a box comes from the first of these sources that gives one:

1. The `color` option of the node, or of the nearest node above it with the option.
2. The `color` option of the tree:
   - `color :branch` gives each node under the root the next color of the palette. The
     nodes under that node take the same color. The root has no color.
   - `color {:field, "site"}` gives each value of the field `site` the next color of the
     palette, in the order of the tree. A node without the field has no color. A legend
     under the tree shows each value and its color.
3. No color: a border in the muted color.

A box with a color has a border in the color and a light tint of the color as its
background. The palette has eight colors, `--chart-1` to `--chart-8`, as for a chart. The
ninth branch or value takes the first color again.

```elixir
slide "the sites" do
  tree do
    title "The sites"
    color {:field, "site"}

    node "HQ" do
      fields site: "Berlin"
      node "Ops", fields: [site: "Berlin"]
      node "Sales", fields: [site: "Lyon"]
      node "Lab", fields: [site: "Oslo"], color: :danger
    end
  end
end
```

The legend is in the drawing, so it scales with the tree. The screen reader reads the
field of each node in the list, so it gets the same information as the colors.

## The layout

The compiler calculates the place of each box. Each node places the nodes under it with one
of three layouts:

| Layout | The nodes under a node | The line to each node |
| --- | --- | --- |
| `:top_down` | Side by side in a row under the node. The node is at the center above the row. | Down from the node, along the row, and down to each box. |
| `:left_right` | One under the other in a column at the right of the node. The node is at the middle at the left. | Right from the node, along the column, and right to each box. |
| `:stacked` | One under the other below the node, with an indent. | Down a line at the left, and right to each box. |

The layout of the nodes under a node comes from the first of these:

1. The `layout` option of the node.
2. The `stack_from` option of the tree. The nodes of that level and below are stacked, and
   the root is level 1.
3. The `layout` option of the nearest node above it with the option.
4. The `layout` option of the tree. The default is `:top_down`.

A wide last level is the usual problem of an org chart. `stack_from 3` stacks the nodes of
level 3 under each node of level 2, so the tree gets taller and not wider. A disk has deep
folders, and `layout :left_right` puts each level in a column.

```elixir
slide "the plant" do
  tree do
    title "The plant"
    stack_from 3
    box [[width: 220, height: 96], [width: 200, height: 80], [width: 170, height: 56]]

    node "Ana" do
      detail "Plant manager"

      node "Ben" do
        detail "Production"
        node "Cy", detail: "Press"
        node "Di", detail: "Paint"
        node "Fay", detail: "Pack"
      end

      node "Hal" do
        detail "Maintenance"
        layout :top_down
        node "Jo", detail: "Electric"
        node "Kim", detail: "Mechanic"
      end
    end
  end
end
```

In a tree with one layout, the boxes of one level have their tops in one row for
`:top_down`, and their left edges in one column for `:left_right`. The layout does not move
a subtree into the space next to a smaller subtree. Thus the place of each box depends only
on its branch, and the same tree gives the same picture each time.

## The look

A box without a color has a border in the muted color, a background in the color of the
background, and round corners. The label is bold, and the detail has the muted color. A text
that is longer than its box ends with an ellipsis. A deck can change these custom
properties in the `css` option:

| Property | Effect | Default |
| --- | --- | --- |
| `--tree-width` | The width of the tree | `80vw` |
| `--tree-height` | The most height of the tree | `72vh` |
| `--tree-border` | The color of the border of a box without a color | the muted color |
| `--tree-line` | The color of the lines | the muted color |
| `--tree-box` | The color of the background of a box | the background color |
| `--tree-text` | The color of the label | the text color |
| `--tree-bar` | The color of the bar | the color of the box, or the accent color |

## The HTML

The renderer writes a `figure` with the class `tree`. It holds:

- an `svg` with `aria-hidden="true"`. A `g` with the class `tree-lines` holds a `path` with
  the class `tree-line` for each line. A `foreignObject` holds each box, which is a `div`
  with the class `tree-box`. The `div` holds:
  - an `img` with the class `tree-image`, or a `span` with the class `tree-icon` that holds
    the SVG of the icon. The `div` then also has the class `tree-media`;
  - a `div` with the class `tree-text`. It holds a `p` with the class `tree-label`, a `p`
    with the class `tree-detail` when the node has a detail, and a `p` with the class
    `tree-field` for each field. The name of a field is in a `span` with the class
    `tree-field-name`. A `p` with the class `tree-value` holds the text of the value;
  - with `bar true`, a `span` with the class `tree-bar` that holds a `span` with the class
    `tree-bar-fill`. Its `width` is the part of the value of the root.

  The node of the rest of a `limit` has the class `tree-more`.

  A box with a color also has the class `tree-colored` and the custom property
  `--tree-color` in its `style`, such as `var(--chart-2)` or `var(--danger)`;
- the overlay attributes of each node on its `foreignObject`, which has the class
  `tree-node`, and on the line to the node. With `reflow true`, each `foreignObject` also
  has `data-node` with its place in the tree, and each run of steps with the same boxes has
  its own copy of the lines. Each line has `pathLength="1"` for the effect `:grow`;
- with `color {:field, name}`, a `foreignObject` under the boxes that holds a `ul` with the
  class `tree-legend`. Each `li` holds a `span` with the class `tree-swatch` and the value;
- a `ul` with the class `tree-list` and an `aria-label` with the title. It holds the same
  tree as nested lists, and each item holds the label and the detail, such as
  `Ben, Production`. The style sheet hides the list from the eye, and a screen reader reads
  it in place of the drawing.

## The errors

The compiler gives an error for these:

- a tree with no `node` entity, or with more than one `node` entity at its top;
- two nodes of one tree with the same name;
- a node of a tree with the option `column` or `order`;
- a node of a chart with an option of a tree, such as `detail` or `layout`, or with a
  nested `node` entity;
- a `box` value that is not one size or a list of sizes with positive integers;
- a `color` option of the tree that is not `:branch` or `{:field, name}`;
- `color {:field, name}` when no node of the tree has the field;
- a `color` option of a node that is not a role of the theme;
- a `fields` option that is not a list of names and texts;
- an `icon` name that no icon has;
- a `value` that is negative or not a number;
- `bar true` or `value_format :percent` when the root has no value above 0;
- a `layout` that is not `:top_down`, `:left_right` or `:stacked`;
- a `stack_from` level under 2;
- a tree with `src` and node entities, and `delimiter` or `fields` without `src`;
- a file without the columns `id` and `parent` or the column `path`, and a `fields` column
  that the file does not have;
- a row with a value, a color or a layout that is not correct, with the number of its line;
- two nodes with one identity, a parent that no node has, and a loop of parents;
- a `parent` option on a node inside a different node;
- a `morph` option on a node. Give the option to the tree;
- a node that shows at a step at which the node above it does not show;
- a `reveal` value that is not `:levels`, `:branches` or `:nodes`.

A path of an image that the renderer cannot read is an error of the render, as for the
image element.
