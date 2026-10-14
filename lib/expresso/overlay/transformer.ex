defmodule Expresso.Overlay.Transformer do
  @moduledoc """
  The Spark transformer for overlays

  It runs one time for each deck module at compile time. It calls
  `Expresso.Overlay.Expand.slide/1` for each slide, and it writes the result
  into the DSL state. An error from the expansion becomes a
  `Spark.Error.DslError` with the path of the slide.
  """

  use Spark.Dsl.Transformer

  alias Expresso.Dsl
  alias Expresso.Overlay.Expand
  alias Spark.Dsl.Transformer

  @doc """
  Expand the specifications of each slide of the deck
  """
  @impl Transformer
  @spec transform(map()) :: {:ok, map()} | {:error, Spark.Error.DslError.t()}
  def transform(dsl_state) do
    with {:ok, slides} <- Dsl.map_slides(dsl_state, &Expand.slide/1),
         do: {:ok, Dsl.put_slides(dsl_state, slides)}
  end
end
