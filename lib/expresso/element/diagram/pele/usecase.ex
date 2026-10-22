defmodule Expresso.Element.Diagram.Pele.Usecase do
  @moduledoc """
  The plan of a use case diagram of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | An actor or a use case | `Talk` | `Talk` |
  | A system boundary | `Expresso` | `Expresso` |
  | A relationship | `edge-0` | `Presenter->Talk`, by its two ends |
  | A second relationship between the same ends in the same direction | `edge-4` | `Presenter->Talk:2` |
  | A relationship with an id in the source | `e1` | `e1` |

  The arrow of a relationship is `->` for `-->`, `<-` for `<--`, and `--` for
  `---` and `--`. A use case in a system boundary has the boundary as its
  parent.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  # The arrow of each `arrowType` of the model.
  @arrows %{0 => "->", 1 => "<-", 2 => "--"}

  @impl Plan
  def plan(model) do
    parents =
      for items <- [model["actors"], model["useCases"], model["systemBoundaries"]],
          {id, item} <- items || %{},
          into: %{},
          do: {id, item["parentId"]}

    parents =
      for {boundary, %{"members" => members}} <- model["systemBoundaries"] || %{},
          member <- members,
          reduce: parents,
          do: (parents -> Map.put(parents, member, boundary))

    edges =
      for relationship <- model["relationships"] || [] do
        %{
          key: relationship["id"],
          from: relationship["source"],
          to: relationship["target"],
          arrow: Map.get(@arrows, relationship["arrowType"], "->"),
          label: relationship["label"],
          name: if(relationship["explicitId"], do: relationship["id"])
        }
      end
      |> Plan.edges()

    fn data_id, classes -> part(data_id, classes, parents, edges) end
  end

  defp part(data_id, classes, parents, edges) do
    cond do
      "pele-edge" in classes and Map.has_key?(edges, data_id) -> edges[data_id]
      "pele-cluster" in classes -> {data_id, Plan.container(parents[data_id])}
      "pele-node" in classes -> {data_id, Plan.node(parents[data_id])}
      true -> {edges |> Map.get(data_id, {data_id, []}) |> elem(0), []}
    end
  end
end
