defmodule Expresso.CssTransformer do
  @moduledoc """
  The Spark transformer that reads and scans the CSS of a deck one time

  The `css` option of the deck is a style sheet or the path of a file. Three
  verifiers need its names: `Expresso.Overlay.EffectVerifier` for the
  effects, `Expresso.TransitionVerifier` for the transitions and
  `Expresso.Overlay.PropertyVerifier` for the custom properties. This
  transformer resolves the option with `Expresso.Css.resolve/1` and scans
  it with `Expresso.Css.scan/1`, and it persists the result under
  `:css_names`. `Expresso.Dsl.css_names/1` reads it.

  The transformer gives no error for a file that it cannot read. It persists
  `{:error, message}`, and `Expresso.Overlay.EffectVerifier` reports the
  message, as before. It runs after `Expresso.PathTransformer`, which joins
  the path of the file to the `root` option of the deck.
  """

  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  @doc """
  Run after `Expresso.PathTransformer`, which gives the path of the file
  """
  @impl Transformer
  @spec after?(module()) :: boolean()
  def after?(Expresso.PathTransformer), do: true
  def after?(_transformer), do: false

  @doc """
  Persist the names of the CSS of the deck, or the error of its file
  """
  @impl Transformer
  @spec transform(map()) :: {:ok, map()}
  def transform(dsl_state) do
    names =
      dsl_state
      |> Transformer.get_option([:deck], :css)
      |> Expresso.Css.resolve()
      |> Shoddy.Result.map_ok(&Expresso.Css.scan/1)

    {:ok, Transformer.persist(dsl_state, :css_names, names)}
  end
end
