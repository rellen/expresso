# Diagrams from Graphviz and D2

This document gives a plan for a `diagram` that takes the source of a graph, in the
language of Graphviz or of D2. The render runs the tool, and the deck animates the nodes
and the edges with the parts of the `diagram` element. The document ends with ten
decisions, and each is settled. Issue #386 holds the same plan.

## The problem

A talk often shows a graph: the services of a system, the states of a process, or the
modules of a program. Graphviz and D2 calculate the layout of such a graph from a short
text. Graphviz is old and fast, and many tools write its language. D2 is newer. Its ELK
layout routes each edge with right angles, and a container holds its nodes.

A deck can show such a graph now, as a `diagram` from an SVG file. Pull request #384 makes
the files of both tools work, and a test in that pull request animated a graph from each
tool. The test found these problems:

- **The author runs the tool by hand.** The deck names the SVG file, and not the source.
  The SVG file is old after each change of the source, and the watch mode does not see a
  change of the source.
- **D2 gives no `id` to a shape.** A part finds an element by its `id`. D2 names each shape
  with a class that holds its key in Base64, such as `YXBwLndlYg==` for `app.web`. The test
  needed a script that copied each key into an `id`.
- **Graphviz numbers each element without an `id`.** A node without an `id` in the source
  gets `node1`, `node2` and so on. The numbers change when the graph changes, so a part
  must name an `id` that the author writes into the source.
- **The theme does not reach the colors.** Graphviz writes black lines, a white background
  and the font Times into the file. D2 writes its own palette. The colors do not change
  with the theme, and they do not change with the dark variant of a theme.
- **Each edge needs its own part.** An edge that joins two nodes must show at the step of
  the later node. The author writes each step two times: one time for the node, and one
  time for the edge.
- **A screen reader gets the text in the order of the file.** D2 writes no `<title>`, and
  the order of the file is not the order of the graph.

## The constraints

- The output stays one HTML file, and the presenter script does not calculate a layout.
  The render runs the tool, as the render calculates the layout of a chart.
- A diagram from a source obeys the overlay contract: `at`, `on`, `effect`, `dim`, `class`
  and `morph`. Each part keeps the options of a part of an SVG file, such as `move_to`.
  See `docs/overlays.md`.
- The same deck gives the same document. The release tests compare the document of the
  binary with the document of `Expresso.main/2`.
- Expresso does not hold Graphviz or D2. A deck without a graph source needs neither tool,
  and the binary of Burrito stays the same size.
- A tool that is not present stops the render with a message that names the tool and the
  way to install it.
- The watch mode renders the deck again after a change of the source.
- The handout view and paper show each step that the present view can show.

## The facts about the two tools

These facts come from Graphviz 2.43.0 and D2 0.7.1 in a session on Linux x86_64.

| Fact | Graphviz | D2 |
| --- | --- | --- |
| The command | `dot -Tsvg` | `d2 --layout elk - -` |
| The input and the output | The standard input and the standard output | The standard input and the standard output |
| The time for a graph of 4 nodes | 0.025 s | 2.0 s with ELK, 0.27 s with dagre |
| The size of the program | A package of the system | One binary of 48 MB |
| The same source gives the same SVG | Yes | Yes |
| The `id` of a node | The `id` attribute of the source, else `node1`, `node2` | None |
| The name of a node in the SVG | A `<title>` with the name, such as `web` | A class with the key in Base64 |
| The name of an edge in the SVG | A `<title>` such as `web->api` | A class with a key such as `(app.api -> db)[0]` |
| The `class` of the source | Yes, after the class `node` or `edge` | No |
| The colors | Attributes, such as `stroke="black"` | Classes of a palette, such as `fill-B4` and `stroke-B1` |
| The fonts | The font of the system, Times by default | Source Sans Pro, in the SVG as a data URI |
| An `svg` in the root `svg` | No | Yes |

The ELK layout of D2 runs inside the binary of D2, so D2 needs no Java and no Node.

## The plan

### The entity

The `diagram` element takes a source file. The extension of the file selects the tool:

| Extension | Tool |
| --- | --- |
| `.svg` | None. The diagram shows the file, as now. |
| `.dot` and `.gv` | Graphviz |
| `.d2` | D2 |

```elixir
slide "the system" do
  diagram "system.d2" do
    layout :elk
    width "80%"

    part "app.web"
    part "app.api", at: [from: 2]
    part "db", at: [from: 3]

    part "app" do
      on 4, state: :alert
    end
  end
end
```

The diagram gets these options:

| Option | Value | Effect |
| --- | --- | --- |
| `layout` | For D2, `:elk` or `:dagre`. For Graphviz, `:dot`, `:neato`, `:fdp`, `:sfdp`, `:circo` or `:twopi`. | The layout engine. The default is `:elk` for D2 and `:dot` for Graphviz. |
| `edges` | `:follow` or `:own` | `:follow` shows an edge from the step where both of its ends show. `:own` gives an edge only the steps of its own part. The default is `:follow`. |
| `colors` | `:theme` or `:tool` | `:theme` gives the graph the colors of the theme. `:tool` keeps the colors of the tool. The default is `:theme`. |
| `font` | The path of a directory with TTF files | The font of the text. The default is the font of the built-in theme. See "The fonts". |

