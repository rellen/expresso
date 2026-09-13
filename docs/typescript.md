# TypeScript for the presenter script

This document gives a plan for a conversion of `assets/main.js` to TypeScript. The code
does not contain this conversion yet. The document ends with four open decisions.

## The script today

`assets/main.js` is the presenter. It holds the number of the current slide, it reads the
keys `j`, `k` and `p`, and it shows a slide with the inline `style.display` property. It
has approximately 35 lines.

The script is a classic script, and it is not a module. It has no `import` and no
`export`. `Expresso.Renderer` reads the file with `File.read!/1` at compile time, and it
writes the text into one `script` element. The file is an `@external_resource` of the
renderer, so a change to the file starts a new compile.

No build step exists for the file. Prettier formats it, and the Nix shell gives Prettier.
No test exists for the file. `docs/development.md` gives a recipe with Playwright, and a
person runs that recipe by hand.

## Why now

`docs/overlays.md` gives the largest change that the script will get. The script must
hold a step index for each slide, read `data-max-step`, write `data-step`, and possibly
apply class names. That work makes the script three or four times larger, and it adds
state that a person can get wrong.

A conversion of 35 lines costs little. A conversion after the overlay work costs more,
and the overlay work then goes into the script without types. Therefore do the conversion
first, and write the overlay code in TypeScript from the start.

## The parts of the conversion

### The source file

Move `assets/main.js` to `assets/main.ts` with `git mv`, so that Git keeps the history.
Then add the types. The surface is small:

- `document.getElementById/1` returns `HTMLElement | null`. The script assumes an
  element each time. With `strict`, the compiler refuses this assumption. Add one function
  that reads a slide by its number and raises an error when the element is not present. A
  missing slide is a defect of the renderer, and a loud error is correct.
- `e.key` is a `string`. The listener gets a `KeyboardEvent`.
- `document.getElementsByClassName/1` returns an `HTMLCollectionOf<Element>`.

Keep the file a classic script. Do not add an `import` or an `export`. The renderer writes
the text into a `script` element without `type="module"`, and a module statement gives a
syntax error in that element. See the open decisions for the point at which this rule
changes.

Do not put the text `</script>` into a string in the script. The renderer writes the text
with `Phoenix.HTML.raw/1`, and that text closes the element early.

### The configuration

Add `assets/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM"],
    "strict": true,
    "noEmitOnError": true,
    "outDir": "."
  },
  "files": ["main.ts"]
}
```

`ES2020` is the correct target. `docs/overlays.md` commits to Chrome 85, Safari 16.4 and
Firefox 128 for the `@property` at-rule. Each of these browsers runs ES2020. Chrome 85
does not run each ES2022 construction, so `ES2022` is not safe.

`noEmitOnError` makes sure that a type error does not write a new `main.js`. Without it,
`tsc` writes the file and then reports the error, and the renderer packages the file.

### The tools

Add `package.json` at the root of the repository:

```json
{
  "private": true,
  "scripts": {
    "build": "tsc -p assets",
    "check": "tsc -p assets && git diff --exit-code assets/main.js",
    "format": "prettier --write assets"
  },
  "devDependencies": {
    "prettier": "<the version that npm resolves>",
    "typescript": "<the version that npm resolves>"
  }
}
```

Pin each version. Record the versions in this document when you add them. Add
`node_modules/` to `.gitignore`.

The `check` script does two operations. `tsc` type-checks and writes `main.js`, and
`noEmitOnError` stops the write on a type error. Then `git diff` makes sure that the
`main.js` in Git is the output of the `main.ts` in Git. See the open decisions for the
reason that this second operation exists.

Each environment gets the tools from `package.json`:

- The Nix shell gives Node 24. Run `npm install` in the shell. Do not add TypeScript to
  `shell.nix`, because two sources for one tool give two versions.
- The remote container gives Node 22, and it has a global `tsc` 6.0.2 from the image of
  the harness. Do not use the global `tsc`. It is not a part of this repository, and a
  later image can change it. Add `npm install` to `.claude/hooks/session-start.sh`.

