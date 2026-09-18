# Gleam and Lustre for the presenter script

This document gives the result of an investigation on 2026-09-19. The question is this:
can Gleam and Lustre replace TypeScript for the script inside the presentation HTML?

The investigation built a working Gleam port of the presenter, and it measured the bundle.
The numbers below come from that build, and not from an estimate.

## The answer

Gleam is possible, and the cost is 6 times the size of the bundle and one more tool in the
build. Lustre is not correct for this program. Lustre makes the DOM, and the presenter does
not make the DOM. `Expresso.Renderer` makes the DOM.

The recommendation is to keep TypeScript.

## The measurement

Each bundle below is the output of esbuild with `--bundle --format=iife --minify
--target=es2020`, which is the configuration of the repository today.

| Script | Bytes | Bytes after gzip |
| --- | --- | --- |
| TypeScript today (`assets/src/`) | 1088 | 551 |
| Gleam, no framework | 6437 | 2457 |
| Gleam and Lustre, minimal application | 50046 | 15530 |

The three modules of `assets/src/` went into Gleam as `state.gleam`, `dom.gleam` and
`presenter.gleam`, with the DOM operations in two small `.mjs` files behind `@external`.
The port gives the same result as the TypeScript for the keys `j`, `k` and `p`, and for
the limits of the deck.

The Lustre number is the floor and not the port. It comes from a Lustre program of 40
lines that holds two integers and shows one number. A port of the presenter is larger.
The Lustre documents give 10 kB for the client of a server component, which is a
different and smaller runtime.

### Why the Gleam bundle is 6 times larger

The Gleam compiler puts a prelude in the output. The file `prelude.mjs` of the compiler
has 34.9 kB, and it holds the classes for a list, a result, a custom type and a bit array.
esbuild removes the part that the program does not use, and approximately 5 kB stays. The
program itself is small, as the TypeScript is small.

The bundle goes into the HTML file, and a person opens that file from the disk. Therefore
the size after gzip does not apply. 1 kB becomes 6 kB, and this is the honest number.

## The constraints of the repository

`docs/typescript.md` gives four decisions. Gleam agrees with two of them, and it breaks
one.

### The output is one HTML file

Gleam agrees. The Gleam compiler writes ES modules, and esbuild makes one IIFE from them,
as it does for the TypeScript. The bundle has no `import`, no `export` and no `</script>`.
The measurement above confirms each of these.

### The target is ES2020

Gleam agrees, with esbuild. The compatibility reference of Gleam asks for ECMAScript 2022
or higher, and the document says that a bundler can make an older version. esbuild with
`--target=es2020` accepted the output of the compiler with no error. Therefore the floor of
`docs/overlays.md` — Chrome 85, Safari 16.4 and Firefox 128 — stays.

### `mix compile` needs no other tool

Gleam breaks this decision. This is the largest cost.

Today the Hex package `esbuild` downloads one binary, and Elixir runs it. Therefore
`mix compile` works with Elixir alone, and a person who builds the Burrito release needs
nothing more.

No Hex package gives the Gleam compiler. `mix_gleam` and `gleam_compile` run the compiler,
and both ask the person to install the compiler first. Therefore `mix compile` needs the
`gleam` binary on the machine, and `flake.nix`, `shell.nix`, the hook in
`.claude/hooks/session-start.sh` and the workflow in `.github/workflows/check.yml` each
need a change.

Two facts make the cost smaller than it appears:

- The Gleam compiler needs no Erlang for the JavaScript target. The investigation
  compiled the port on a machine with no `erl`.
- `flake.nix` can give the compiler, and Nix pins the version. The Nix shell is the
  environment of the repository.

The cost stays, because the compiler is an operating system dependency and not a Hex
dependency. A person outside the Nix shell must install it.

### The `script` element stays classic

Gleam agrees. The IIFE format gives a classic script.

## Why Lustre is not correct

Lustre is a framework of the Elm architecture. `lustre.start` takes a selector, it removes
the content of that element, and a virtual DOM then owns the content. Lustre has no
function that takes HTML from another source and holds it.

The presenter does the opposite. `Expresso.Renderer` makes each `section`, and the script
writes two attributes: `data-view` on the `body`, and `data-step` on one `section`. The
comment in `assets/src/dom.ts` says that these two attributes are the only operations of
the presenter on the document, and `docs/overlays.md` makes the CSS the owner of each
other change.

