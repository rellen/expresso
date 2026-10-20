# The presenter script

This page tells you how to build and test the presenter script in TypeScript, and how to
run its type check and its lint.

`docs/typescript.md` gives the design. The parts are:

- `assets/src/program.ts` — reads the program of the presenter that the renderer writes.
  It examines no value.
- `assets/src/schema.ts` — the type and the decoder of each value that Elixir writes for
  the script, and the constants of the script, such as `ELEMENT_KINDS`.
  `Expresso.Test.SchemaWriter` writes it. Do not change it by hand. "The schema of the
  presenter" below tells how to write it again.
- `assets/src/decode.ts` — the functions that make the decoders of `schema.ts`.
- `assets/src/interpreter.ts` — runs the program for each key, click and swipe.
- `assets/src/state.ts` — the state of the presenter, the messages between the windows,
  the side of a click and the direction of a swipe.
- `assets/src/dom.ts` — the code that reads the document and writes to it.
- `assets/src/main.ts` — the entry, which esbuild bundles.
- `assets/src/layout.ts` — the layout check of `?check` in the address.
- `assets/src/check.ts` — axe-core for `?check=a11y`, and the result for
  `mix expresso --check`.
- `assets/src/deck.ts` — the list of the steps of the deck.
- `assets/src/speaker.ts` — the texts of the speaker view.
- `assets/src/search.ts` — the search of the list of keys.
- `assets/src/scheme.ts` — the variant of a theme with a light and a dark variant.
- `assets/src/morph.ts` — the morph between two slides.
- `assets/src/chart.ts` — the numbers that count, of a chart and of a stat.
- `assets/src/media.ts`, `assets/src/video.ts` and `assets/src/audio.ts` — the media of the
  video element and of the audio element.
- `assets/src/embed.ts` — the frames of the embed element.
- `assets/src/assets.ts` — copies each large file back into the elements that
  `Expresso.Assets` gave a reference.
- `assets/test/interpreter.test.ts` — the test that runs the fixtures of the Elixir
  interpreter. "The fixtures of the interpreter" below tells how to write them again.
- `assets/test/validate.ts` — examines a program of the presenter and a list of the
  steps with the decoders of `schema.ts`. `assets/test/program.test.ts` and
  `assets/test/deck.test.ts` run it on each program and each list of the fixture file.
- `assets/test/state.test.ts` — the example tests of the state.
- `assets/test/state_property.test.ts` and `assets/test/speaker_property.test.ts` — the
  property tests of the state and of the speaker view texts.
- `assets/test/property.ts` — `RUNS`, the number of runs of each property.
- `assets/test/nth.ts` — the item at an index, for the tests.
- `assets/tsconfig.json` — the options of the type check.
- `.oxlintrc.json` — the rules of the lint.
- `package.json` — the tools, with a pinned version of each.
- `Mix.Tasks.Compile.Presenter` in `mix.exs` — the compiler that makes the bundle, with the esbuild version and profile.

`mix compile` makes `priv/static/presenter.js` with esbuild, in front of the Elixir
compiler. The first `mix compile` downloads the esbuild binary from the npm registry, and
the download passes the proxy of the remote container. Git does not hold the bundle. A
source newer than the bundle makes a new bundle and a new compile of `Expresso.Renderer`.
A project that takes Expresso from GitHub makes the bundle in the same way when it compiles
the dependency. The compiler gives esbuild its version and profile, because a dependency
does not load `config/config.exs`.

The commands are:

```sh
npm install            # the hook runs this command in a remote session
npm run check          # tsc, the type check
npm run lint           # oxlint with the type-aware rules
npm run format:check   # prettier --check, which changes no file
npm run format         # prettier --write, which formats each file
npm test               # node --test, which runs a .ts file directly
```

`mix check` runs each of these commands except `npm run format`.

