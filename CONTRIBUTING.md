# Contributing

This document tells you how to make a change to Expresso and send it as a pull request.

## Make a change

1. Get the toolchain. [The toolchain](docs/development/toolchain.md) gives the versions and
   how to get them, with Nix or without it.
2. Read [`CLAUDE.md`](CLAUDE.md). It gives the conventions for a branch, a commit message
   and the prose of a document or a comment.
3. Make a branch. Do not commit to `main`.
4. Run `mix check` before each commit. [The checks](docs/development/checks.md) tells what
   each check needs.
5. Push the branch, and open a pull request. In the pull request, tell the maintainer which
   checks you ran.

The maintainer merges the pull request. A change that needs more than one pull request goes
as a stack, and "Git" in `CLAUDE.md` tells how to open one.

## The documents for a contributor

[`docs/development.md`](docs/development.md) lists a page for each topic, such as the
browser tests, the binary, the workflow and the presenter script. These documents give the
design and its reasons:

- [`docs/architecture.md`](docs/architecture.md) — how the code makes an HTML document from
  a deck.
- [`docs/overlays.md`](docs/overlays.md) — the design for overlays, which are the steps
  inside one slide.
- [`docs/typescript.md`](docs/typescript.md) — the plan for the presenter script in
  TypeScript, and its result.
- [`docs/dim-state.md`](docs/dim-state.md) — the design for a dim state with a color for
  each role.
- [`docs/tree.md`](docs/tree.md) — the design for the element `tree`, and its result.

The site at https://rellen.github.io/expresso/ shows only the documents for a user. GitHub
shows each document of this list.
