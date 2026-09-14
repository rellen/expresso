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
    |> Enum.reduce_while({:ok, []}, fn slide, {:ok, slides} ->
      case Expand.slide(slide) do
        {:ok, slide} -> {:cont, {:ok, [slide | slides]}}
        {:error, message} -> {:halt, {:error, dsl_error(module, slide, message)}}
      end
    end)
    |> case do
      {:ok, slides} -> {:ok, put_slides(dsl_state, Enum.reverse(slides))}
      {:error, error} -> {:error, error}
    end
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
