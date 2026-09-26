# The browser tests of `test/e2e/` need Node, the Playwright driver and a
# browser. `mix test --only e2e` runs them. The tests of `test/release/` need the
# binary that Burrito makes. `mix test --only release` runs them.
# `docs/development.md` gives the setup of each.
ExUnit.start(exclude: [:e2e, :release])
