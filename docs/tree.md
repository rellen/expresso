# A tree element

This document gives a plan for the element `tree`, which shows a hierarchy as boxes and
lines. An org chart is one use, and the use of a disk by folders is another. The code
contains this plan. The document records nine decisions, and each is settled. The last
section, "The result", tells what changed during the work.

## The problem

A talk often shows a hierarchy:

- the structure of a team, and how a reorganization changes it;
- the folders of a disk and the space that each one uses;
- the modules of a program, or the parts of a product.

A deck can now draw such a tree only as a `diagram` from an SVG file, or as a
`chart :treemap` or `chart :sunburst`. The author draws a diagram again after each change of
the data. A treemap and a sunburst show the parts of a whole as areas, and they have no box
with a name, a detail and a picture.

A tree in a talk has these needs:

- A box for each node, with a label, a detail line, a picture, some short facts and an
  optional value.
- A layout that fits the slide. A wide last level, such as a team of eight or a folder of
  forty files, needs a different layout than the levels above it.
- Steps: the presenter shows the tree level by level, branch by branch, or in groups of one
  or more nodes. The presenter puts one node or one branch in focus. A change of the data,
  such as a reorganization, moves the boxes from the old tree to the new tree.
- Data from a file, because a real tree comes from a system, not from a list that the author
  types.

## The constraints

- The output stays one HTML file, and the presenter script does not calculate a layout. The
  compiler calculates each layout, as it does for the charts.
- A tree obeys the overlay contract: `at`, `on`, `effect`, `reveal`, `dim`, `class` and
  `morph`. See `docs/overlays.md`.
- The handout view and paper show each step that the present view can show.
- A screen reader gets the same tree as the eye: each node, its detail, its value, and the
  node above it.
- The theme gives each color, and the deck can change each color with CSS.

## The plan

### The entity

`tree` is a new element. It is not a kind of `chart`. A chart shows series of values, and
its options, such as `series`, `count` and the axes, do not apply to a tree. The tree uses
the parts of the charts that do apply: the channels of `Expresso.Element.Chart.Motion`, the
CSV reader, the `highlight` steps, the format of numbers and the colors of the palette.

```elixir
tree do
  title "The plant"

  node "Ana" do
    detail "Plant manager"
    image "ana.jpg"

    node "Ben" do
      detail "Production"
      fields team: "42 people"
      node "Cy", detail: "Press"
      node "Di", detail: "Paint"
    end

    node "Eve", detail: "Quality", icon: "shield-check"
  end
end
```

A node with nodes under it gives its options in its block. A Spark entity takes at most two
arguments, the name and the options, and the block is a third. A node with no nodes under it
can give its options after the name.

The same element shows the use of a disk:

```elixir
tree do
  title "The use of the disk"
  layout :left_right
  value_format :bytes
  sort :value
  bar true

  node "/" do
    node "home" do
      node "photos", value: 412_000_000_000
      node "code", value: 38_000_000_000
    end

    node "var", value: 21_000_000_000
  end
end
```

The `title` option is required, as for a chart. It names the tree for a screen reader.

### The node

The tree uses the `node` entity of the charts of flows. The entity gets the options of a
tree, and a verifier refuses an option that does not apply to the parent element:

| Option of `node` | In a tree | In a chart of flows | Effect |
| --- | --- | --- | --- |
| The first argument | yes | yes | The identity of the node. In a tree, also the default label. |
| `label` | yes | yes | The text of the first line of the box. |
| `class` | yes | yes | The classes of the box. |
| `column`, `order` | no | yes | The place of the node in a chart of flows. |
| `detail` | yes | no | The second line of the box, such as a role. |
| `image` | yes | no | The path of an image. The box shows it in a circle. The document holds each file one time. |
| `icon` | yes | no | The name of an icon, in place of an image. See the icon element. |
| `fields` | yes | no | Short facts, one line each, such as `[team: "42 people"]`. |
| `value` | yes | no | A number, such as a size or a count. |
| `color` | yes | no | A role of the theme, such as `:success`, for the box and its branch. |
| `layout` | yes | no | The layout of the nodes under this node. |
| `at`, `on`, `effect` | yes | no | The overlay options of the box. |
| Nested `node` entities | yes | no | The nodes under this node. |

