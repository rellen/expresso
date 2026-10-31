# Development

This document tells you how to get a toolchain, how to run the checks and how to look at a
deck in a browser. Each topic has a page in `docs/development/`:

| Page | Topic |
| --- | --- |
| [The toolchain](development/toolchain.md) | The versions of the tools, on your machine and in a Claude Code session on the web |
| [The checks](development/checks.md) | Each command of `mix check`, what it needs, and flaky tests |
| [The unit tests](development/unit-tests.md) | Property tests, and the HTML of a deck in a unit test |
| [The browser tests](development/browser-tests.md) | The tests in Chromium, and how to look at a deck in a browser |
| [The graph tools](development/graph-tools.md) | Graphviz and D2 for the diagrams from the source of a graph, and their tests |
| [The binary and its tests](development/release.md) | The binary, the dependency test and the release tests |
| [The workflow](development/ci.md) | The checks of a pull request on GitHub, and Zig in the workflow |
| [The dependencies](development/dependencies.md) | The audit of the dependencies, their updates and the icons |
| [The presenter script](development/presenter-script.md) | The TypeScript of the presenter: its lint, its schema, its fixtures and the tables of keys |
| [Add a built-in theme](development/themes.md) | The steps to add a base16 scheme as a theme |
| [Record the GIFs and the stills](development/gifs.md) | `mix expresso.gifs`, and the branch `media` |

Start with this command, which runs each check:

```sh
mix check
```

## Documents

`mix docs` makes the site of the documents in `doc/`, and https://rellen.github.io/expresso/
shows the site of the last push to `main`. `mix.exs` gives ExDoc the list of the documents
and their groups. The site holds the documents for a user: the README, the tutorial, the
how-to guides, the reference pages and the two explanations below. The documents for a
contributor, such as this index and `docs/development/`, stay in the repository, and
GitHub shows them. A link from a page of the site to one of them uses its address on
GitHub.

- `docs/architecture.md` — how the code makes an HTML document from a deck.
- `docs/overlays.md` — the design for overlays, and its decisions.
- `docs/typescript.md` — the plan for the presenter script in TypeScript, and its result.
- `docs/dim-state.md` — the design for a dim state with a color for each role.
- `docs/tree.md` — the design for the element `tree`, and its result.
- `docs/graph-diagrams.md` — the design for a diagram from Graphviz or D2, and its result.
- `docs/scatter-plots.md` — the design for a scatter plot, and its result.
- `docs/waterfall-charts.md` — the design for a waterfall chart, and its result.
- `docs/math-parts.md` — the design for a formula with parts, and its result.
- `docs/part-copies.md` — the design for a copy of a part, and its result.
- `docs/line-links.md` — the design for the links between the lines of a derivation, and its
  result.
- `docs/each-occurrence.md` — the design for each occurrence of a symbol, and its progress.
