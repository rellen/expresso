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
| `class` | CSS class names | The classes of the box. |
| Nested `node` entities | | The nodes under this node, from the left. |

The name is the identity of the node, so two nodes of one tree cannot have the same name.
Give a different name and a label to the second node, such as
`node "home/docs", label: "docs"`.

The `node` entity is also the entity of a node of a chart of flows. See
[the chart element](chart-element.md). A chart takes the options `column` and `order`, and a
tree does not. A tree takes `detail`, `image`, `icon`, `fields`, `color` and nested nodes,
and a chart does not.

## The box

A box shows its parts in this order:

1. The image or the icon, in a circle at the left. A box without them centers its text.
2. The label, in bold.
3. The detail, in the muted color.
4. A line for each field, with the name in the muted color.

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

The compiler calculates the place of each box:

- The boxes of one level have their tops in one row.
- The nodes under a node are side by side in a row, with a gap between two of them.
- A node is at the center above the row of the nodes under it.
- A line goes down from the bottom of a box, along to the center of each box under it, and
  down to the top of that box.

The layout does not move a subtree into the space under a smaller subtree next to it. Thus
the place of each box depends only on its branch, and the same tree gives the same picture
each time.

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
    `tree-field-name`.

  A box with a color also has the class `tree-colored` and the custom property
  `--tree-color` in its `style`, such as `var(--chart-2)` or `var(--danger)`;
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
- a node of a chart with the option `detail`, `image`, `icon`, `fields` or `color`, or
  with a nested `node` entity;
- a `box` value that is not one size or a list of sizes with positive integers;
- a `color` option of the tree that is not `:branch` or `{:field, name}`;
- `color {:field, name}` when no node of the tree has the field;
- a `color` option of a node that is not a role of the theme;
- a `fields` option that is not a list of names and texts;
- an `icon` name that no icon has.

A path of an image that the renderer cannot read is an error of the render, as for the
image element.
