defmodule Expresso.Overlay.Transformer do
  @moduledoc """
  The Spark transformer for overlays

  It runs one time for each deck module at compile time. It calls
  `Expresso.Overlay.Expand.slide/1` for each slide, and it writes the result
  into the DSL state. An error from the expansion becomes a
  `Spark.Error.DslError` with the path of the slide.
  """

  use Spark.Dsl.Transformer

  alias Expresso.Overlay.Expand
  alias Shoddy.Result
  alias Spark.Dsl.Transformer

  @doc """
  Expand the specifications of each slide of the deck
  """
  @impl Transformer
  @spec transform(map()) :: {:ok, map()} | {:error, Spark.Error.DslError.t()}
  def transform(dsl_state) do
    module = Transformer.get_persisted(dsl_state, :module)

    dsl_state
    |> Transformer.get_entities([:deck])
    |> Stream.map(fn slide ->
      slide |> Expand.slide() |> Result.map_error(&dsl_error(module, slide, &1))
    end)
    |> Result.collect()
    |> Result.map_ok(&put_slides(dsl_state, &1))
  end

  defp put_slides(dsl_state, slides) do
    Map.replace_lazy(dsl_state, [:deck], &Map.put(&1, :entities, slides))
  end

  defp dsl_error(module, slide, message) do
    Spark.Error.DslError.exception(
      module: module,
      message: message,
      path: [:deck, :slide] ++ List.wrap(slide.name)
    )
  end
end
