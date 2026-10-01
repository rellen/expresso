defmodule Expresso.GotoVerifier do
  @moduledoc """
  The Spark verifier of the `goto` option

  It runs after the transformers, one time for each deck module at compile
  time. It calls `Expresso.Goto.check/2` for each element with a `goto`
  option, so a link to a slide or a step that the deck does not have stops the
  compile. The transformer writes the maximum step number of each slide first.
  """

  use Spark.Dsl.Verifier

  alias Expresso.Goto
  alias Shoddy.Result
  alias Spark.Dsl.Verifier

  @doc """
  Make sure that each link of the deck goes to a slide and a step of the deck
  """
  @impl Verifier
  @spec verify(map()) :: :ok | {:error, Spark.Error.DslError.t()}
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    slides = Verifier.get_entities(dsl_state, [:deck])
    targets = Goto.targets(slides)

    slides
    |> Stream.map(fn slide ->
      slide.elements
      |> List.wrap()
      |> links()
      |> first_error(targets)
      |> Result.map_error(&dsl_error(module, slide, &1))
    end)
    |> Result.collect()
    |> Result.ignore()
  end

  # Each link of a tree of elements.
  defp links(elements) do
    Enum.flat_map(elements, fn element ->
      List.wrap(Map.get(element, :goto)) ++ links(List.wrap(Map.get(element, :elements)))
    end)
  end

  defp first_error(links, targets) do
    links
    |> Stream.map(&Goto.check(&1, targets))
    |> Result.collect()
    |> Result.ignore()
  end

  defp dsl_error(module, slide, message) do
    Spark.Error.DslError.exception(
      module: module,
      message: message,
      path: [:deck, :slide] ++ List.wrap(slide.name)
    )
  end
end