A verifier refuses `layout`, `edges`, `colors` and `font` for an SVG file, and a layout that
is not a layout of the tool.

### The run of the tool

A module for each tool runs the tool with `System.cmd/3`. The module sends the source to
the standard input, and it reads the SVG from the standard output.

| Tool | Arguments |
| --- | --- |
| Graphviz | `-Tsvg -K<layout>` |
| D2 | `--layout <layout> --omit-version --pad 0 - -` |

The render finds each tool on the path. `EXPRESSO_DOT` and `EXPRESSO_D2` give a different
path, as `EXPRESSO_CHROMIUM` gives the path of the browser for `--check`. A tool that is not
present stops the render with this message, for example:

```
the diagram "system.d2" needs D2, and the render does not find `d2` on the path.
Install D2 from https://d2lang.com, or give its path in EXPRESSO_D2.
```

An error of the tool, such as a syntax error in the source, stops the render with the
message of the tool and the path of the source.

`Expresso.DeckFile` reads the source, so the watch mode sees each change of the source.

### The cache

D2 with ELK takes about 2 s for a small graph. The watch mode renders the whole deck after
each change, so a deck with five graphs would wait 10 s after a change of the text of one
slide.

The watch mode therefore keeps the SVG of each source in a cache. The key is the hash of the
tool, its version, its arguments, the font and the source. A render from the command line runs each
tool one time and does not need the cache.

### The names of the parts

The render gives each node, edge and container an `id`, so a part names it in the words of
the source. The render keeps an `id` that the source gives.

| Element | Graphviz | D2 |
| --- | --- | --- |
| A node | The name of the node, such as `web` | The key, such as `app.web` |
| A container | The name of the cluster, such as `cluster_app` | The key, such as `app` |
| An edge | The two ends, such as `web->api`, or `a--b` in a graph with no direction | The two keys, such as `app.web->app.api` |
| A second edge between the same ends | `web->api:2` | `app.web->app.api:2` |

The name of an edge has no spaces, so `part "app.api->db"` names an edge of D2. An edge of
D2 inside a container gets the container in front of each end, as the key of each end has
it.

A part with a name that the graph does not have stops the render, as a part of an SVG file
does now. The message lists the names that the graph has, because the author cannot read
the names in the SVG.

### The edges that follow their nodes

The render knows the two ends of each edge from its name. With `edges :follow`, an edge
without its own part gets the steps where both of its ends show. An end without a part
shows at each step.

An edge with its own part keeps the steps of its part. Thus an author can show an edge
later than its nodes, for example to show a new connection.

### The colors

With `colors :theme`, the render and the theme change the colors of the tool:

- **Graphviz.** The render removes the white polygon of the background. It changes
  `black` to `currentColor` in `fill` and `stroke`. A text without a `fill` gets the color
  `--text`. A color that the source gives stays.
- **D2.** The theme gives each class of the palette of D2 a color of the theme. The render
  removes the rectangle of the background, which has the class `fill-N7`.

| Classes of D2 | Use in D2 | Color of the theme |
| --- | --- | --- |
| `N1` | The text | `--text` |
| `N2`, `N3` | The text of less importance | `--muted` |
| `N4` to `N6` | The lines of less importance and the fills | A mix of `--muted` and `--background` |
| `N7` | The background | `--background` |
| `B1`, `B2` | The lines of the shapes and the edges | `--accent` |
| `B3` to `B6` | The fills of the shapes and the containers | A mix of `--accent` and `--background` |
| `AA2` to `AA5`, `AB4`, `AB5` | The second and third colors | `--chart-2` and `--chart-3`, and their mixes |

A rule in the style sheet of D2 has a lower specificity than a rule of the theme, because
`Expresso.SvgCopy` puts each selector of the file in `:where()`. Thus the rules of the
theme apply. The dark variant of a theme changes the graph with the slide.

### The fonts

The text of a graph gets the font of the slide. Each tool measures the text with the font
that it gets, and it calculates the size of each box from that measure. Therefore the render
gives the font to the tool, and the browser then shows the text in the same font. A font
that only the style sheet changes would make a text wider than its box.

Expresso holds the font of the built-in theme, Atkinson Hyperlegible, only as WOFF2 files.
The tools read TTF files. Therefore `assets/fonts/` gets the four TTF files of the font:
regular, bold, italic and bold italic. The OFL license of the font lets Expresso hold them.

The render gives the font to each tool in this way:

| Tool | How the tool gets the font |
| --- | --- |
| D2 | `--font-regular`, `--font-bold`, `--font-italic` and `--font-semibold` with the TTF files. D2 then holds the font in the SVG. |
| Graphviz | A fontconfig file in a private directory names the directory of the TTF files. `FONTCONFIG_FILE` gives that file to the tool, and `-Nfontname`, `-Efontname` and `-Gfontname` name the font. |