Prettier formats a `.ts` file with no configuration. The repository has no
`.prettierrc`, and the defaults are sufficient.

### The renderer

`Expresso.Renderer` continues to read `assets/main.js`. The `@external_resource`
attribute continues to name that file. No change to Elixir code is necessary in the first
version.

### The documents

- `CLAUDE.md` — add `npm run check` to the commands in "Build and test".
- `docs/development.md` — add a section that tells you how to build the script and how
  the check operates.
- `docs/architecture.md` — in "The presenter", name `assets/main.ts` as the source and
  `assets/main.js` as the output.
- `docs/overlays.md` — in "The JavaScript code", name `assets/main.ts`.

## The steps

Do the steps in this order. Each step leaves the repository in a state that compiles and
passes the checks.

1. Add `package.json`, `assets/tsconfig.json` and the `.gitignore` line. Run
   `npm install`. Commit the lockfile `package-lock.json`.
2. Move `assets/main.js` to `assets/main.ts` with `git mv`. Add the types. Add the
   function that reads a slide by number.
3. Run `npm run build`. Read the output `assets/main.js`. Make sure that the file has no
   `import`, no `export` and no `</script>`.
4. Run `mix compile`. Make sure that the compiler rebuilds `Expresso.Renderer`, because
   `main.js` changed.
5. Run the Playwright recipe in `docs/development.md`. Make sure that `j`, `k` and `p`
   give the same result as before. Also make sure that `document.compatMode` is
   `CSS1Compat`, so that the result comes from the standards mode.
6. Add `npm install` to the hook, and run the hook by hand.
7. Update the four documents.
8. Run each command in "Build and test" of `CLAUDE.md`, and `npm run check`. Commit.

## The test plan

The first version has no unit test for the script. A classic script cannot export a
function, so a test file cannot import one. The Playwright recipe is the test, and step 5
runs it.

A unit test becomes possible with the second open decision. When the script becomes a
set of modules, put the state of the presenter in a pure function, such as
`next(state, key, limits)`. Test that function with `node --test`. Node 22 and Node 24
run a `.ts` file with the flag `--experimental-strip-types`, so the test needs no other
tool.

## The open decisions

### 1. Where does the output `main.js` live?

There are three options:

1. **Commit the output.** `main.ts` and `main.js` are both in Git. `mix compile` reads
   `main.js` as it does now, and it needs no Node. The `check` script catches a stale
   `main.js`.
2. **Write the output at compile time.** A Mix alias runs `tsc` before `compile.elixir`.
   `main.js` is not in Git. `mix compile` then needs Node and TypeScript in each
   environment: the Nix shell, the remote container and the Burrito release. The
   `@external_resource` attribute then names a file that Git does not hold.
3. **Use the `esbuild` package from Hex.** It downloads a binary, and Elixir runs it with
   no Node. It strips the types, and it does not check them. A type check still needs
   `tsc` and Node in development.

The proposal is option 1 now. The repository has no continuous integration, and the
maintainer runs each gate by hand. The `check` script is one more such gate. Option 1
keeps `mix compile` free of Node, which keeps the release simple. Option 2 gives one
source of truth, but it costs a tool in three environments for one file of 35 lines.

Move to option 3 when the script becomes a set of modules. At that point a bundle is
necessary, and `esbuild` makes one classic script from the modules.

### 2. When does the script become a set of modules?

A classic script cannot export, so it cannot have a unit test. A set of modules can, but
it needs a bundle step, which is option 3 above.

The proposal is to keep one classic script until the overlay work lands. Then split the
state of the presenter from the code that touches the document, add `esbuild`, and add
the unit tests. The overlay work is the point at which the logic becomes worth a test.

### 3. Does this conversion come before or after the overlay code?

The proposal is before. See "Why now". In `docs/architecture.md`, this conversion is
item 2 of "Open work", and the overlay code is item 3. Move the items if you decide the
other order.

### 4. Where do the tools come from?

The proposal is `package.json` and `npm install`, in each environment. The alternative is
`shell.nix` for the Nix shell and the hook for the container. Two sources give two
versions, and a difference between them is not visible until a build differs. One
`package.json` with pinned versions gives one answer.
