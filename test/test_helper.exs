# The browser tests of `test/e2e/` need Node, the Playwright driver and a
# browser. `mix test --only e2e` runs them. `docs/development.md` gives the setup.
ExUnit.start(exclude: [:e2e])
