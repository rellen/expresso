defmodule Expresso.Element.Diagram.Pele.Flowchart do
  @moduledoc """
  The plan of a flowchart of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A node | `web` | `web` |
  | A subgraph | `app` | `app` |
  | An edge | `L_web_api_0` | `web->api` |
  | A second edge between the same ends | `L_web_api_1` | `web->api:2` |
  | An edge with an id in the source, such as `web e1@--> api` | `e1` | `e1` |

  The ends of an edge and the members of a subgraph come from the model,
  because an id such as `L_web_ui_api_0` cannot give its ends safely. The
  arrow is `<->` for an edge with a head at each end, `--` for an edge with no
  head, and `->` for each other edge. The group of the label of an edge has
  the class `pele-edge-label`, so it takes the name of its edge and no marks.

  A swimlane diagram and an agent flow have the model of a flowchart, and a
  lane or a flow is a subgraph, so this plan names their parts too. Pele draws
  a collapsed flow of an agent flow as one node, with no group for its
  members, so an edge to a member has the flow as its end.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    parents =
      for subgraph <- model["subgraphs"] || [], child <- subgraph["nodes"] || [], into: %{} do
        {child, subgraph["id"]}
      end

    collapsed = collapsed(model["subgraphs"] || [])

    edges =
      for edge <- model["edges"] || [] do
        %{
          key: edge["id"],
          from: Map.get(collapsed, edge["start"], edge["start"]),
          to: Map.get(collapsed, edge["end"], edge["end"]),
          arrow: arrow(edge["type"]),
          label: edge["text"],
          name: if(edge["isUserDefinedId"], do: edge["id"])
        }
      end
      |> Plan.edges()

    fn data_id, classes -> part(data_id, classes, parents, edges) end
  end

  # The members of a collapsed flow of an agent flow have no group, so an
  # edge to a member goes to the flow.
  defp collapsed(subgraphs) do
    for %{"metadata" => %{"view" => "collapsed"}} = subgraph <- subgraphs,
        child <- subgraph["nodes"] || [],
        into: %{},
        do: {child, subgraph["id"]}
  end

  defp part(data_id, classes, parents, edges) do
    cond do
      "pele-edge" in classes and Map.has_key?(edges, data_id) -> edges[data_id]
      "pele-cluster" in classes -> {data_id, Plan.container(parents[data_id])}
      "pele-node" in classes -> {data_id, Plan.node(parents[data_id])}
      true -> {edges |> Map.get(data_id, {data_id, []}) |> elem(0), []}
    end
  end

  defp arrow("double_" <> _rest), do: "<->"
  defp arrow("arrow_open"), do: "--"
  defp arrow(_type), do: "->"
end
