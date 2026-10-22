# The checks

This page lists the checks of the project, and tells you what each check needs.

```sh
mix check                      # each tool below, Dialyzer, Doctor, ex_doc and unused_deps
mix compile --warnings-as-errors
mix format --check-formatted
mix credo
mix sobelow --exit --skip
mix hex.audit                  # the advisories and the retirements of the dependencies
mix test
mix test --only e2e            # the browser tests, see browser-tests.md
mix test --only dependency     # Expresso as a dependency, see release.md
mix test --only release        # the tests of the binary, see release.md
mix test --only graphviz --only d2 --only mermaid   # the graph tools, see graph-tools.md
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

Each result above comes from Erlang/OTP 29.1, Elixir 1.20.4 and Zig 0.16.0, which
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