Graphviz measures a text with fontconfig only through its plugin `cairo`. A test in the
session showed the effect: the same label got a box of 155 pt with Times and 185 pt with
DejaVu Sans. Graphviz uses a font of the system for a font that it does not find, and it
writes no warning. A test of the render must therefore make sure that the box fits the text
of the theme font.

A deck with a different font, from a theme or from the `css` option, gives the TTF files of
that font with the `font` option. The render cannot read a font from the CSS of the deck.
Without the option, the tool gets the font of the built-in theme.

### The views

The diagram is one SVG for each view, as now. The handout view and paper show each step,
because the steps are the steps of the parts.

### Accessibility

The render adds a nested list of the graph for a screen reader, as the `tree` element does.
The list holds each container with its nodes, and each node with the edges that leave it,
such as "web, to api". The style sheet hides the list from the eye. The `alt` option keeps
its effect: the diagram becomes one image with that name, and the list goes away.

### The tests

The tests that run a tool need that tool, so they get the tags `:graphviz` and `:d2`.
`mix test` excludes them, as it excludes `:e2e`. A test without a tool uses an SVG that the
tool wrote, in `test/fixtures/`.

The workflow installs Graphviz from the package of the system, and D2 from its release on
GitHub, with a fixed version. The hook of the session installs both tools too. The proxy of
a remote session refuses a download from a repository that the session does not hold, so
the hook builds D2 with `go install oss.terrastruct.com/d2@<version>`. The proxy lets Go
get the modules.

## The alternatives

- **A new element, such as `graph`.** A new element would repeat the parts, the width, the
  morph and the copies of `diagram`. A graph is a diagram that the render draws, so the same
  element fits.
- **The source in the deck, and not in a file.** A short graph could go into the deck as a
  string. The first pull requests take a file only. An option `source` can come later if a
  real deck needs it.
- **A layout in the browser.** Graphviz and D2 both run as WebAssembly. The document would
  then hold a layout engine of some megabytes, and the presenter script would calculate the
  layout. The handout view, paper and the layout check would wait for the script.
- **A layout in Elixir.** A layered layout, as in Graphviz and ELK, is a large program. The
  layout of the `tree` element took a stack of ten pull requests, and a general graph is
  harder than a tree.
- **WebAssembly in Elixir.** A library such as Wasmex could run the WebAssembly of a tool
  in the VM. Wasmex compiles a NIF in Rust, so each user and the binary of Burrito would
  need a Rust NIF.
- **Mermaid.** `mermaid-cli` needs a browser to calculate the layout, and a file from
  `mermaid-cli` already works as a `diagram`. Mermaid can come later with the same plan.

## The decisions

1. **The `diagram` element takes the source, and the extension selects the tool.** A new
   element would repeat most of `diagram`.
2. **The render finds each tool on the path, and an environment variable gives a
   different path.** The variables are `EXPRESSO_DOT` and `EXPRESSO_D2`. Expresso and the
   binary of Burrito do not hold the tools.
3. **The default layout of D2 is ELK.** ELK gives the better layout, and dagre is 7 times
   faster. The cache of the watch mode hides the time of ELK.
4. **The render gives each element an `id` from the source.** The names of the table in
   "The names of the parts" are the words of the source. A second edge between the same
   ends gets `:2`.
5. **An edge follows its nodes by default.** `edges :follow` is the default, and
   `edges :own` is for a deck that gives each edge its own steps.
6. **The theme gives the colors by default.** `colors :theme` is the default, and
   `colors :tool` is for a graph with colors that have a meaning.
7. **The text gets the font of the slide, and the render gives that font to the tool.**
   The tool then sizes each box for that font. `assets/fonts/` gets the TTF files of the
   font of the built-in theme. A `font` option gives the TTF files of a different font.
8. **The watch mode keeps a cache of each SVG.** The cache is in the process of the watch
   mode. The key is the hash of the tool, its version, its arguments, the font and the
   source.
9. **The tests that need a tool get a tag, and `mix test` excludes them.** The workflow
   installs both tools in one job. The tags are `:graphviz` and `:d2`, and the job is
   `graph` in `.github/workflows/check.yml`.
10. **The work comes in this stack of pull requests.** Each pull request is small and works
    alone. The first pull request also adds this document.
    1. Graphviz: the source file, the run of the tool, the `layout` option, the message for
       a tool that is not present, and the names of the parts.
    2. D2: the run of the tool, the `layout` option, the names of the parts, and the
       `svg` inside the root `svg`.
    3. The `edges` option.
    4. The `colors` option, the classes of D2 in the theme, the TTF files and the `font`
       option.
    5. The cache of the watch mode.
    6. The list for a screen reader.
    7. A guide in `docs/how-to/`, an example deck for each tool, and their GIFs.
