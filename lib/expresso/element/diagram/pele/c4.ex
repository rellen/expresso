defmodule Expresso.Element.Diagram.Pele.C4 do
  @moduledoc """
  The plan of a C4 diagram of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A person, a system, a container or a component | `web` | `web`, its alias |
  | A boundary or a deployment node | `shop` | `shop`, its alias |
  | A relationship | `customer-web` | `customer->web`, by its two ends |

  A shape in a boundary has the boundary as its parent. The arrow of a
  relationship is `->` for `Rel` and its variants of direction, such as
  `Rel_U`, `<-` for `Rel_Back`, and `<->` for `BiRel`. Mermaid keeps one
  relationship for two ends in the same order, so the last one of the source
  replaces the others.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    parents =
      for shape <- (model["shapes"] || []) ++ (model["boundaries"] || []),
          into: %{},
          do: {shape["alias"], parent(shape["parent"])}

    edges =
      for rel <- model["rels"] || [] do
        %{
          key: "#{rel["from"]}-#{rel["to"]}",
          from: rel["from"],
          to: rel["to"],
          arrow: arrow(rel["type"]),
          label: rel["label"],
          name: nil
        }
      end
      |> Plan.edges()

    fn data_id, classes -> part(data_id, classes, parents, edges) end
  end

  # The diagram itself is the boundary `global`, so a shape in it has no parent.
  defp parent(%{"alias" => "global"}), do: nil
  defp parent(%{"alias" => alias}), do: alias
  defp parent(_parent), do: nil

  defp arrow("birel"), do: "<->"
  defp arrow("rel_b"), do: "<-"
  defp arrow(_type), do: "->"

  defp part(data_id, classes, parents, edges) do
    cond do
      "pele-edge" in classes and Map.has_key?(edges, data_id) -> edges[data_id]
      "pele-cluster" in classes -> {data_id, Plan.container(parents[data_id])}
      "pele-node" in classes -> {data_id, Plan.node(parents[data_id])}
      true -> {edges |> Map.get(data_id, {data_id, []}) |> elem(0), []}
    end
  end
end
