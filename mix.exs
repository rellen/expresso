defmodule Expresso.MixProject do
  use Mix.Project

  def project do
    [
      app: :expresso,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases(),
      dialyzer: [plt_core_path: "_build/#{Mix.env()}", plt_add_apps: [:mix]]
    ]
  end

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
      # HTML
      {:earmark_parser, "~> 1.4"},
      {:floki, "~> 0.35"},
      {:phoenix_html, "~> 3.3"},
      {:temple, "~> 0.12"},

      # releasing
      {:burrito, "~> 1.0"},

      # docs
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},

      # checks
      {:ex_check, "~> 0.15", only: :dev},

      # static analysis
      {:credo, ">= 0.0.0", only: :dev, runtime: false},
      {:doctor, ">= 0.0.0", only: :dev, runtime: false},
      {:mix_audit, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:sobelow, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
