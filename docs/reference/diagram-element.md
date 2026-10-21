# The diagram element

The `diagram` element shows an SVG file as a part of the document. Each `part` names an
element of the file, and that element can show, hide, move or change at steps.

```elixir
slide "the flow" do
  diagram "flow.svg" do
    width "60%"

    part "arrow", at: [from: 2]

    part "output" do
      at from: 3
      on 4, state: :alert
    end
  end
end
```

`Expresso.Builder` takes the same options, such as
`diagram("flow.svg", width: "60%", elements: [part("arrow", at: [from: 2])])`.

## The options of the diagram

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | The path of an `.svg` file, or of a `.dot` or a `.gv` file | The diagram, or the source of a graph. A path is relative to [the root option](root-option.md) of the deck, or to the working directory of the command. See [A graph from Graphviz](#a-graph-from-graphviz). |
| `width` | A CSS width, such as `"900px"` or `"60%"` | The width of the diagram. A percentage is a part of the width of the slide. The default is the width that the file gives. |
| `alt` | A string | The text of the diagram for a screen reader. The diagram then has the role `img`, and a screen reader reads this text in the place of the text of the SVG. Without it, a screen reader reads the text of the SVG. |
| `class` | CSS class names | See [the class option](class-option.md). |
| `morph` | A string | A key of the morph. See [the morph option](morph-option.md). |
| `layout` | `:dot`, `:neato`, `:fdp`, `:sfdp`, `:circo` or `:twopi` | The layout engine of Graphviz, for a `.dot` or a `.gv` file. The default is `:dot`. |

## The options of a part

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | A string | The `id` of an element of the SVG file, or the name of a node, an edge or a cluster of a graph. |

A diagram and a part each take the overlay options, such as `at`, `effect` and the `on`
entity. The `on` entity of a part also takes `move_to`. See
[the overlay options](overlay-options.md#on).

## A graph from Graphviz

A `.dot` or a `.gv` file is the source of a graph in the language of Graphviz. The render
runs Graphviz on the source, and the diagram shows the SVG that Graphviz draws. A part names
a node, an edge or a cluster in the words of the source:

```elixir
slide "the system" do
  diagram "system.dot" do
    layout :dot

    part "web"
    part "web->api", at: [from: 2]
    part "api", at: [from: 2]

    part "cluster_app" do
      on 3, state: :alert
    end
  end
end
```

| Element | Name | Example |
| --- | --- | --- |
| A node | The name of the node | `web` |
| A cluster | The name of the subgraph | `cluster_app` |
| An edge | The two ends, with `->` in a `digraph` and `--` in a `graph` | `web->api` |
| A second edge between the same ends | The name of the first edge, then `:2` | `web->api:2` |

An element with an `id` in the source, such as `db [id="store"]`, keeps that `id`, and a
part names it with the `id`. A part with a name that the graph does not have stops the
render, and the message lists the names that the graph has.

The layout engines `:sfdp`, `:circo` and `:twopi` draw no cluster. With them, a part cannot
name a cluster.

The render finds the program `dot` on the `PATH`. The variable `EXPRESSO_DOT` gives a
different path. A deck without a graph does not need Graphviz. Each render runs Graphviz
again, and the watch mode renders the deck again after a change to the source.

The graph keeps the colors and the fonts that Graphviz gives it.

## The errors

The render gives an error for these:

- a file that it cannot read, or that is not UTF-8;
- a part with an `id` that the file does not have;
- a `move_to` with an `id` that the file does not have, or with an element that has no shape;
- a `.dot` or a `.gv` file when the render does not find Graphviz;
- a source that Graphviz cannot draw, such as a source with a syntax error. The message
  gives the message of Graphviz.

The DSL and `Expresso.Builder` give an error for the `layout` option of an `.svg` file.

## The theme and the SVG file

The document holds the SVG as elements, and not as a picture. The rules of the theme and
of [the css option](css-option.md) thus reach the parts of the diagram.

The render removes the XML declaration and the DOCTYPE at the start of the file, because
an HTML document cannot hold them. A file from Graphviz, Inkscape or Illustrator thus
works as the tool writes it.

Each view gets its own copy of the file, with its own `id` values. A gradient or a marker
thus works in each view. An `id` in the document is therefore not the same as the `id` in
the file. Write a rule of the css option with a class of the file, and not with an `id`.

A `<style>` element of the file applies only to its copy. Two files with the same class
names, such as two exports of Adobe Illustrator with `.st0`, thus keep their own colors.
An `#id` selector in the `<style>` element gets the `id` of the copy, so a file from
mermaid-cli keeps its colors. The rules of `@keyframes` and `@font-face` stay as they are.

The `id` of a part can hold a point, a colon or a space, such as `step.1`.

## A part that moves

A part with an `on` entity, or with an effect that moves it, goes into a `g` element with
the class `diagram-part`. The theme moves the `g` element, so the part keeps its own
`transform` attribute. A distance in `set: [x: ..., y: ...]` is in the units of the file.

A part inside a `text` element of the file, such as a `tspan`, can fade, dim and change
its color. It cannot move or get an outline.

## The watch mode

The watch mode renders the deck again after a change to the SVG file.
