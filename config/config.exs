import Config

# The presenter bundle. `Mix.Tasks.Compile.Presenter` runs esbuild with this
# profile in front of the Elixir compiler. See docs/typescript.md.
config :esbuild,
  version: "0.28.2",
  presenter: [
    args:
      ~w(src/main.ts --bundle --format=iife --target=es2020 --minify --outfile=../priv/static/presenter.js),
    cd: Path.expand("../assets", __DIR__)
  ]

# The property tests. The generators of `Expresso.Test.CSS` make many forms, and
# therefore each property needs more than the default of 100 runs.
config :stream_data, max_runs: 500

# Zigler writes a debug message each time the GIF encoder of `tools/` loads, and
# the message comes in the output of `mix test`. The compiler removes it.
config :logger,
  compile_time_purge_matching: [[module: Expresso.Gif.Nif, level_lower_than: :info]]
