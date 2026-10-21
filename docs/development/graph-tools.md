# The graph tools

This page tells you how to install the tools that draw a graph, and how to run their
tests. A `diagram` with a `.dot` or a `.gv` file runs Graphviz. `docs/graph-diagrams.md`
gives the design.

## The tests

The tests that run a tool have the tag of the tool. `mix test` excludes them, as it
excludes the browser tests.

| Tag | Tool | Program |
| --- | --- | --- |
| `:graphviz` | Graphviz | `dot` |

```sh
mix test --only graphviz --only d2   # the tests of each graph tool
```

The other tests of a graph use an SVG that the tool wrote, in `test/fixtures/graphviz/`. A
test with the tag makes sure that the tool still gives the names of that fixture. After a
change of a source in `test/fixtures/graphviz/`, write its SVG again:

```sh
dot -Tsvg test/fixtures/graphviz/flow.dot -o test/fixtures/graphviz/flow.svg
```

`mix check` runs the tests with the tags in the tool `graph`, and the job `graph` of the
workflow runs them too.

## The installation

| Place | Graphviz |
| --- | --- |
| A remote session | The hook installs the package `graphviz` with `apt-get`. |
| The workflow | The job `graph` installs the package `graphviz` with `apt-get`. |
| The Nix shell | `shell.nix` gives the package `graphviz`. |
| macOS | `brew install graphviz` |

A remote session and the workflow both run Ubuntu 24.04, so `apt-get` gives both the same
version of Graphviz. The Nix shell gives a newer version. The tests make sure of the names
and the steps, and not of the coordinates, so each version passes.

The render finds `dot` on the `PATH`. The variable `EXPRESSO_DOT` gives a different path.
