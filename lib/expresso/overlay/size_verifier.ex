defmodule Expresso.Overlay.SizeVerifier do
  @moduledoc """
  The Spark verifier of the number of steps of each slide

  It runs after the transformers, one time for each deck module at compile
  time. It calls `Expresso.Overlay.Size.slide/1` for each slide, and it gives
  each result to the compiler as a warning.

  `Expresso.Overlay.PropertyVerifier` gives the warnings of a custom property.
  A verifier gives an error or a warning, and not both, so each kind of
  warning needs its own verifier.
  """

  use Spark.Dsl.Verifier

  alias Expresso.Overlay.Size
  alias Spark.Dsl.Verifier

  @doc """
  Give a warning for each slide of the deck with very many steps
  """
  @impl Verifier
  @spec verify(map()) :: :ok | {:warn, [Size.warning()]}
  def verify(dsl_state) do
    warnings =
      dsl_state
      |> Verifier.get_entities([:deck])
      |> Enum.flat_map(&Size.slide/1)

    if warnings == [], do: :ok, else: {:warn, warnings}
  end
end
