defmodule Expresso.Element.Diagram.Pele.Block do
  @moduledoc """
  The plan of a block diagram of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A block | `server` | `server` |
  | A composite block | `store` | `store` |
  | An edge | `1-server-db` | `server->db`, by its two ends |
  | A second edge between the same ends in the same direction | `2-server-db` | `server->db:2` |

  The model gives each edge its ends and the type of the arrow at each end.
  The arrow of the name is `->` for a head at the end, `<-` for a head at the
  start, `<->` for a head at each end, and `--` for no head. A block in a
  composite block has the composite block as its parent.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  # The types of an arrow without a head.
  @open [nil, "", "arrow_open", "none"]

  @impl Plan
  def plan(model) do
    parents = parents(get_in(model, ["root", "children"]) || [], nil, %{})

    edges =
      for edge <- model["edges"] || [] do
        %{
          key: edge["id"],
          from: edge["start"],
          to: edge["end"],
          arrow: arrow(edge["arrowTypeStart"] not in @open, edge["arrowTypeEnd"] not in @open),
          label: edge["label"],
          name: nil
        }
      end
      |> Plan.edges()

    fn data_id, classes -> part(data_id, classes, parents, edges) end
  end

  defp parents(blocks, parent, acc) do
    Enum.reduce(blocks, acc, fn block, acc ->
      parents(block["children"] || [], block["id"], Map.put(acc, block["id"], parent))
    end)
  end

  defp arrow(true, true), do: "<->"
  defp arrow(true, false), do: "<-"
  defp arrow(false, true), do: "->"
  defp arrow(false, false), do: "--"

  defp part(data_id, classes, parents, edges) do
    cond do
      "pele-edge" in classes and Map.has_key?(edges, data_id) -> edges[data_id]
      "pele-cluster" in classes -> {data_id, Plan.container(parents[data_id])}
      "pele-node" in classes -> {data_id, Plan.node(parents[data_id])}
      true -> {edges |> Map.get(data_id, {data_id, []}) |> elem(0), []}
    end
  end
end
