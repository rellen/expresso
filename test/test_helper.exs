# The browser tests of `test/e2e/` need Node, the Playwright driver and a
# browser. `mix test --only e2e` runs them. The tests of `test/release/` need the
# binary that Burrito makes. `mix test --only release` runs them. The test of
# `test/dependency/` makes a project that takes Expresso as a dependency, and it
# needs the network. `mix test --only dependency` runs it.
# `docs/development.md` gives the setup of each.
ExUnit.start(exclude: [:e2e, :release, :dependency])

# Some tests compile the same deck file more than one time, and
# `mix test --repeat-until-failure` compiles each module again. Elixir then
# writes a warning about the new definition to the global standard error. An
# async test that captures the standard error removes the name
# `:standard_error` for a moment, and a write in that moment raises. The option
# stops the warning, as it does in `Expresso.Watch` for each render.
Code.put_compiler_option(:ignore_module_conflict, true)
