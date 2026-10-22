defmodule Expresso.Element.Diagram.Pele.Eventmodeling do
  @moduledoc """
  The plan of an event model of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A lane | `Events` | `Events`, its label |
  | A box of a time frame | `02` | `02`, the id of its time frame |
  | A relation | `01-02` | `01->02`, by its source and its target |

  A box is a node with its lane as its parent, and a lane is a container. The
  name of a box is the id of its time frame, because two time frames can show
  the same entity, such as `AddItem`. A relation is an edge from its source to
  its target.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    parents = for box <- model["boxes"] || [], into: %{}, do: {box["id"], box["lane"]["label"]}

    edges =
      for relation <- model["relations"] || [] do
        {from, to} = {relation["source"]["id"], relation["target"]["id"]}
        %{key: "#{from}-#{to}", from: from, to: to, arrow: "->", label: nil, name: nil}
      end
      |> Plan.edges()

    fn data_id, classes -> part(data_id, classes, parents, edges) end
  end

  defp part(data_id, classes, parents, edges) do
    cond do
      "pele-edge" in classes -> edges[data_id] || {data_id, []}
      "pele-em-lane" in classes -> {data_id, Plan.container()}
      "pele-node" in classes -> {data_id, Plan.node(parents[data_id])}
      true -> {data_id, []}
    end
  end
end