The identity connects a node to the `highlight` option and to the same node in another
frame. Two nodes of one tree cannot have the same identity, so a folder `docs` in two places
needs `node "home/docs", label: "docs"`.

`Expresso.Builder` keeps one function `node/2`. A tree and a node take the nodes under them
in the `elements` key, as a list takes its items:
`tree(title: "The plant", elements: [node("Ana", detail: "Plant manager", elements: [...])])`.

The name `node` is also the name of `Kernel.node/1`. `use Expresso` imports `Kernel` without
`node/1`, so the `node` of the DSL has no conflict in a module of a deck.

### The values

A node can have a `value`. These options of the tree use the values:

| Option of `tree` | Value | Effect |
| --- | --- | --- |
| `sum` | `true` or `false` | A node with no `value` gets the sum of the values of its nodes. The default is `true`. |
| `value_format` | `:number`, `:bytes` or `:percent` | The text of a value: `1,250`, `412 GB` or `12.5%`. `:percent` gives the part of the value of the root. |
| `sort` | `:value` or `:none` | The order of the nodes under each node. `:value` puts the largest first. The default is `:none`, the order of the data. |
| `bar` | `true` or `false` | A bar along the bottom of each box, with a length in proportion to the part of the value of the root. |
| `limit` | An integer | The most nodes under each node. The rest go into one node "N more", with the sum of their values. |
| `depth` | An integer | The most levels. A node at the last level shows the sum of its subtree. |

The value goes into the box after the fields, and into the tree for a screen reader.

### The data

A CSV file gives a tree with one row for each node. The `src` option names the file. The
file gives the tree in one of two forms:

| Form | Columns | Example |
| --- | --- | --- |
| Parent | `id`, `parent`, and the other columns | `cy,ben,Cy,Press` |
| Path | `path`, and the other columns. The `separator` option of the tree divides a path, as for a treemap. | `/home/photos,412000000000` |

The other columns have the names of the options of a node: `label`, `detail`, `image`,
`icon`, `value`, `color`, `layout` and `class`. The option `fields ["team", "location"]`
selects further columns for the boxes, in that order. The headings of these columns are the
labels of the fields.

A `node` in a DSL deck can also give `parent: "ben"` in place of nesting. Thus an author can
type a flat list. The compiler refuses a tree with two roots, a loop, an unknown parent, and
an identity that shows two times.

### The box

The box holds the image or the icon, the label, the detail, the fields, the value and the
bar, in this order. Each box of one level has the same size. The option `box` of the tree
gives the size of each level, in the units of the drawing, from the root down. The last size
applies to each deeper level:

```elixir
box [[width: 280, height: 120], [width: 220, height: 96], [width: 180, height: 56]]
```

The default is one size, `[width: 220, height: 96]`, for each level. A text that does not
fit its line ends with an ellipsis, and the full text goes into the tree for a screen
reader.

The color of a box comes from one of these sources, in this order:

1. The `color` option of the node, or of the nearest node above it with the option.
2. The `color` option of the tree:
   - `color :branch`: each node under the root starts a branch, and each branch takes the
     next color of the palette.
   - `color {:field, "department"}`: each value of the field takes the next color of the
     palette, in the order of the first node with the value. The legend under the tree
     names each value and its color.

   A box has a light tint of its color, and its border has the color.
3. The default: the surface color of the theme, with a border in `--muted`.

The theme gives the custom properties `--tree-box`, `--tree-border`, `--tree-line`,
`--tree-text` and `--tree-bar`, so a deck can change them with its CSS.

### The layout

The layout is recursive. The layout of a node places the subtrees of its nodes, and each
subtree is a box. The `layout` option of a node sets how its nodes go. A node takes the
`layout` of the tree, which has the default `:top_down`:

| Layout | The nodes under a node | The line to each node |
| --- | --- | --- |
| `:top_down` | Side by side in one row under the node. The node is at the center above the row. | Down from the node, along the row, and down to each box. |
| `:left_right` | One under the other in a column to the right of the node. The node is at the middle on the left. | Right from the node, along the column, and right to each box. |
| `:stacked` | One under the other below the node, with an indent. | Down a line on the left, and right to each box. |

