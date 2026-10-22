defmodule Expresso.Element.Diagram.Pele.Requirement do
  @moduledoc """
  The plan of a requirement diagram of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A requirement or an element | `fast` | `fast` |
  | A relationship | `bundle-fast-0` | `bundle->fast`, by its source and its destination |
  | A second relationship between the same ends in the same direction | `bundle-fast-3` | `bundle->fast:2` |

  Pele names the relationship at the index `n` from 0
  `<source>-<destination>-<n>`. The label of a relationship is its type, such
  as `satisfies`.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    edges =
      (model["relations"] || [])
      |> Enum.with_index()
      |> Enum.map(fn {relation, index} ->
        %{
          key: "#{relation["src"]}-#{relation["dst"]}-#{index}",
          from: relation["src"],
          to: relation["dst"],
          arrow: "->",
          label: relation["type"],
          name: nil
        }
      end)
      |> Plan.edges()

    fn data_id, classes -> part(data_id, classes, edges) end
  end

  defp part(data_id, classes, edges) do
    cond do
      "pele-edge" in classes and Map.has_key?(edges, data_id) -> edges[data_id]
      "pele-node" in classes -> {data_id, Plan.node()}
      true -> {edges |> Map.get(data_id, {data_id, []}) |> elem(0), []}
    end
  end
end
