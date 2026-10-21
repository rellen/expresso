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
| The first argument | The path of an `.svg` file, or of a `.dot`, a `.gv` or a `.d2` file | The diagram, or the source of a graph. A path is relative to [the root option](root-option.md) of the deck, or to the working directory of the command. See [A graph from Graphviz](#a-graph-from-graphviz) and [A graph from D2](#a-graph-from-d2). |
| `width` | A CSS width, such as `"900px"` or `"60%"` | The width of the diagram. A percentage is a part of the width of the slide. The default is the width that the file gives. |
| `alt` | A string | The text of the diagram for a screen reader. The diagram then has the role `img`, and a screen reader reads this text in the place of the text of the SVG. Without it, a screen reader reads the text of the SVG. |
| `class` | CSS class names | See [the class option](class-option.md). |
| `morph` | A string | A key of the morph. See [the morph option](morph-option.md). |
| `layout` | For Graphviz, `:dot`, `:neato`, `:fdp`, `:sfdp`, `:circo` or `:twopi`. For D2, `:elk` or `:dagre`. | The layout engine of the tool. The default is `:dot` for Graphviz and `:elk` for D2. |
| `edges` | `:follow` or `:own` | When an edge of a graph without its own part shows. The default is `:follow`. See [The edges of a graph](#the-edges-of-a-graph). |
| `colors` | `:theme` or `:tool` | The colors of a graph. The default is `:theme`. See [The colors and the font of a graph](#the-colors-and-the-font-of-a-graph). |
| `font` | The path of a directory with TTF files | The font of the text of a graph. The default is the font of the built-in theme. A path is relative to the root option of the deck. |

## The options of a part

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | A string | The `id` of an element of the SVG file, or the name of an element of a graph. |

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
different path. A deck without a graph does not need Graphviz.

The watch mode renders the deck again after a change to the source. It keeps the SVG of each
graph, so it runs the tool again only after a change to the source, the `layout` option, the
font or the program of the tool. D2 can import a different file of D2 into a source. The
watch mode does not see a change to that file, so save the source again after such a change.

The graph gets the colors and the font of the theme. See
[The colors and the font of a graph](#the-colors-and-the-font-of-a-graph).

## A graph from D2

A `.d2` file is the source of a graph in the language of D2. The render runs D2 with the
layout engine ELK, or with the engine of the `layout` option. A part names a shape, a
container or a connection by its key in the source:

```elixir
slide "the system" do
  diagram "system.d2" do
    part "app.web"
    part "app.web->app.api", at: [from: 2]
    part "app.api", at: [from: 2]
    part "db", at: [from: 3]

    part "app" do
      on 4, state: :alert
    end
  end
end
```

| Element | Name | Example |
| --- | --- | --- |
| A shape | Its key, with the keys of its containers | `app.web` |
| A container | Its key | `app` |
| A connection | The keys of the two ends and the arrow, with no spaces | `app.api->db`, `db<-cache` |
| A connection inside a container | The key of the container in front of each end | `app.web->app.api` for `web -> api` in `app` |
| A second connection between the same ends | The name of the first connection, then `:2` | `app.api->db:2` |

ELK draws each connection with right angles. Dagre is approximately seven times faster,
but ELK takes only some seconds for a graph of a slide.

The render finds the program `d2` on the `PATH`. The variable `EXPRESSO_D2` gives a
different path. D2 holds the font in the SVG.

## The colors and the font of a graph

A graph gets the colors of the theme, so it changes with the theme and with the dark variant
of a theme. With `colors :tool`, the graph keeps the colors of the tool. Use `:tool` for a
graph with colors that have a meaning.

| Tool | The colors of the theme |
| --- | --- |
| Graphviz | The lines and the text take the color `--text`, and the white background goes away. A color that the source gives, such as `color=red`, stays. |
| D2 | Each class of the palette of D2 takes a custom property, such as `--graph-B4` for the fill of a shape. The table below gives the default of each property. The background goes away. |

| Properties | D2 uses them for | Default |
| --- | --- | --- |
| `--graph-N1` | The text | `--text` |
| `--graph-N2`, `--graph-N3` | The text of less importance | `--muted` |
| `--graph-N4` to `--graph-N6` | The lines of less importance and the fills | A mix of `--muted` and `--background` |
| `--graph-N7` | The background | `--background` |
| `--graph-B1`, `--graph-B2` | The lines of the shapes and the connections | `--accent` |
| `--graph-B3` to `--graph-B6` | The fills of the shapes and the containers | A mix of `--accent` and `--background` |
| `--graph-AA2` to `--graph-AA5` | The second colors, such as a cylinder | `--chart-2`, and a mix of it with `--background` |
| `--graph-AB4`, `--graph-AB5` | The third colors | A mix of `--chart-3` and `--background` |

The [css option](css-option.md) can change each property, such as
`.diagram-d2 { --graph-B4: var(--chart-4); }`.

The text of a graph gets the font of the slide. The render gives the font to the tool, so the
tool sizes each box for the text in that font. The default is Atkinson Hyperlegible, the font
of the built-in theme. A deck with a different font gives its TTF files with the `font`
option:

```elixir
slide "the system" do
  diagram "system.d2" do
    font "fonts/inter"
  end
end
```

The directory holds a TTF file for each style: regular, bold, italic and bold italic. The
render reads the family and the style from each file. A style without a file takes the
regular file. In Graphviz, a `fontname` of the source still applies to its element.

## The edges of a graph

An edge of a graph joins two nodes. With `edges :follow`, the default, an edge without its
own part shows from the step where both of its ends show:

```elixir
slide "the steps of a graph" do
  diagram "system.dot" do
    part "api", at: [from: 2]
    part "store", at: [from: 3]
  end
end
```

| Edge | Ends | Steps |
| --- | --- | --- |
| `web->api` | `web` shows at each step, and `api` from step 2 | From step 2 |
| `api->db` | `api` from step 2, and `store` from step 3 | From step 3 |

An end is a node or a container with its own part. An end without a part, or with a part
without `at`, shows at each step. An edge with two such ends shows at each step. An end of
an edge in Graphviz is the `id` of its node, so the node `db [id="store"]` is the end
`store`.

An edge with its own part keeps the steps of that part, so an edge can show later than its
ends. With `edges :own`, an edge without a part shows at each step, as an element of an SVG
file does.

## The errors

The render gives an error for these:

- a file that it cannot read, or that is not UTF-8;
- a part with an `id` that the file does not have;
- a `move_to` with an `id` that the file does not have, or with an element that has no shape;
- a `.dot` or a `.gv` file when the render does not find Graphviz, and a `.d2` file when
  the render does not find D2;
- a source that the tool cannot draw, such as a source with a syntax error. The message
  gives the message of the tool.

The DSL and `Expresso.Builder` give an error for the options `layout`, `edges`, `colors`
and `font` of an `.svg` file, and for a layout of a different tool. The render gives an error
for a font directory without a TTF file, without a regular file, or with more than one
family.

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

The watch mode renders the deck again after a change to the SVG file, or to the source of a
graph. It runs the tool of a graph again only after a change that changes the graph. See
[A graph from Graphviz](#a-graph-from-graphviz).
