# The unit tests

This page tells you how to write a property test and a test that reads the HTML of a deck. `mix test` runs both.

## Property tests

`stream_data` gives the property tests. Put `use ExUnitProperties` in the test module, and
then write `property` in place of `test`. `test/expresso/image_element_test.exs` gives an
example. It makes a random width, and it compares the result against the rule.

`test/support` holds the generators, and `mix.exs` compiles this directory in the test
environment only. `Expresso.Test.CSS` makes a value of the CSS `width` property: a length
in each unit of CSS Values and Units 4, a percentage, a keyword, a custom property and a
math function such as `calc`, `min`, `max` and `clamp`. The module makes the text of the
value, because the DSL holds a width as a string. `Expresso.Test.Overlay` makes an overlay
specification of each form of `docs/overlays.md`, and a term that `Expresso.Overlay.new/1`
refuses.

A property that fails gives the smallest value that it found, and the seed of the run. Run
`mix test --seed <seed> <file>:<line>` to get the same values again.

`config/config.exs` gives each property 500 runs. The generators make many forms, and the
default of 100 runs does not reach enough of them.

The dependency is present in `dev` and in `test`. `mix format` runs in `dev`, and it reads
`deps/stream_data/.formatter.exs` through `import_deps`. Therefore the formatter writes no
parentheses after `check all`.

## The HTML in a unit test

Each unit test that reads the HTML of a deck uses LazyHTML. `lazy_html` is a dependency
for the `test` environment only. The tests of the table, the list, the image and the other
content elements are examples, such as `test/expresso/table_element_test.exs`.

The first compile of `lazy_html` downloads its NIF from GitHub. `elixir_make` keeps the
file in `~/.cache/elixir_make`, so a later compile needs no network. The NIF needs only
`libc`, `libstdc++` and `libgcc_s`, and the BEAM loads these libraries too.

LazyHTML parses the HTML with Lexbor, as a browser does. It also takes each CSS selector of
a browser, such as `:has()` and `:is()`. Floki does not know these selectors, and it
ignores them with no error. Thus a Floki query with `:has()` can find the wrong nodes, and
the test can pass.

Write a test with LazyHTML as follows:

1. Parse a document with `LazyHTML.from_document/1`, or the HTML of one element with
   `LazyHTML.from_fragment/1`.
2. Find the nodes with `LazyHTML.query/2`.
3. Read the result with `Enum.count/1`, `LazyHTML.attribute/2`, or
   `Enum.map(&LazyHTML.text/1)` for the text of each node.

`import Expresso.Test.HTML` gives short forms for these steps:

| Function | Returns |
| --- | --- |
| `one_slide(elements, slide_opts \\ [], deck_opts \\ [])` | A deck with one slide, `"s"`, that holds the elements |
| `document(deck)` | The parsed document of a deck, or of the deck of a DSL module |
| `screen(html, selector)` | The nodes of the selector inside `.screen`, the present view |
| `only!(nodes)` | The one node of a query. The test fails for a different number. |
| `script_json(html, name)` | The data of the block `script#expresso-<name>`, such as `"videos"` |
| `count(html, selector)` | The number of the nodes of the selector |
| `texts(html, selector)` | The text of each node of the selector |

A test of one element thus reads as follows:

```elixir
figure = chart |> one_slide() |> document() |> screen("figure.chart") |> only!()
```

The document writes each slide into the present view, into the handout view and into the
thumbnails of the menu. A query without `.screen` therefore finds each node more than one
time. A test module that imports
`Expresso.Test.HTML` cannot define a private function with the same name and arity, such
as `document/1`. Give a private helper a different name, or a different arity, such as
`document/0` for the deck of the module.

Three other modules of `test/support/` hold the helpers that more than one test file
needs:

| Module | Functions |
| --- | --- |
| `Expresso.Test.Decks` | `find_slide(deck, name)` finds a slide of a deck or of a DSL module. `box(text)` makes a text box with one text area. |
| `Expresso.Test.Warnings` | `texts(warnings)` gives the text of each warning of a check, such as `Expresso.Overlay.Size.slide/1`. |
| `Expresso.Test.HTTP` | `get(url)` gets a page with `:httpc`. `raw_get(port, path, headers)` sends the request on a TCP socket. |

The names of `Expresso.Test.Decks` are not names of the DSL. An import puts its functions
into each deck module inside the test module too, and a name such as `slide/2` would
conflict with the entity `slide` of the DSL.