To use Lustre, the deck must move from Elixir into Gleam. That is a different program, and
it breaks the reason for the Elixir DSL.

Lustre also holds a second risk. The style sheet and the generated rules of the overlays
read the attributes of the document. A virtual DOM writes the document on its own schedule,
and `docs/overlays.md` asks for one render for each step.

## What Gleam gives

The investigation found three benefits:

- **The state machine gets a total type.** `state.ts` writes `View` as a union of two
  strings, and `State` as an object. Gleam gives a custom type, and the compiler refuses a
  `case` that does not cover each constructor. The overlay work of `docs/overlays.md` adds
  rules to this state machine, and a total `case` finds an error that TypeScript does not
  find.
- **The record update syntax removes repetition.** `next` in `state.ts` writes each of the
  three fields in each branch. Gleam writes `State(..state, step: state.step + 1)`. The
  port is shorter than the TypeScript for this reason.
- **One language for the repository.** Gleam and Elixir are both on the BEAM, but the
  script does not run on the BEAM. Therefore this benefit is small. The two programs share
  no code and no type.

## What Gleam costs

- 6 times the size of the bundle, in each HTML file.
- One operating system dependency for `mix compile`, and a change to four environment
  files.
- The DOM code becomes `.mjs` behind `@external`, and that code has no type check. Today
  `dom.ts` has a type check from `tsc` and the DOM types of TypeScript. A binding library
  such as `plinth` or `gossamer` gives types for the DOM, and it also gives one more
  dependency and more bytes.
- The tests change tool. `node --test` runs a `.ts` file with no build step today.
  A Gleam test needs `gleam test`, and the run needs a build.
- `prettier` no longer formats the script. `gleam format` does.

## The size of the problem

`assets/src/` has 144 lines, and its tests have 287 lines. The overlay work makes the
state machine three or four times larger, as `docs/typescript.md` says. A program of
approximately 500 lines does not need the type system of Gleam, and the current tools give
a type check and a test for each rule.

## The conditions for a new decision

Change the decision when one of these becomes true:

- The state machine becomes large enough that a total `case` finds errors that `tsc` does
  not find. A rule for each key, each view and each step of `docs/overlays.md` can reach
  this point.
- A Hex package gives the Gleam compiler, so that `mix compile` needs no other tool.
- The presenter must make the DOM, and not only write two attributes. Lustre then becomes
  a candidate, and the deck must move into Gleam first.

## The sources

- [The compatibility reference of Gleam](https://gleam.run/documentation/compatibility-reference/)
  gives ECMAScript 2022 as the floor of the JavaScript target, and it says that a bundler
  can make an older version.
- [The JavaScript backend of the compiler](https://deepwiki.com/gleam-lang/gleam/3.2-javascript-backend)
  describes the ES module output.
- [`prelude.mjs` of the compiler](https://github.com/gleam-lang/gleam/blob/main/compiler-core/templates/prelude.mjs)
  has 34.9 kB in 1433 lines.
- [The installation instructions of Gleam](https://gleam.run/getting-started/installing/)
  give a prebuilt binary from the GitHub release page.
- [`mix_gleam`](https://github.com/gleam-lang/mix_gleam) and
  [`gleam_compile`](https://github.com/praveenperera/gleam_compile) both ask the person to
  install the compiler first.
- [The Gleam discussion on Erlang](https://github.com/gleam-lang/gleam/discussions/3138)
  says that Gleam has no strict Erlang requirement.
- [The `lustre` module](https://lustre.hexdocs.pm/lustre.html) gives `start`, `component`
  and `start_server_component`, and it gives no function for HTML from another source.
- [The `server_component` module](https://hex.pm/packages/lustre/5.7.1/files/src/lustre/server_component.gleam)
  gives 10 kB for the client runtime of a server component.
- [A case study of Lustre](https://dev.to/enoonan/lustre-and-gleam-make-my-heart-rate-go-down-a-case-study-5765)
  reports 18.1 kB for a bundle, minified and after gzip.
- [The API document of esbuild](https://esbuild.github.io/api/) describes `--target`, which
  makes an older version of the syntax.
