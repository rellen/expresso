defmodule Expresso.Element.Diagram.Pele.Mindmap do
  @moduledoc """
  The plan of a mindmap of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A node | `Elements` | `Elements`, its id or its text |
  | The line from a node to a child | none | `root--Elements`, by the node and the child |

  Pele draws the lines with no `data-id`, in the order of a walk from the root
  that takes each node before its children. Therefore the plan names the
  line at the index `n` from 0 by the edge at that index in the same walk. A
  line has no direction, so its arrow is `--`.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    roots = Enum.filter(model["nodes"] || [], & &1["isRoot"])

    edges =
      roots
      |> Enum.flat_map(&lines/1)
      |> Enum.with_index()
      |> Enum.map(fn {{from, to}, index} ->
        %{key: "#{index}", from: from, to: to, arrow: "--", label: nil, name: nil}
      end)
      |> Plan.edges()

    fn
      nil, classes, count ->
        if "pele-edge" in classes, do: edges["#{count}"] || {nil, []}, else: {nil, []}

      data_id, classes, _count ->
        part(data_id, classes)
    end
  end

  defp lines(node) do
    Enum.flat_map(node["children"] || [], fn child ->
      [{node["nodeId"], child["nodeId"]} | lines(child)]
    end)
  end

  defp part(data_id, classes) do
    if "pele-node" in classes, do: {data_id, Plan.node()}, else: {data_id, []}
  end
end