To assert that an element has no part, find the element with `:not(:has(...))`, and
assert that the query finds one node. A query that must find no node also finds no node
when its selector has an error, so that assertion passes for the wrong reason.
`:not(:has(...))` catches an error in the selector of the element. An error in the
selector inside `:has()` still finds no part, so put there a selector that a different
test finds.

LazyHTML is different from Floki in these points:

- `:root` is the root of the document. `Floki.find(node, ":root > div")` finds a child of
  the node, but the same LazyHTML query finds no node, and it gives no error. Write the
  full selector from the document, such as `#slide-1 .math > div`.
- A selector that LazyHTML does not know, such as `:scope`, raises an error.
- The result of a query is a struct and not a list. Thus `nodes != []` is always true,
  `nodes == []` is always false, and a `case` clause `[] ->` never matches. Use
  `Enum.count/1` or `count/2`, or match the list that `texts/2` returns.
- A `for` comprehension that matches a tuple, such as
  `for {"span", _attributes, children} <- nodes`, skips each node of a LazyHTML result.
  The loop then checks nothing, and the test passes. Give the loop
  `LazyHTML.to_tree(nodes)`.
- Two queries return two different structs for the same node. Thus `==` and `MapSet`
  cannot find the same node in two results. Compare `LazyHTML.to_html/1` of the nodes.
- `LazyHTML.text/1` joins the text nodes with no separator. Floki takes the option
  `sep: " "`. To read each text node, use `LazyHTML.to_tree/1`, as the helper `words/1`
  of `test/expresso/accessibility_test.exs` does.
- `LazyHTML.text/1` returns the text of a `script` element. Floki needs the option
  `js: true` for it.
- A query on a node returns only nodes inside that node. But its selector can name an
  ancestor outside the node, so `.screen figure.chart svg` finds the `svg` of a figure in
  each case. In Floki, the selector sees only the node and the nodes inside it.
- In an `svg` element, a name is the name of the browser, such as `viewBox` and
  `linearGradient`. A query finds a name in each case, and `LazyHTML.to_html/1` writes the
  name of the browser.
- `LazyHTML.query/2` examines the nodes inside the nodes that it gets, and
  `LazyHTML.filter/2` examines the nodes that it gets. Thus
  `figure |> LazyHTML.filter(":not(:has(figcaption))")` asserts that one figure has no
  caption.

Until October 2026, the unit tests used Floki. This table gives the replacement of each
Floki call:

| Floki | LazyHTML |
| --- | --- |
| `Floki.parse_document!(html)` | `LazyHTML.from_document(html)` |
| `Floki.parse_fragment!(html)` | `LazyHTML.from_fragment(html)` |
| `Floki.find(html, selector)` | `LazyHTML.query(html, selector)` |
| `Floki.attribute(nodes, name)` | `LazyHTML.attribute(nodes, name)` |
| `Floki.attribute(html, selector, name)` | `html \|> LazyHTML.query(selector) \|> LazyHTML.attribute(name)` |
| `Floki.children(node)` | `node \|> LazyHTML.child_nodes() \|> LazyHTML.to_tree()` |
| `Floki.text(nodes)` | `LazyHTML.text(nodes)` |
| `assert [_] = Floki.find(html, selector)` | `assert count(html, selector) == 1` |
| `[a, b] = Floki.find(html, selector)` | `[a, b] = html \|> LazyHTML.query(selector) \|> Enum.to_list()` |
| `Floki.find(node, ":root > tag")` | The full selector from the document, with `> tag` |
| `Floki.raw_html(nodes)` | `LazyHTML.to_html(nodes)` |
| `Floki.text(script, js: true)` | `LazyHTML.text(script)` |
| `assert nodes != []` | `assert count(html, selector) > 0` |
| A match on `{tag, attributes, children}` | A match on the result of `LazyHTML.to_tree/1` |

`lib/` keeps Floki. `Expresso.Deck.render/1`, `Expresso.Highlight`, `Expresso.Morph`,
`Expresso.Element.Diagram` and `Expresso.Check.Document` use it at run time. A release with
LazyHTML needs its NIF for each target of Burrito. `Expresso.Deck.render/1` passes the
document through Floki, and Floki drops a text node that is only white space. Thus that
node is not in the document that a test parses.

`Expresso.Element.Diagram.Geometry.distance/3` takes a Floki tree. Thus
`test/expresso/move_to_test.exs` parses its SVG file with Floki, and no other test calls
Floki.
