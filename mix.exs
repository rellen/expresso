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
      # MDEx has `runtime: false`, so it is not an application of Expresso.
      # The compiler then writes a warning for a call to it, and Dialyzer does
      # not know it. `Expresso.Notes` makes sure that MDEx is available.
      elixirc_options: [no_warn_undefined: [MDEx]],
      dialyzer: [plt_core_path: "_build/#{Mix.env()}", plt_add_apps: [:mix, :mdex]],
      docs: docs(),
      usage_rules: usage_rules()
    ]
  end

  # `mix usage_rules.sync` reads these settings. See
  # `docs/development/dependencies.md`.
  defp usage_rules do
    [
      file: "CLAUDE.md",
      usage_rules: [{~r/.*/, link: :markdown}]
    ]
  end

  # The groups of the pages come from Diataxis. See https://diataxis.fr. The
  # site contains only user documentation. `CONTRIBUTING.md` lists contributor
  # documents. The GIFs of the guides come from `mix expresso.gifs`, and the
  # workflow publishes them to the branch `media`. See
  # `docs/development/gifs.md`.
  defp docs do
    [
      main: "readme",
      source_url: "https://github.com/rellen/expresso",
      homepage_url: "https://rellen.github.io/expresso/",
      # `docs/architecture.md` names this function of Mix, which has no
      # documentation. This option tells ExDoc to write the name with no link.
      skip_code_autolink_to: ["Mix.Tasks.Help.run/1"],
      extras: [
        "README.md",
        "docs/tutorials/make-your-first-deck.md",
        "docs/how-to/present-a-deck.md",
        "docs/how-to/add-transitions.md",
        "docs/how-to/animate-elements.md",
        "docs/how-to/make-a-deck-from-data.md",
        "docs/how-to/show-data-in-a-chart.md",
        "docs/how-to/show-a-change-over-time-in-a-chart.md",
        "docs/how-to/show-parts-of-a-whole-in-a-treemap-or-a-sunburst.md",
        "docs/how-to/show-flows-between-nodes-in-a-chart.md",
        "docs/how-to/show-points-in-a-scatter-plot.md",
        "docs/how-to/show-how-a-total-changes-in-a-waterfall-chart.md",
        "docs/how-to/show-a-hierarchy-as-a-tree.md",
        "docs/how-to/animate-a-supervision-tree.md",
        "docs/how-to/draw-a-graph-from-graphviz-or-d2.md",
        "docs/how-to/draw-a-diagram-from-mermaid.md",
        "docs/how-to/show-code.md",
        "docs/how-to/check-the-layout.md",
        "docs/how-to/check-a-deck.md",
        "docs/how-to/export-a-deck.md",
        "docs/how-to/style-one-slide.md",
        "docs/how-to/move-a-diagram-part.md",
        "docs/how-to/explain-a-formula-step-by-step.md",
        "docs/how-to/show-the-steps-of-a-proof.md",
        "docs/how-to/point-at-a-part-of-a-slide.md",
        "docs/how-to/show-a-web-page.md",
        "docs/how-to/show-a-video.md",
        "docs/how-to/play-a-sound.md",
        "docs/how-to/share-the-slides-with-a-qr-code.md",
        "docs/how-to/put-a-deck-on-a-web-host.md",
        "docs/how-to/cite-your-sources.md",
        "docs/how-to/draw-attention-with-a-callout.md",
        "docs/how-to/show-the-plan-of-a-talk.md",
        "docs/how-to/show-a-key-number.md",
        "docs/how-to/add-icons-to-a-slide.md",
        "docs/how-to/move-elements-between-slides.md",
        "docs/how-to/keep-backup-slides.md",
        "docs/how-to/run-a-deck-by-time.md",
        "docs/how-to/rehearse-a-talk.md",
        "docs/how-to/write-notes-for-the-speaker.md",
        "docs/how-to/make-a-deck-accessible.md",
        "docs/how-to/make-templates.md",
        "docs/how-to/use-colors-of-your-own.md",
        "docs/how-to/render-a-deck-in-your-project.md",
        "docs/how-to/put-files-into-the-css.md",
        "docs/how-to/put-a-picture-behind-a-slide.md",
        "docs/how-to/give-a-deck-two-variants.md",
        "docs/reference/deck-options.md",
        "docs/reference/presenter.md",
        "docs/reference/transition-option.md",
        "docs/reference/placement.md",
        "docs/reference/accessibility.md",
        "docs/reference/lang-option.md",
        "docs/reference/dim-contrast-option.md",
        "docs/reference/dim-graphic-opacity-option.md",
        "docs/reference/external-option.md",
        "docs/reference/description-option.md",
        "docs/reference/link-preview-options.md",
        "docs/reference/slide-size.md",
        "docs/reference/morph-option.md",
        "docs/reference/overlay-options.md",
        "docs/reference/step-labels.md",
        "docs/reference/css-option.md",
        "docs/reference/background-option.md",
        "docs/reference/goto-option.md",
        "docs/reference/hidden-option.md",
        "docs/reference/advance-option.md",
        "docs/reference/text-box-element.md",
        "docs/reference/text-area-element.md",
        "docs/reference/image-element.md",
        "docs/reference/list-element.md",
        "docs/reference/table-element.md",
        "docs/reference/quotation-element.md",
        "docs/reference/spacer-element.md",
        "docs/reference/columns-element.md",
        "docs/reference/math-element.md",
        "docs/reference/diagram-element.md",
        "docs/reference/qr-code-element.md",
        "docs/reference/footnote-element.md",
        "docs/reference/note-element.md",
        "docs/reference/callout-element.md",
        "docs/reference/toc-element.md",
        "docs/reference/stat-element.md",
        "docs/reference/icon-element.md",
        "docs/reference/shape-element.md",
        "docs/reference/chart-element.md",
        "docs/reference/tree-element.md",
        "docs/reference/code-element.md",
        "docs/reference/window-option.md",
        "docs/reference/layout-check.md",
        "docs/reference/check-option.md",
        "docs/reference/export-options.md",
        "docs/reference/class-option.md",
        "docs/reference/embed-element.md",
        "docs/reference/video-element.md",
        "docs/reference/audio-element.md",
        "docs/reference/template-option.md",
        "docs/reference/root-option.md",
        "docs/reference/theme-option.md",
        "docs/overlays.md",
        "docs/architecture.md"
      ],
      groups_for_extras: [
        Tutorials: ~r"docs/tutorials/",
        "How-to guides": ~r"docs/how-to/",
        Reference: ~r"docs/reference/",
        Explanation: ["docs/overlays.md", "docs/architecture.md"]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "tools", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "tools"]
  defp elixirc_paths(_env), do: ["lib"]

  # Run `mix help compile.app` to read about applications.
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

  # `docs/development/dependencies.md` gives the purpose of each dependency.
  defp deps do
    [
      {:spark, "~> 2.7"},
      {:shoddy, github: "rellen/shoddy", branch: "main"},
      {:floki, "~> 0.38"},
      {:phoenix_html, "~> 4.3"},
      {:temple, "~> 0.14"},
      {:mdex, "~> 0.14", runtime: false},
      {:burrito, "~> 1.6"},
      {:esbuild, "~> 0.10", runtime: false},
      {:eqrcode, "~> 0.2"},
      {:makeup, "~> 1.2"},
      {:makeup_elixir, "~> 1.0"},
      {:makeup_erlang, "~> 1.1"},
      {:makeup_gleam, "~> 1.0"},
      {:makeup_eex, "~> 2.0"},
      {:makeup_html, "~> 1.0"},
      {:makeup_css, "~> 0.2"},
      {:makeup_ts, "~> 0.2"},
      {:makeup_json, "~> 1.0"},
      {:makeup_sql, "~> 0.1"},
      {:makeup_c, "~> 0.1"},
      {:makeup_rust, "~> 0.3"},
      {:makeup_diff, "~> 0.1"},
      {:ex_doc, "~> 0.40", only: [:dev, :test], runtime: false, override: true},
      {:ex_check, "~> 0.16", only: :dev},
      {:usage_rules, "~> 1.3", only: :dev, runtime: false},
      {:sourceror, "~> 1.0", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.2", only: [:dev, :test], runtime: false},
      {:lazy_html, "~> 0.1.13", only: :test},
      {:playwright_ex, "~> 0.12", optional: true},
      {:zigler, "~> 0.16", only: [:dev, :test], runtime: false},
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

  See `docs/development/presenter-script.md`.
  """

  use Mix.Task.Compiler

  @sources "assets/src/**/*.ts"
  @bundle "priv/static/presenter.js"
  @version "0.28.2"

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
    Mix.ensure_application!(:inets)
    Mix.ensure_application!(:ssl)
    Application.put_env(:esbuild, :version, @version)

    Application.put_env(:esbuild, :presenter,
      args:
        ~w(src/main.ts --bundle --format=iife --target=es2020 --minify --outfile=../priv/static/presenter.js),
      cd: Path.expand("assets", __DIR__)
    )

    Application.ensure_all_started(:esbuild)

    case Esbuild.install_and_run(:presenter, []) do
      0 -> :ok
      status -> Mix.raise("esbuild gave the exit status #{status}")
    end
  end
end
