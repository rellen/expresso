# The graph tools

This page tells you how to install the tools that draw a graph, and how to run their
tests. A `diagram` with a `.dot` or a `.gv` file runs Graphviz, and a `diagram` with a
`.d2` file runs D2. A `diagram` with a `.mmd` file, or with a Mermaid source in the deck,
runs Pele in Node. `Expresso.Element.Math.Tex` runs Temml in Node, and it makes the MathML
of a formula in LaTeX. `docs/graph-diagrams.md`, `docs/mermaid-diagrams.md` and
`docs/math-parts.md` give the design.

## The tests

The tests that run a tool have the tag of the tool. `mix test` excludes them, as it
excludes the browser tests.

| Tag | Tool | Program |
| --- | --- | --- |
| `:graphviz` | Graphviz | `dot` |
| `:d2` | D2 | `d2` |
| `:mermaid` | Pele in Node | `node` |
| `:temml` | Temml in Node | `node` |

```sh
mix test --only graphviz --only d2 --only mermaid --only temml   # the tests of each tool
```

The other tests of a graph use an SVG that the tool wrote, in `test/fixtures/graphviz/` and
`test/fixtures/d2/`, or the JSON that the script of Pele wrote, in `test/fixtures/mermaid/`. A test with the tag makes sure that the tool still gives the names of
that fixture. After a change of a source, write its SVG again:

```sh
dot -Tsvg test/fixtures/graphviz/flow.dot -o test/fixtures/graphviz/flow.svg
d2 --layout elk --omit-version --pad 0 test/fixtures/d2/flow.d2 test/fixtures/d2/flow.svg
```

Each `.mmd` file of `test/fixtures/mermaid/` has a `.json` file with the output of the
script of Pele. A test with the tag `:mermaid` compares each one with a new run, and this
command writes them again:

```sh
EXPRESSO_MERMAID=write mix test --only mermaid test/expresso/diagram_mermaid_fixtures_test.exs
```

`mix check` runs the tests with the tags in the tool `graph`, and the job `graph` of the
workflow runs them too.

Two example decks of `examples/animations/` draw a graph. The browser test that renders each
example deck, and `mix expresso.gifs`, therefore need both tools too.

## The installation

| Place | Graphviz | D2 |
| --- | --- | --- |
| A remote session | The hook installs the package `graphviz` with `apt-get`. | The hook builds D2 0.7.1 with `go install` into `/opt/d2`. |
| The workflow | `.github/actions/setup-graph-tools` installs the package `graphviz` with `apt-get`, in the jobs `graph`, `e2e` and `gifs`. | The same action gets the release of D2 0.7.1 from GitHub. |
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

Graphviz measures a text through fontconfig only when it has its plugin `cairo`. The
package `graphviz` of Ubuntu, of Homebrew and of Nix has it.

The render finds `dot` and `d2` on the `PATH`. The variables `EXPRESSO_DOT` and
`EXPRESSO_D2` give a different path.

## Pele

Pele is a library in JavaScript, so it has no program of its own to install.
`priv/pele/` holds a copy of `pele.js`, its license, and the script `render.mjs`, and the
render runs the script with Node. Node is in `.tool-versions` for the checks, and the
variable `EXPRESSO_NODE` gives a different path. The binary of Burrito holds no Node, so a
deck with Mermaid needs Node on the `PATH` of the computer that renders it.

`package.json` names the same version of Pele, so Dependabot proposes a new version. To
take a new version:

1. Change the version in `package.json`, and run `npm install`.
2. Copy `node_modules/pele/dist/pele.js` and `node_modules/pele/LICENSE` to `priv/pele/`.
3. Change `@version` in `Expresso.Element.Diagram.Pele`. A test compares it with
   `package.json`.
4. Write the fixtures of `test/fixtures/mermaid/` again with the command above, and run
   `mix test --only mermaid`.

## Temml

Temml is a library in JavaScript that makes MathML from LaTeX, for the `math` element.
`priv/temml/` holds a copy of `temml.mjs`, its license, and the script `render.mjs`, and the
render runs the script with Node, as for Pele. One run makes the MathML of each formula of a
deck. A deck with no LaTeX needs no Node. `docs/math-parts.md` gives the design.

`package.json` names the same version of Temml, so Dependabot proposes a new version. To
take a new version:

1. Change the version in `package.json`, and run `npm install`.
2. Copy `node_modules/temml/dist/temml.mjs` and `node_modules/temml/LICENSE` to
   `priv/temml/`.
3. Change `@version` in `Expresso.Element.Math.Tex`. A test compares it with `package.json`.
4. Run `mix test --only temml`.
