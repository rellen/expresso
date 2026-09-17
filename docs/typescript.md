# TypeScript for the presenter script

This document gives a plan for the presenter script in TypeScript. The code does not
contain this plan yet. The document ends with four decisions.

## The constraint

One constraint holds. The output of Expresso is one HTML file that stands alone. The file
holds the presenter script, and a person can open the file with no other file. A minified
script is acceptable.

Nothing else holds. The structure of the script today, and the form of the `script`
element today, are results of a small first version. They are not constraints. The plan
below changes both.

## The script today

`assets/main.js` is the presenter. It holds the number of the current slide, and it reads
the keys `j`, `k` and `p`. It shows a slide with the inline `style.display` property. It
has approximately 35 lines in one file. It has no `import` and no `export`.

`Expresso.Renderer` reads the file with `File.read!/1` at compile time. It writes the text
into one `script` element. The file is an `@external_resource` of the renderer. No build
step exists, and no test exists. `docs/development.md` gives a Playwright recipe that a
person runs by hand.

## Why now

`docs/overlays.md` gives the largest change that the script will get. The script must hold
a step index for each slide, read `data-max-step`, write `data-step`, and possibly apply
class names. That work makes the script three or four times larger, and it adds state that
a person can get wrong.

A conversion of 35 lines costs little. A conversion after the overlay work costs more, and
the overlay code then goes into the script without types and without tests. Therefore do
the conversion first.

## The design

### The source

Put the source in `assets/src/`, as a set of modules:

- `state.ts` — the state of the presenter and the function that changes it. The state is
  the number of the slide and the number of the step. The function takes a state, a key
  and the limits of the deck, and it returns a new state. It does not touch the document.
- `dom.ts` — the code that reads the document and writes to it. It reads the limits from
  the `section` elements, and it applies a state with `style.display` and, later, with
  `data-step`.
- `main.ts` — the entry. It reads the initial state, it adds the `keydown` listener, and
  it connects `state.ts` to `dom.ts`.

This split gives the state a unit test, and it keeps the document code thin. The overlay
code then goes into `state.ts` with a test for each rule of `docs/overlays.md`.

Use only the syntax that Node can erase. Do not use `enum`, `namespace` or a parameter
property. The option `erasableSyntaxOnly` in `tsconfig.json` makes the compiler refuse the
other syntax. Node runs a `.ts` file with such syntax directly, and the tests below need
this.

### The bundle

esbuild makes one script from the modules. It reads `main.ts`, it follows each `import`,
it strips the types, and it writes one file in the IIFE format with `--minify`. The
target is `ES2020`. `docs/overlays.md` commits to Chrome 85, Safari 16.4 and Firefox 128
for the `@property` at-rule, and each of these browsers runs ES2020. Chrome 85 does not
run each ES2022 construction.

The IIFE format gives a classic script with no module statement. Therefore the `script`
element of the renderer keeps its form, and the script runs at the same point in the
document as the script today. See the third decision for the alternative.

esbuild comes from the Hex package `esbuild`. The package downloads one binary, and Elixir
runs it. Therefore `mix compile` needs no Node. The package needs `runtime: false` and no
`only:` option, because the compile of a release also makes the bundle.

The bundle goes to `priv/static/presenter.js`. Git does not hold this file, so add it to
`.gitignore`. A minified file gives a diff that no person can read, and a build that is a
part of `mix compile` needs no copy in Git.

### The compile step

Add a Mix compiler, `Mix.Tasks.Compile.Presenter`, in `mix.exs`, and put it in front of
the Elixir compiler:

```elixir
compilers: [:presenter] ++ Mix.compilers()
```

The compiler runs esbuild when a file under `assets/src/` is newer than the bundle. The
order makes sure that the bundle exists before the Elixir compiler reads it.

### The renderer

`Expresso.Renderer` reads `priv/static/presenter.js` with `File.read!/1` at compile time,
as it reads `assets/main.js` today. Each file under `assets/src/` becomes an
`@external_resource` of the renderer, so a change to a source file starts a new compile of
the renderer. A `Path.wildcard/1` at compile time gives the list.

The `script` element does not change. The renderer writes the bundle with
`Phoenix.HTML.raw/1`, as it does today. Do not put the text `</script>` into a string in
the source. That text closes the element early. esbuild does not escape it.

### The type check

esbuild strips the types, and it does not check them. `tsc --noEmit` checks them. Add
`assets/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM"],
    "module": "esnext",
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "noEmit": true,
    "strict": true,
    "erasableSyntaxOnly": true,
    "types": ["node"]
  },
  "include": ["src", "test"]
}
```

Node needs the extension in an import, such as `import { next } from "./state.ts"`.
esbuild accepts this form. `tsc` accepts it with `allowImportingTsExtensions`, which needs
`noEmit`. The option `types` gives the test files the types of `node:test`.

### The tests

Node runs a `.ts` file directly, and it has a test runner. Put the tests in
`assets/test/`, and run them with `node --test assets/test/`. No other tool is necessary.

This works on Node 22.22, which the remote container has, and on Node 24, which
`.tool-versions` gives. A test of two cases ran on this container with no flag and with no
build step.

The tests cover `state.ts`. The Playwright recipe in `docs/development.md` covers `dom.ts`
and `main.ts`. Add one line to that recipe: make sure that `document.compatMode` is
`CSS1Compat`, so that the result comes from the standards mode.