The option `stack_from 3` of the tree puts the nodes of level 3 and below in the layout
`:stacked`. A wide last level is the common case, so this option saves a `layout` on each
node of level 2.

A level can have its own box size, so the layout uses the size of the level of each box. In
the layout `:top_down`, the boxes of one level have their tops in one row. In the layout
`:left_right`, the boxes of one level have their left edges in one column.

The layout places the boxes of a row with a gap. It does not move a subtree into the space
under a smaller subtree next to it. Each layout is a function of the tree and the box size
only, so the same tree gives the same picture each time.

The drawing scales to fit the box of the element, as a chart does.

### The steps

Each box takes the overlay options, so `at` and `on` work as for each element. The tree also
has these options for the common orders:

| Option of `tree` | The steps |
| --- | --- |
| `reveal :levels` | Level 1 shows first, then level 2, and so on. |
| `reveal :branches` | The root shows first, then the branch of each node under the root, in order. |
| `reveal :nodes` | The nodes show one at a time, in the order of the tree. |
| `at` on a node | The node and the nodes under it show at that step, unless they have their own `at`. Thus the nodes of one step form a group of one or more nodes. |

A line to a node shows with the node. `dim true` dims the boxes of the earlier steps.

The option `reflow` decides where a box goes before the step of a node that does not show
yet:

- With `reflow false`, the default, the layout holds a place for each node from the first
  step. A box that shows fades into its place, and no other box moves.
- With `reflow true`, the compiler calculates one layout for each step from the nodes that
  show at that step. When a node shows, the other boxes move to the new layout, and the new
  box fades in. The moves use the channels of `Expresso.Element.Chart.Motion`, so a box moves
  with the `speed` and the `easing` of the tree.

The effect `:grow` draws each line from its parent to its box, from the root down, when the
box shows.

### The highlight

The option `highlight` puts a node or a branch in focus at each step, as for a chart:

```elixir
highlight ["Ben", branch("Ben"), ["Cy", "Di"]]
```

A name puts the box of that node in focus. `branch("Ben")` puts Ben and each node under Ben
in focus. A list puts each item of the list in focus at the same step. The rest of the tree
dims, as a dimmed series of a chart does. The line from a box in focus to its parent stays in
full color.

### The frames

A `frame` holds a full tree at one point in time, such as before and after a
reorganization, or the disk in two months:

```elixir
tree do
  title "The plant"
  reflow true

  frame "2025" do
    node "Ana" do
      node "Ben" do
        node "Cy"
      end
    end
  end

  frame "2026" do
    node "Ana" do
      node "Eve" do
        node "Cy"
      end
    end
  end
end
```

The identity of a node connects the boxes of two frames. At the step of a frame, a box that
is in both frames moves to its new place, and its value changes. A box of the new frame only
fades in, and a box of the old frame only fades out. Each frame has its own copy of the
lines, as with `reflow`, because a path cannot change its shape in each browser. A CSV file
gives frames with the `frames` option, which names a column, as for a chart.

### The views

| View | The tree |
| --- | --- |
| The present view | The boxes at each step, with the moves. |
| The speaker view and the overview | The step of the page, with no moves. |
| The handout view and paper | One page for each step, as for each element. A tree with frames shows each frame as a small tree in a grid, as a chart with frames does. |

### Accessibility

The boxes are a nested `ul` in the HTML. Each node is an `li` with the box, and a nested `ul`
for the nodes under it. The CSS places each box, so the order of the HTML is the order of the
tree. A screen reader thus reads the tree with its levels, and it reads a box as "Ben,
Production, team 42 people, 2 items". The lines are an SVG with `aria-hidden`.

A box that does not show at the step has `visibility: hidden`, so a screen reader skips it,
as for each element with `at`.

### The rendering

The module of the element is `Expresso.Element.Hierarchy`, because `Expresso.Element.Tree`
holds the functions that walk the elements of a slide. The drawing is one SVG with a `viewBox` of the layout. The lines are paths in the SVG. Each
box is a `foreignObject` in the SVG, and it holds the HTML of the box. Thus the SVG scales
the whole tree to the box of the element, and the text of a box wraps and ends with an
ellipsis as HTML does. Safari has defects with a transform on an element inside a
`foreignObject`, so the transform goes on the `foreignObject` itself, which Safari draws
correctly.

