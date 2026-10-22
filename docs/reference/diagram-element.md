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
| The first argument | The path of an `.svg` file, or of a `.dot`, a `.gv`, a `.d2` or a `.mmd` file | The diagram, or the source of a graph. A path is relative to [the root option](root-option.md) of the deck, or to the working directory of the command. See [A graph from Graphviz](#a-graph-from-graphviz), [A graph from D2](#a-graph-from-d2) and [A diagram from Mermaid](#a-diagram-from-mermaid). |
| `source` | A string | The source of a graph in the deck, in place of a file. It needs `lang`. A diagram takes the first argument or `source`, and not both. |
| `lang` | `:mermaid` | The language of `source`. A file gives its language with its extension, so a file takes no `lang`. |
| `width` | A CSS width, such as `"900px"` or `"60%"` | The width of the diagram. A percentage is a part of the width of the slide. The default is the width that the file gives. |
| `alt` | A string | The text of the diagram for a screen reader. The diagram then has the role `img`, and a screen reader reads this text in the place of the text of the SVG. Without it, a screen reader reads the text of the SVG, or the list of a graph. See [A graph and a screen reader](#a-graph-and-a-screen-reader). |
| `class` | CSS class names | See [the class option](class-option.md). |
| `morph` | A string | A key of the morph. See [the morph option](morph-option.md). |
| `layout` | For Graphviz, `:dot`, `:neato`, `:fdp`, `:sfdp`, `:circo` or `:twopi`. For D2, `:elk` or `:dagre`. | The layout engine of the tool. The default is `:dot` for Graphviz and `:elk` for D2. Pele has one layout, so a Mermaid diagram takes no `layout`. |
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

## A diagram from Mermaid

A `.mmd` file is the source of a diagram in the language of Mermaid. The `source` option with
`lang: :mermaid` gives the same source in the deck. The render draws it with
[Pele](https://pele.run) in Node. A part names a node, a subgraph or an edge of a flowchart
by its id in the source:

```elixir
slide "the system" do
  diagram "system.mmd" do
    part "web"
    part "web->api", at: [from: 2]
    part "api", at: [from: 2]
    part "db", at: [from: 3]
  end
end

slide "a small flow" do
  diagram source: "flowchart LR\n  a --> b", lang: :mermaid
end
```

| Element of a flowchart | Name | Example |
| --- | --- | --- |
| A node | Its id | `web` for `web[Web]` |
| A subgraph | Its id | `app` for `subgraph app [App]` |
| An edge | The ids of the two ends and the arrow: `->`, `<->`, or `--` for an edge with no head | `web->api` |
| A second edge between the same ends | The name of the first edge, then `:2` | `api->db:2` |
| An edge with an id in the source | That id | `e1` for `web e1@--> api` |

The label of an edge shows at the steps of its edge.

A sequence diagram names its parts in the same way. A message is an edge from one actor to
the other, so a message without its own part shows from the step where both of its actors
show:

| Element of a sequence diagram | Name | Example |
| --- | --- | --- |
| An actor or a participant, with its lifeline and its activations | Its id | `Web` for `participant Web as Web app` |
| A message | The two actors and the arrow: `<->` for a message with a head at each end, else `->` | `Customer->Web` |
| A second message between the same actors in the same direction | The name of the first message, then `:2` | `Web->Customer:2` |
| A note | `note` and its number, in the order of the source | `note1` |

A class diagram names a relation by its two classes and its arrow. The arrow points to the
end with a marker, such as the triangle of `<|--`:

| Element of a class diagram | Name | Example |
| --- | --- | --- |
| A class | Its id | `Turtle` |
| A namespace | Its id. Each class in it has the namespace as its parent. | `Reef` |
| A relation | The two classes, in the order of the source, and the arrow: `->` for a marker at the second class, `<-` for a marker at the first class, `<->` for a marker at each end, and `--` for no marker | `Animal<-Turtle` for `Animal <\|-- Turtle` |
| A second relation between the same classes in the same direction | The name of the first relation, then `:2` | `Animal<-Turtle:2` |
| A note | `note` and its number from 0, in the order of the source | `note0` |
| The line from a note to its class | The note, `--` and the class | `note0--Turtle` |

A state diagram names a transition by its two states. A composite state is a container:

| Element of a state diagram | Name | Example |
| --- | --- | --- |
| A state | Its id | `Draft` |
| A composite state | Its id. Each state in it, and in each of its concurrent regions, has it as its parent. | `Review` |
| The start and the end of the diagram | `root_start` and `root_end` | `root_start` |
| The start and the end in a composite state | The composite state, then `_start` or `_end` | `Review_start` |
| A transition | The two states and `->` | `Draft->Submitted` |
| A second transition between the same states in the same direction | The name of the first transition, then `:2` | `Draft->Submitted:2` |
| A note | `note` and its number, in the order of the source | `note1` |
| The line from a note to its state | The note, `--` and the state | `note1--Draft` |

An entity relationship diagram names a relationship by its two entities. A relationship has
no direction, so its arrow is `--`:

| Element of an entity relationship diagram | Name | Example |
| --- | --- | --- |
| An entity | Its name in the source | `CUSTOMER` |
| A relationship | The two entities, in the order of the source, and `--` | `CUSTOMER--ORDER` |
| A second relationship between the same entities | The name of the first relationship, then `:2` | `CUSTOMER--ORDER:2` |

A C4 diagram names a relationship by its two ends. A boundary is a container:

| Element of a C4 diagram | Name | Example |
| --- | --- | --- |
| A person, a system, a container or a component | Its alias | `web` for `System(web, "Web store")` |
| A boundary or a deployment node | Its alias. Each shape in it has it as its parent. | `shop` |
| A relationship | The two ends and the arrow: `<-` for `Rel_Back`, `<->` for `BiRel`, else `->` | `customer->web` |

Mermaid keeps one relationship for two ends in the same order, so the last relationship of
the source replaces the others.

An architecture diagram names an edge by its two ends. A group is a container:

| Element of an architecture diagram | Name | Example |
| --- | --- | --- |
| A service or a junction | Its id | `api` |
| A group | Its id. Each service, junction or group in it has it as its parent. | `cloud` |
| An edge | The two ends and the arrow: `->` for a head at the second end, `<-` for a head at the first end, `<->` for a head at each end, and `--` for no head | `web->api` for `web:R --> L:api` |
| A second edge between the same ends with the same arrow | The name of the first edge, then `:2` | `web->api:2` |

Pele draws each diagram type of Mermaid 12.1, such as a pie or a Gantt chart. A type with
no table on this page keeps the `data-id` of Pele as the name of each part, and each part
can take steps.

Pele is a library in JavaScript, and Expresso holds a copy of it. The render runs it with
the program `node` on the `PATH`, and the variable `EXPRESSO_NODE` gives a different path.
A deck without a Mermaid diagram needs no Node.

## The colors and the font of a graph

A graph gets the colors of the theme, so it changes with the theme and with the dark variant
of a theme. With `colors :tool`, the graph keeps the colors of the tool. Use `:tool` for a
graph with colors that have a meaning.

| Tool | The colors of the theme |
| --- | --- |
| Graphviz | The lines and the text take the color `--text`, and the white background goes away. A color that the source gives, such as `color=red`, stays. |
| D2 | Each class of the palette of D2 takes a custom property, such as `--graph-B4` for the fill of a shape. The table below gives the default of each property. The background goes away. |
| Pele | Pele writes each color as a custom property, such as `--pele-fg`, and the theme sets each one: the text and the lines take `--text`, the shapes take a tint of `--accent` with a border of `--accent`, and the series of a chart take `--chart-1` to `--chart-8`. |

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
regular file. In Graphviz, a `fontname` of the source still applies to its element. For
Mermaid, the render reads the advance width of each character from the files, and Pele
sizes each box from those widths. A monospace text in a Mermaid diagram takes a fixed width
of 0.6 of the size for each character.

## A graph and a screen reader

A screen reader reads the text of an SVG in the order of the file, and that order is not the
order of the graph. Therefore a graph without the `alt` option gets a nested list for a
screen reader, and the screen reader does not read its SVG. The screen and paper do not show
the list.

The list holds each container with its nodes, and each node with the edges that leave it.
For the graph of the examples above, a screen reader reads this list:

- App
  - web, to api
  - api, to db, to db (replica)
- db

An edge with a label gets the label in parentheses. An edge with no direction, such as
`a -- b`, reads "with b". The label of a node is the text that it shows, or its name when it
shows no text. With the `alt` option, the diagram is one image with that name, and it gets no
list.

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
