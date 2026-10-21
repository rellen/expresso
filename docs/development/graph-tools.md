# The graph tools

This page tells you how to install the tools that draw a graph, and how to run their
tests. A `diagram` with a `.dot` or a `.gv` file runs Graphviz, and a `diagram` with a
`.d2` file runs D2. `docs/graph-diagrams.md` gives the design.

## The tests

The tests that run a tool have the tag of the tool. `mix test` excludes them, as it
excludes the browser tests.

| Tag | Tool | Program |
| --- | --- | --- |
| `:graphviz` | Graphviz | `dot` |
| `:d2` | D2 | `d2` |

```sh
mix test --only graphviz --only d2   # the tests of each graph tool
```

The other tests of a graph use an SVG that the tool wrote, in `test/fixtures/graphviz/` and
`test/fixtures/d2/`. A test with the tag makes sure that the tool still gives the names of
that fixture. After a change of a source, write its SVG again:

```sh
dot -Tsvg test/fixtures/graphviz/flow.dot -o test/fixtures/graphviz/flow.svg
d2 --layout elk --omit-version --pad 0 test/fixtures/d2/flow.d2 test/fixtures/d2/flow.svg
```

`mix check` runs the tests with the tags in the tool `graph`, and the job `graph` of the
workflow runs them too.

## The installation

| Place | Graphviz | D2 |
| --- | --- | --- |
| A remote session | The hook installs the package `graphviz` with `apt-get`. | The hook builds D2 0.7.1 with `go install` into `/opt/d2`. |
| The workflow | The job `graph` installs the package `graphviz` with `apt-get`. | The job `graph` gets the release of D2 0.7.1 from GitHub. |
| The Nix shell | `shell.nix` gives the package `graphviz`. | `shell.nix` gives the package `d2`. |
| macOS | `brew install graphviz` | `brew install d2` |

A remote session and the workflow both run Ubuntu 24.04, so `apt-get` gives both the same
version of Graphviz. The Nix shell gives a newer version. The tests make sure of the names
and the steps, and not of the coordinates, so each version passes.

The proxy of a remote session refuses a download from a repository that the session does
not hold, such as a release of D2 on GitHub. It lets Go get the modules, so the hook builds
D2 with Go. The build takes approximately 30 seconds, and the hook removes the caches of Go
after it. `D2_VERSION` in the hook and in `.github/workflows/check.yml` gives the version,
and the two must agree.

The render finds `dot` and `d2` on the `PATH`. The variables `EXPRESSO_DOT` and
`EXPRESSO_D2` give a different path.
