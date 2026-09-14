defmodule Expresso.Overlay.Verifier do
  @moduledoc """
  The Spark verifier for overlays

  It runs after the transformers, one time for each deck module at compile
  time. It calls `Expresso.Overlay.Check.slide/1` for each slide. An error from
  the check becomes a `Spark.Error.DslError` with the path of the slide.
  """

  use Spark.Dsl.Verifier

  alias Expresso.Overlay.Check
  alias Spark.Dsl.Verifier

  @doc """
  Check the steps of each slide of the deck
  """
  @impl Verifier
  @spec verify(map()) :: :ok | {:error, Spark.Error.DslError.t()}
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    dsl_state
    |> Verifier.get_entities([:deck])
    |> Enum.reduce_while(:ok, fn slide, :ok ->
      case Check.slide(slide) do
        :ok -> {:cont, :ok}
        {:error, message} -> {:halt, {:error, dsl_error(module, slide, message)}}
      end
    end)
  end

  defp dsl_error(module, slide, message) do
    Spark.Error.DslError.exception(
      module: module,
      message: message,
      path: [:deck, :slide] ++ List.wrap(slide.name)
    )
  end
end