A box has a transform from the channels of its place, as a mark of a chart has. The compiler
writes the channels of each step that changes a place, from the layout of that step.

## The alternatives

- **A kind of chart, such as `chart :tree`.** The kind would get frames, highlight and CSV
  from the chart. The options of series and axes would not apply, and each one would need an
  error. The box, the image and the layout of each level have no place in the options of a
  chart.
- **A `diagram` from a tool.** The tool draws the tree, and the deck shows the SVG. Each
  change of the data then needs the tool again, and a step cannot move a box.
- **A layout in the browser.** The script could calculate the layout from the size of each
  box. The handout view, paper and the layout check would then depend on the script. The
  charts calculate each layout in the compiler for this reason.
- **A separate entity for the tree, such as `person`.** A name for people does not fit a
  folder. Two entities with the name `node` and different options cannot exist, because
  `Expresso.Builder` makes one function for each name.

## The decisions

1. **The element is a general tree, not a chart of people.** An org chart and the use of a
   disk are two uses of one element.
2. **The name of the element is `tree`.** The name fits each use. `org_chart` reads oddly for
   a disk, and `hierarchy` is longer.
3. **The entity is `node`, shared with the charts of flows.** A verifier refuses an option
   that does not apply to the parent. `Expresso.Builder` keeps one function `node/2`.
4. **The default of `reflow` is `false`.** The layout holds a place for each node, so no box
   moves at a step. `reflow true` gives a tree that grows.
5. **The boxes are HTML in a `foreignObject`.** A browser test in Chromium runs in CI, and a
   manual test in Safari runs before the merge.
6. **The layout does not compact subtrees.** A compaction, as in the tidy layout of Reingold
   and Tilford, can come later if a real deck needs it.
7. **The color comes from a branch or from a field.** `color :branch` and
   `color {:field, "department"}` come in the same pull request.
8. **Each level has its own box size.** The `box` option takes a list of sizes, one for each
   level from the root down, and the last size applies to each deeper level.
9. **The work comes in this stack of pull requests.** Each pull request is small and works
   alone:
   1. This document.
   2. The element, the tree options of `node` and their verifier, the Builder, the layout
      `:top_down`, the box with a label and a detail, the size of each level, the lines and
      the nested list.
   3. The image, the icon, the fields, the colors and the custom properties of the theme.
   4. The values: `value`, `sum`, `value_format`, `sort`, `bar`, `limit` and `depth`.
   5. The layouts `:left_right` and `:stacked`, the `layout` option of a node, and
      `stack_from`.
   6. The CSV file in both forms, the `fields` option and the `parent` option.
   7. The steps: `reveal`, `at` on a node, `reflow` and the effect `:grow`.
   8. The `highlight` option.
   9. The frames, and the grid of frames in the handout view.
   10. A guide in `docs/how-to/`, two example decks (an org chart and the use of a disk) and
       their GIFs.

## The result

The ten pull requests of the stack contain the plan. These parts changed during the work:

- **The module.** The module of the element is `Expresso.Element.Hierarchy`, because
  `Expresso.Element.Tree` holds the walks over the tree of elements. The name of the
  element in the DSL is `tree`.
- **The lines at a step.** A path cannot change its shape in each browser, so a line does not
  move with its two boxes. With `reflow` or frames, each run of steps with the same boxes has
  its own copy of the lines, as the frames of a chart of flows do.
- **The highlight.** The groups of `highlight` are the groups of the highlight of a chart,
  with a step from `Expresso.Overlay.Expand`, and `branch/1` names a node and each node
  under it.
- **The nodes of a frame.** A frame holds its nodes in its `elements` key, the key of a
  nested node. With a key of its own, the `node` macro in the block of a node put the nested
  nodes under that key of the node, and the nodes were lost.
- **The content of a box in frames.** A box with a different content in two frames holds
  one card for each content, and the cards fade from one to the other. A value does not
  count from one number to the next.
- **The examples.** The guide `docs/how-to/show-a-hierarchy-as-a-tree.md` shows three
  example decks: an org chart, the use of a disk and a change of a team.
