defmodule GifEncoder.MixProject do
  use Mix.Project

  def project do
    [
      app: :gif_encoder,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application, do: [extra_applications: [:logger]]

  defp deps do
    [
      {:rustler, "~> 0.38"},
      {:zigler, "~> 0.16", runtime: false},
      {:vix, "~> 0.42"}
    ]
  end
end
