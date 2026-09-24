defmodule Expresso.MixProject do
  use Mix.Project

  def project do
    [
      app: :expresso,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      compilers: [:presenter] ++ Mix.compilers(),
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      releases: releases(),
      dialyzer: [plt_core_path: "_build/#{Mix.env()}", plt_add_apps: [:mix]]
    ]
  end

  # `test/support` holds the generators of the property tests, and only the test
  # environment compiles them.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Expresso.BurritoEntryPoint, []}
    ]
  end

  def releases do
    [
      expresso_cli_app: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            macos_x86: [os: :darwin, cpu: :x86_64],
            macos_arm: [os: :darwin, cpu: :aarch64],
            linux_x86: [os: :linux, cpu: :x86_64],
            linux_arm: [os: :linux, cpu: :aarch64]
          ]
        ]
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # DSL
      {:spark, "~> 2.7"},

      # HTML
      {:floki, "~> 0.38"},
      {:phoenix_html, "~> 4.3"},
      {:temple, "~> 0.14"},

      # releasing
      {:burrito, "~> 1.6"},

      # the presenter bundle
      {:esbuild, "~> 0.10", runtime: false},

      # the highlighting of a code element. Each lexer package registers its
      # languages when its application starts.
      {:makeup, "~> 1.2"},
      {:makeup_elixir, "~> 1.0"},
      {:makeup_erlang, "~> 1.1"},
      {:makeup_gleam, "~> 1.0"},
      {:makeup_eex, "~> 2.0"},
      {:makeup_html, "~> 0.2"},
      {:makeup_css, "~> 0.2"},
      {:makeup_ts, "~> 0.2"},
      {:makeup_json, "~> 1.0"},
      {:makeup_sql, "~> 0.1"},
      {:makeup_c, "~> 0.1"},
      {:makeup_rust, "~> 0.3"},
      {:makeup_diff, "~> 0.1"},

      # docs
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},

      # checks
      {:ex_check, "~> 0.16", only: :dev},

      # the formatter of the DSL. `Spark.Formatter` and `mix spark.formatter`
      # need it.
      {:sourceror, "~> 1.0", only: [:dev, :test], runtime: false},

      # property tests. The formatter and the static analysis run in `dev`, and
      # therefore the dependency is present in `dev` too.
      {:stream_data, "~> 1.2", only: [:dev, :test], runtime: false},

      # the browser tests of `mix test --only e2e`. The client drives the
      # Playwright driver of `package.json`.
      {:playwright_ex, "~> 0.12", only: :test},

      # static analysis
      {:credo, ">= 0.0.0", only: :dev, runtime: false},
      {:doctor, ">= 0.0.0", only: :dev, runtime: false},
      {:mix_audit, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:sobelow, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end

defmodule Mix.Tasks.Compile.Presenter do
  @moduledoc """
  Make the presenter bundle with esbuild

  `mix.exs` puts this compiler in front of the Elixir compiler. esbuild reads
  `assets/src/main.ts`, it follows each import, and it writes one minified
  script to `priv/static/presenter.js`. `Expresso.Renderer` reads that file at
  compile time. The profile is in `config/config.exs`.

  This module is in `mix.exs` and not in `lib/`. Mix runs the compilers before
  it compiles `lib/`, so a compiler in `lib/` is not present when Mix needs it.
  Mix loads `mix.exs` first, so a module here is present.

  The compiler runs esbuild when a source is newer than the bundle, when the
  bundle is not present, or when the command has `--force`. `mix clean` removes
  the bundle. See `docs/typescript.md`.
  """

  use Mix.Task.Compiler

  @sources "assets/src/**/*.ts"
  @bundle "priv/static/presenter.js"

  @impl Mix.Task.Compiler
  def run(args) do
    if "--force" in args or Mix.Utils.stale?(Path.wildcard(@sources), [@bundle]) do
      bundle()
      {:ok, []}
    else
      {:noop, []}
    end
  end

  @impl Mix.Task.Compiler
  def clean do
    File.rm(@bundle)
    :ok
  end

  defp bundle do
    # The first run downloads the esbuild binary, and the download needs these
    # applications. `mix esbuild` starts them the same way.
    Mix.ensure_application!(:inets)
    Mix.ensure_application!(:ssl)
    Application.ensure_all_started(:esbuild)

    case Esbuild.install_and_run(:presenter, []) do
      0 -> :ok
      status -> Mix.raise("esbuild gave the exit status #{status}")
    end
  end
end