`fast-check` gives the property tests. It is a development dependency, and the bundle does
not import it. [Property tests](unit-tests.md#property-tests) tells how `stream_data` does the same for the Elixir
code. Each property of the presenter script gets `RUNS`, which is 500, as
`config/config.exs` gives each property of `stream_data`. The generators make many forms,
such as a state after 0 to 60 keys, clicks and messages, and 100 runs do not reach enough of
them.

When a property fails, `fast-check` gives a `seed` and a `path`. Give both to `fc.assert`
as parameters to get the same value again.

Node runs the test files with no build step. Node 24 reads a `.ts` file
directly when the file uses only erasable syntax, and `erasableSyntaxOnly` in
`tsconfig.json` makes the compiler refuse other syntax.

`assets/tsconfig.json` has more options than the plan of `docs/typescript.md` gives.
`isolatedModules` and `verbatimModuleSyntax` refuse syntax that esbuild cannot compile one
file at a time. These options refuse code that is unused, unreachable or incomplete:

- `noImplicitReturns`
- `noFallthroughCasesInSwitch`
- `noUnusedLocals`
- `noUnusedParameters`
- `allowUnreachableCode: false`
- `allowUnusedLabels: false`

`noUncheckedIndexedAccess` gives each index access the type `T | undefined`. A test uses
`nth` of `assets/test/nth.ts`, which stops the test for a missing item.
`exactOptionalPropertyTypes` refuses `undefined` for an optional property. The options do
not change the bundle.

## The lint and the format of the script

Three tools check the presenter script, and each has one job:

| Tool | Command | Its job |
| --- | --- | --- |
| `tsc` of TypeScript 7 | `npm run check` | The types, and the options of `assets/tsconfig.json`. |
| `oxlint` with `oxlint-tsgolint` | `npm run lint` | Defects that the types allow, such as a promise that nothing handles. |
| Prettier | `npm run format:check` | The layout of `assets/`. `.prettierignore` names the files of a generator. |

`.oxlintrc.json` turns on the category `correctness` and these rules, which need the
types:

- `typescript/no-floating-promises` — each promise is awaited, ends with `.catch`, or has
  `void`. A call of `test` or `describe` of `node:test` returns a promise that Node
  handles, so the rule allows it.
- `typescript/no-misused-promises` — a promise does not go where a value or a function
  with no promise goes, such as the condition of an `if`.
- `typescript/await-thenable` — `await` gets a promise.

To fix a finding of `no-floating-promises`, give the promise a `.catch` that handles the
error. A promise whose error is not important gets `void`, with a comment that tells why.
`main.ts` writes an error of the layout check to the console, as the check writes each
problem.

These are the reasons for the choice of the tools:

- **oxlint, and not ESLint.** The rules that need the types come from `tsgolint`, which
  is built on TypeScript 7.0.2, the version of `package.json`. `typescript-eslint` does not
  support TypeScript 7, because TypeScript 7.0 has no programmatic API. The version of
  `oxlint-tsgolint` follows the version of TypeScript: 7.0.2003 is the fourth release for
  TypeScript 7.0.2. Change the two versions together.
- **Few rules.** The category `suspicious` reported each type assertion of the document,
  such as the result of `querySelector`, and `strict` with the other options of
  `tsconfig.json` already refuses most of the defects of the other categories. A rule
  that reports correct code teaches you to ignore the lint. Add a rule when it finds a
  real defect in this code.
- **Prettier, and not oxfmt.** oxfmt, the formatter of the same project as oxlint, is
  approximately 30 times faster. On 2026-10-10 it was at version 0.72, and with a width of
  80 it changed the layout of 3 files. Prettier takes approximately one second for
  `assets/`. Look at oxfmt again after its version 1.0.

## The schema of the presenter

`Expresso.Presenter.Schema` describes the JSON form of each value that Elixir writes for
the script: the program, the list of the steps, the commands of an element, and the
message between the two windows. It is the one source of these forms:

- `Expresso.Presenter.Verifier` reads the fields of the state, the built-in functions and
  the kind of each value from it.
- `Expresso.Test.SchemaWriter` writes `assets/src/schema.ts`. That file holds a
  TypeScript type, a decoder, and for a form of strings a constant, for each form. After
  the forms, it holds each constant of `Expresso.Presenter.Schema.constants/0`, such as
  `ELEMENT_KINDS`. The modules of the script import their types from it, and `tsc` makes
  sure that each decoder agrees with its type.
- A record form, such as `written_entry`, names the value at each place of an array.
  `Expresso.Presenter.Schema.Record.write/2` writes the array in that order, and the
  converter of `schema.ts`, such as `fromWrittenEntry`, reads it in the same order. The
  tests of the script write an array with the converter back, such as `toWrittenEntry`.
- `Expresso.Presenter.Schema.Check` examines a decoded JSON value with the same forms. The
  verifier uses it for the values of a definition. The property tests of
  `test/expresso/presenter/schema_test.exs` make random decks, and they make sure that
  each program and each list of the steps agrees with its form.

The test `assets/src/schema.ts agrees with the forms of the schema` fails when the file
does not agree with the schema. After a change to a form or to a constant, such as a new
row of `Expresso.Element.kinds/0`, do these steps:

1. Write the file again:

   ```sh
   EXPRESSO_SCHEMA=write mix test test/expresso/presenter/schema_test.exs
   ```

2. Run `npm run check` and `npm test`.
3. Commit `assets/src/schema.ts` with the change.

The script trusts the program and the list, so the bundle does not decode them. The bundle
decodes only the message from the other window, because another page or an extension of
the browser can send any value. Each call in `schema.ts` has the annotation `@__PURE__`,
so esbuild removes each decoder that the script does not use. Prettier does not format the
file, and `.prettierignore` names it.

## The fixtures of the interpreter

The TypeScript interpreter must return the result of the Elixir interpreter for each
event. Node cannot run Elixir, so Git holds the results of the Elixir interpreter in
`assets/test/fixtures/presenter.json`. `interpreter.test.ts` runs the same events, and it
compares each result. The tests of `main.ts` also read the programs and the lists of keys
from this file.

`Expresso.Test.PresenterFixtures` makes the file. Its test in
`test/expresso/presenter/fixtures_test.exs` fails when the file does not agree with the
text that `json/0` returns. After a change to `Expresso.Presenter.Default` or to an
interpreter, do these steps:

1. Write the file again:

   ```sh
   EXPRESSO_FIXTURES=write mix test test/expresso/presenter/fixtures_test.exs
   ```

2. Run `npm test`.
3. Commit the file with the change.

Prettier does not format the file, because `.prettierignore` holds its directory. The file
has one line for each deck and for each case, so a diff shows each changed case.

A call of a DSL has no parentheses. Expresso has two DSLs: the deck DSL of
`Expresso.Extension` and the presenter DSL of `Expresso.Presenter.Extension`.
`.formatter.exs` holds the list `spark_locals_without_parens`, and `mix format` then adds
no parentheses. After a change to an entity or an option of a DSL, run this command to make
the list again:

```sh
mix spark.formatter --extensions Expresso.Extension,Expresso.Presenter.Extension
```

The task needs the `sourceror` package, which is a development dependency. The formatter removes no parentheses, so write a new call without them.

Sobelow gives a warning for `Phoenix.HTML.raw/1`. When the input is safe, put a
`# sobelow_skip` comment above the function, with the reason in a comment above it.
`Expresso.Renderer.render/1` and `Expresso.Element.Diagram.render/1` show this pattern.

Prettier formats the files in `assets/`. `package.json` pins the version, and
`npm install` gives the command. Run `npm run format`, which is not one of the checks.

## The fixture of the number formats

`format` and `formatStat` in `assets/src/chart.ts` write the number of a count at each
frame. They copy `Expresso.Element.Chart.Plot.label/1` and
`Expresso.Element.Stat.format/3`, so Git holds numbers and their texts from Elixir in
`assets/test/fixtures/numbers.json`. `assets/test/chart.test.ts` compares the two functions
with the file.

`Expresso.Test.NumberFixtures` makes the file, and `test/expresso/number_fixtures_test.exs`
fails when the file does not agree with it. After a change to a format in Elixir, do these
steps:

1. Write the file again:

   ```sh
   EXPRESSO_FIXTURES=write mix test test/expresso/number_fixtures_test.exs
   ```

2. Run `npm test`, and change the function of the script until the test passes.
3. Commit the file with the change.

## The tables of keys

`docs/reference/presenter.md` holds a table of keys for each mode, and `Expresso.Test.KeyTables` makes each
table from `Expresso.Presenter.Default`. Its test in
`test/expresso/presenter/key_tables_test.exs` fails when a table does not agree with the
module. After a change to a binding, write the tables again, and commit the page with the
change:

```sh
EXPRESSO_KEYS=write mix test test/expresso/presenter/key_tables_test.exs
```

Do not change the text between `<!-- keys present -->` and `<!-- /keys -->` by hand. Put
a rule that a table does not give in the text after the table.
