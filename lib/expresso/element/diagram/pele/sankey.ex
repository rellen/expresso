defmodule Expresso.Element.Diagram.Pele.Sankey do
  @moduledoc """
  The plan of a sankey diagram of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A node, with its label | `Revenue` | `Revenue` |
  | A link | `Sales->Revenue` | `Sales->Revenue`, by its source and its target |

  A link is an edge from its source to its target, with its value as its
  label. Pele draws a node as a `rect` and a link as a `path`, so
  `Expresso.Element.Diagram.Pele.name/1` puts each into a group with its
  marks.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    edges =
      for link <- model["links"] || [] do
        {from, to} = {link["source"]["id"], link["target"]["id"]}

        %{
          key: "#{from}->#{to}",
          from: from,
          to: to,
          arrow: "->",
          label: to_string(link["value"]),
          name: nil
        }
      end
      |> Plan.edges()

    fn data_id, classes ->
      cond do
        "pele-sankey-link" in classes -> edges[data_id] || {data_id, []}
        "pele-sankey-node" in classes -> {data_id, Plan.node()}
        true -> {data_id, []}
      end
    end
  end
end
