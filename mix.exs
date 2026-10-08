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
      dialyzer: [plt_core_path: "_build/#{Mix.env()}", plt_add_apps: [:mix]],
      docs: docs()
    ]
  end

  # The pages of `mix docs`. The groups follow Diataxis: a how-to guide gives
  # the steps of one task, a reference page describes each option, and an
  # explanation gives the design and its reasons. The GIFs of the guides come
  # from `mix expresso.gifs`, and the workflow publishes them to the branch
  # `media`. See `docs/development.md`.
  defp docs do
    [
      main: "readme",
      source_url: "https://github.com/rellen/expresso",
      homepage_url: "https://rellen.github.io/expresso/",
      # `docs/architecture.md` names this function of Mix, which has no
      # documentation. ExDoc then writes the name with no link.
      skip_code_autolink_to: ["Mix.Tasks.Help.run/1"],
      extras: [
        "README.md",
        "docs/how-to/add-transitions.md",
        "docs/how-to/animate-elements.md",
        "docs/how-to/make-a-deck-from-data.md",
        "docs/how-to/show-code.md",
        "docs/how-to/check-the-layout.md",
        "docs/how-to/style-one-slide.md",
        "docs/how-to/move-a-diagram-part.md",
        "docs/how-to/show-a-web-page.md",
        "docs/how-to/show-a-video.md",
        "docs/how-to/make-templates.md",
        "docs/how-to/use-colors-of-your-own.md",
        "docs/how-to/render-a-deck-in-your-project.md",
        "docs/how-to/put-files-into-the-css.md",
        "docs/how-to/give-a-deck-two-variants.md",
        "docs/reference/transition-option.md",
        "docs/reference/overlay-options.md",
        "docs/reference/step-labels.md",
        "docs/reference/css-option.md",
        "docs/reference/goto-option.md",
        "docs/reference/code-element.md",
        "docs/reference/layout-check.md",
        "docs/reference/class-option.md",
        "docs/reference/embed-element.md",
        "docs/reference/video-element.md",
        "docs/reference/template-option.md",
        "docs/reference/root-option.md",
        "docs/reference/theme-option.md",
        "docs/overlays.md",
        "docs/architecture.md",
        "docs/development.md",
        "docs/typescript.md",
        "docs/dim-state.md"
      ],
      groups_for_extras: [
        "How-to guides": ~r"docs/how-to/",
        Reference: ~r"docs/reference/",
        Explanation: ["docs/overlays.md", "docs/architecture.md"],
        Contributing: ["docs/development.md", "docs/typescript.md", "docs/dim-state.md"]
      ]
    ]
  end

  # `test/support` holds the generators of the property tests, and only the test
  # environment compiles them. `tools/` holds the recorder of the GIFs and its
  # encoder, a Zig NIF. The release does not need them, so only `dev` and `test`
  # compile them.
  defp elixirc_paths(:test), do: ["lib", "tools", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "tools"]
  defp elixirc_paths(_env), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      # `inets` gives `:httpd`, the web server of the watch mode.
      extra_applications: [:logger, :inets],
      mod: {Expresso.BurritoEntryPoint, []}
    ]
  end

  # Zigler writes the library of each NIF in `tools/` to `priv/lib`, and the
  # release copies `priv`. The binary does not use these libraries, so this step
  # removes them before Burrito wraps the release.
  defp drop_tool_libraries(release) do
    release.path
    |> Path.join("lib/expresso-*/priv/lib")
    |> Path.wildcard()
    |> Enum.each(&File.rm_rf!/1)

    release
  end

  def releases do
    [
      expresso_cli_app: [
        steps: [:assemble, &drop_tool_libraries/1, &Burrito.wrap/1],
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

      # results, lists, maps and keyword lists. Shoddy is not on Hex, so the lockfile
      # gives the commit of its main branch.
      {:shoddy, github: "rellen/shoddy", branch: "main"},

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

      # docs. Zigler depends on zig_doc, which asks for ExDoc 0.39.1 exactly.
      # zig_doc compiles with this version too, so the override keeps it, and
      # zig_doc needs ExDoc in each environment that compiles Zigler.
      {:ex_doc, "~> 0.40", only: [:dev, :test], runtime: false, override: true},

      # checks
      {:ex_check, "~> 0.16", only: :dev},

      # the formatter of the DSL. `Spark.Formatter` and `mix spark.formatter`
      # need it.
      {:sourceror, "~> 1.0", only: [:dev, :test], runtime: false},

      # property tests. The formatter and the static analysis run in `dev`, and
      # therefore the dependency is present in `dev` too.
      {:stream_data, "~> 1.2", only: [:dev, :test], runtime: false},

      # the browser tests of `mix test --only e2e` and the recorder of the GIFs
      # in `tools/`. The client drives the Playwright driver of `package.json`.
      {:playwright_ex, "~> 0.12", only: [:dev, :test]},

      # the GIF encoder of the recorder, a NIF in Zig. Zigler compiles it with
      # the Zig of the toolchain.
      {:zigler, "~> 0.16", only: [:dev, :test], runtime: false},

      # static analysis
      {:credo, ">= 0.0.0", only: :dev, runtime: false},
      {:doctor, ">= 0.0.0", only: :dev, runtime: false},
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