### The tools

Add `package.json` at the root of the repository, with `typescript`, `@types/node` and
`prettier` as development dependencies, and with these scripts:

- `check` — `tsc -p assets`.
- `test` — `node --test "assets/test/**/*.test.ts"`. A directory as the argument does
  not work, and Node reports the directory as one failed test.
- `format` — `prettier --write assets`.

Pin each version, and commit `package-lock.json`. Add `node_modules/` to `.gitignore`.
esbuild is not in `package.json`, because the Hex package gives it.

Each environment gets Node from its own source, and the tools from `package.json`:

- The Nix shell gives Node 24. Run `npm install` in the shell. Remove `prettier` from
  `shell.nix`, so that one file gives the version.
- The remote container gives Node 22. Add `npm install` to
  `.claude/hooks/session-start.sh`. The container has a global `tsc` from the image of
  the harness. Do not use it. It is not a part of this repository.

`mix compile` needs Node in no environment. The type check and the tests need Node, and a
person runs them before a commit.

### The documents

- `CLAUDE.md` — add `npm run check` and `npm test` to the commands in "Build and test".
- `docs/development.md` — add a section for the script: the source, the bundle, the
  check, the tests and the `compatMode` line in the Playwright recipe.
- `docs/architecture.md` — in "The presenter", name `assets/src/` as the source and
  `priv/static/presenter.js` as the bundle. In "The render pipeline", add the compiler.
- `docs/overlays.md` — in "The JavaScript code", name `state.ts` for the rules and
  `dom.ts` for the attributes.

## Progress

Each step is done, on 2026-09-13. `assets/main.js` is not in the repository. Two facts
came from the work, and the plan above did not give them:

- The compiler `Mix.Tasks.Compile.Presenter` is in `mix.exs`, and not in `lib/`. Mix runs
  the compilers before it compiles `lib/`, so a compiler in `lib/` is not present when Mix
  needs it. Mix loads `mix.exs` first.
- Elixir compares the content of an `@external_resource`, and not its time. A `touch` of a
  source does not start a compile of the renderer. A content change does.

The bundle of the presenter today is 662 bytes. Chromium reports `CSS1Compat`, and the
keys `j`, `k` and `p` give the same result as the script before the conversion.

## The steps

Do the steps in this order. Each step leaves the repository in a state that compiles and
passes the checks.

1. Add the Hex package `esbuild` and its configuration. Run `mix esbuild.install`. Make
   sure that the download passes the proxy of the remote container. The hook downloads
   from the npm registry today, so the registry is reachable.
2. Add `package.json`, `assets/tsconfig.json` and the `.gitignore` lines. Run
   `npm install`. Commit the lockfile.
3. Write `state.ts` with the state of today: the slide number, and the keys `j` and `k`.
   Write its tests. Run `npm test`.
4. Write `dom.ts` and `main.ts`. Move the code of `main.js` into them. Remove `main.js`
   with `git rm`.
5. Add the Mix compiler and the `compilers` line. Run `mix compile`. Read the bundle.
   Make sure that it has no `import`, no `export` and no `</script>`.
6. Point the renderer at the bundle and at the sources. Run `mix compile` again. Make sure
   that a change to `state.ts` starts a new compile of the renderer.
7. Run the Playwright recipe. Make sure that `j`, `k` and `p` give the same result as
   before, and that `document.compatMode` is `CSS1Compat`.
8. Add `npm install` to the hook, and run the hook by hand. Remove `prettier` from
   `shell.nix`.
9. Update the four documents.
10. Run each command in "Build and test" of `CLAUDE.md`, `npm run check` and `npm test`.
    Commit.

## The decisions

The maintainer accepted each proposal below on 2026-09-13. The decisions are settled.
A later change needs a new decision, and this document then records it.

### 1. Where does the bundle step run?

There are two options:

1. **A Mix compiler with the Hex package `esbuild`.** `mix compile` makes the bundle, and
   it needs no Node. Git does not hold the bundle. This is the design above.
2. **An npm script, with the bundle in Git.** `npm run build` makes the bundle, and a
   person commits it. `mix compile` reads the file as today. A check compares the file
   with a new build.

The decision is option 1. A minified file in Git gives a diff that no person can read. A
stale file in Git is a defect that the check finds only when a person runs the check.
Option 1 gives one source of truth, and it costs one Hex package.

### 2. Does the renderer read the bundle at compile time or at run time?

At compile time, the renderer holds the bundle in a module attribute, as it does today.
At run time, the renderer reads `priv/static/presenter.js` with
`Application.app_dir/2` on each render.

The decision is compile time. It is the smallest change to the renderer. The binary that
Burrito makes then holds the script in the code, and not in a file. The run-time
option lets a person change the script without a new compile, and nobody needs that.

### 3. Does the script element get `type="module"`?

An inline module script runs after the document is complete, and it has its own scope.
The IIFE bundle has no module statement, so it runs in a classic `script` element as the
script does today.

The decision is the classic element. The behavior at run time is then equal to the
behavior today, and the conversion changes one thing at a time. Change the element when
a reason appears.

### 4. Is the order of the work correct?

The decision is to do this conversion before the overlay code. In `docs/architecture.md`,
this conversion is item 2 of "Open work", and the overlay code is item 3.
