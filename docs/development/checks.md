# The checks

This page lists the checks of the project, and tells you what each check needs.

```sh
mix check                      # each tool below, Dialyzer, Doctor, ex_doc and unused_deps
mix compile --warnings-as-errors
mix format --check-formatted
mix credo                      # Credo and ExSlop, see "ExSlop" below
mix expresso.credence          # Credence, see "Credence" below
mix sobelow --exit --skip
mix hex.audit                  # the advisories and the retirements of the dependencies
mix test
mix test --only e2e            # the browser tests, see browser-tests.md
mix test --only dependency     # Expresso as a dependency, see release.md
mix test --only release        # the tests of the binary, see release.md
mix test --only graphviz --only d2 --only mermaid --only temml   # the graph tools and Temml, see graph-tools.md
npm run check                  # tsc, the type check of the presenter script
npm run lint                   # oxlint, see presenter-script.md
npm run format:check           # prettier --check
npm test                       # the tests of the presenter script
```

Each command above passes, and `mix check` passes as a whole. `mix doctor` passes with a
doc coverage, a spec coverage and a moduledoc coverage of 100 percent. Doctor reads the
source and not the compiled modules, so the functions that `use Spark.Dsl` and
`use Temple.Component` write do not count. Each public function that you write needs a
`@doc` and a `@spec`, and each struct needs a `@type t`.

Each result above comes from Erlang/OTP 29.1, Elixir 1.20.5 and Zig 0.16.0, which
`.tool-versions` gives. The Nix shell, a remote session and the workflow each give these
versions. Therefore a check that passes in a session also passes on your machine and in the
workflow.

`mix check` also runs the browser tests, the tests of the graph tools, the dependency test
and the release tests. The tests of the graph tools need Graphviz, D2 and Node, see
`graph-tools.md`. Before
the release tests,
it makes the binary for the target of the computer: `macos_arm`, `macos_x86`, `linux_x86`
or `linux_arm`. `.check.exs` finds the target. Therefore `mix check` needs Node, the
Chromium of Playwright, Zig, `xz` and `timeout`. It also runs the four `npm` commands, so it
needs `npm install` first. The hook runs `npm install` in a remote session.

The browser tests start after the unit tests. The dependency test and the release tests
start after the browser tests, and the release tests also need a release that succeeded. `.check.exs` gives `retry: false`, so each run
of `mix check` runs each tool. In the retry mode, a run after a failure runs only the
failed tools. A failed tool with a dependency that does not run is then skipped, and a
skipped tool does not fail the run.

## Credence

Credence finds code that works, but that is slower than necessary or that is not
idiomatic Elixir, such as `Enum.map/2` before `Enum.sum/1`. It is a dependency in `dev`
and in `test`. Credence has no task for a project, so `mix expresso.credence` in `tools/`
runs it:

```sh
mix expresso.credence                      # each file of lib/, tools/ and test/
mix expresso.credence lib/expresso/css.ex  # one file or one directory
```

The task writes each issue with its file, its line and its rule, and it fails when it finds
an issue. `mix check` and the job `lint` of the workflow run it. Change the code, and read
the message of the rule for the change that it expects.

- The task uses only the Pattern round of Credence, with `Credence.Pattern.analyze/2`.
  `Credence.analyze/1` also compiles each file to find the warnings of the compiler. It then
  defines each module again, and it runs the code that a module runs at the compile time,
  such as the build of a NIF.
- The task gives `assumptions: :strict`. Each rule then gives the same result as the code
  for each text. A deck can hold any Unicode text.
- Do not use `Credence.fix/1` on a file of Expresso. It compiles the file for the same
  check, and some of its fixes make the code less clear. For example, it changes
  `Enum.map/2` and `Enum.sum/1` into `Enum.reduce/3` with a capture that it calls at once,
  where `Enum.sum_by/2` is clearer.

## ExSlop

ExSlop is a plugin of Credo. It finds the patterns that a code generator writes too often,
such as a rescue of each exception, a comment that tells what the next line does, or
`Enum.map/2` before `Enum.join/2`. `mix credo` runs its checks, so `mix check` and the job
`lint` of the workflow also run them.

- `.credo.exs` gives `plugins: [{ExSlop, []}]`. The configuration has no list
  `checks.enabled`, so the plugin turns on its 28 recommended checks. Do not add that list,
  because Credo then ignores the checks of the plugin.
- The check `LengthComparison` finds a comparison of `length/1` with an integer, such as
  `length(list) > 1`. Use a list pattern, such as `match?([_, _ | _], list)`.
- `LengthComparison` does not read `test/`. An assert of a test compares a count, such as
  2000, that a list pattern cannot give.
- ExSlop is a dependency in `dev` only, like Credo, because it depends on Credo.

## Flaky tests

A flaky test passes in one run and fails in a different run of the same code. To find one,
run a suite again and again:

```sh
mix test --repeat-until-failure 30                # the unit tests, in one VM
mix test --only e2e --repeat-until-failure 20     # the browser tests, in one VM
for i in $(seq 30); do mix test || break; done    # the unit tests, in a new VM each time
```

A run without `--seed` gets a new seed, so each run has a new order of the tests and new
values for the property tests. The output of each run gives its seed, and
`mix test --seed <seed>` gives the same run again. Run two suites at the same time, so that
each suite gets the load of a run of `mix check`.

The tests of the presenter script run in a fixed order in each file. Each file
`assets/test/main_*.test.ts` loads `main.ts` one time, and each test uses the page of the
test before it. Therefore use `node --test --test-randomize` only for the other files.

The standard error is global. When an async test captures it with `capture_io(:stderr, ...)`,
ExUnit removes the name `:standard_error` for a moment. A write from a different test in that
moment raises `the device does not exist`. Therefore an async test must not write to the
standard error outside a capture. `test/test_helper.exs` sets the compiler option
`:ignore_module_conflict`, so a second compile of a module writes no warning.
