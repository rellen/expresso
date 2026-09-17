defmodule Expresso.Overlay.PropertyVerifier do
  @moduledoc """
  The Spark verifier of the custom properties of the overlays

  It runs after the transformers, one time for each deck module at compile
  time. It calls `Expresso.Overlay.Properties.slide/1` for each slide, and it
  gives each result to the compiler as a warning.

  A warning is not an error. The deck compiles, and the renderer writes the
  property. Elixir reports the warning of a verifier as a compile warning, and
  `mix compile --warnings-as-errors` then fails for a deck module in `lib/`. A
  test collects the warning with `Spark.Test.dsl_warnings/1`.
  """

  use Spark.Dsl.Verifier

  alias Expresso.Overlay.Properties
  alias Spark.Dsl.Verifier

  @doc """
  Give a warning for each custom property of the deck that is a defect
  """
  @impl Verifier
  @spec verify(map()) :: :ok | {:warn, [Properties.warning()]}
  def verify(dsl_state) do
    warnings =
      dsl_state
      |> Verifier.get_entities([:deck])
      |> Enum.flat_map(&Properties.slide/1)

    if warnings == [], do: :ok, else: {:warn, warnings}
  end
end
