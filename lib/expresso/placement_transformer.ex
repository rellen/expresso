defmodule Expresso.PlacementTransformer do
  @moduledoc """
  The Spark transformer of the places of the elements

  It runs one time for each deck module at compile time, before the other
  transformers. It calls `Expresso.Placement.slide/1` for each slide, and an
  error becomes a `Spark.Error.DslError` with the path of the slide.

  The check changes nothing. It is a transformer and not a verifier, because
  Spark raises an error from a transformer, and the compile stops. Spark runs
  a verifier in an `@after_verify` callback, and Elixir reports its error as a
  warning.
  """

  use Spark.Dsl.Transformer

  alias Expresso.Placement
  alias Shoddy.Result
  alias Spark.Dsl.Transformer

  @doc """
  Run this transformer before each other transformer
  """
  @impl Transformer
  @spec before?(module()) :: boolean()
  def before?(_transformer), do: true

  @doc """
  Check the place of each element of each slide of the deck
  """
  @impl Transformer
  @spec transform(map()) :: {:ok, map()} | {:error, Spark.Error.DslError.t()}
  def transform(dsl_state) do
    module = Transformer.get_persisted(dsl_state, :module)

    dsl_state
    |> Transformer.get_entities([:deck])
    |> Stream.map(fn slide ->
      slide |> Placement.slide() |> Result.map_error(&dsl_error(module, slide, &1))
    end)
    |> Result.collect()
    |> Result.ignore()
    |> case do
      :ok -> {:ok, dsl_state}
      error -> error
    end
  end

  defp dsl_error(module, slide, message) do
    Spark.Error.DslError.exception(
      module: module,
      message: message,
      path: [:deck, :slide] ++ List.wrap(slide.name)
    )
  end
end
