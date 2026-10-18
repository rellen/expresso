defmodule Expresso.GotoVerifier do
  @moduledoc """
  The check of the `goto` option

  `Expresso.VerifierTransformer` runs it after the other transformers, one
  time for each deck module at compile time. It calls `Expresso.Goto.check/2` for each element with a `goto`
  option, so a link to a slide or a step that the deck does not have stops the
  compile. The transformer writes the maximum step number of each slide first.
  """

  use Spark.Dsl.Verifier

  alias Expresso.Dsl
  alias Expresso.Element.Tree
  alias Expresso.Goto
  alias Shoddy.Result
  alias Spark.Dsl.Verifier

  @doc """
  Make sure that each link of the deck goes to a slide and a step of the deck
  """
  @impl Verifier
  @spec verify(map()) :: :ok | {:error, Spark.Error.DslError.t()}
  def verify(dsl_state) do
    targets = dsl_state |> Verifier.get_entities([:deck]) |> Goto.targets()

    dsl_state
    |> Dsl.map_slides(fn slide ->
      slide.elements
      |> Tree.descendants()
      |> Enum.flat_map(&List.wrap(Map.get(&1, :goto)))
      |> first_error(targets)
    end)
    |> Result.ignore()
  end

  defp first_error(links, targets) do
    links
    |> Stream.map(&Goto.check(&1, targets))
    |> Result.collect()
    |> Result.ignore()
  end
end
