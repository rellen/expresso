defmodule Expresso.Element.Diagram.Pele.Cynefin do
  @moduledoc """
  The plan of a Cynefin diagram of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A domain, with its region and its label | `complex` | `complex` |
  | An item | `User research` | `User research`, its label |
  | A transition | `complex-complicated` | `complex->complicated`, by its two domains |

  A domain is a container, and each item in it has it as its parent. Pele
  draws the region of a domain as a `path`, so
  `Expresso.Element.Diagram.Pele.name/1` puts it into a group with its marks,
  and the label of the domain gets the same name. A transition is an edge
  from one domain to another, with its label.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    parents =
      for {domain, %{"items" => items}} <- model["domains"] || %{},
          item <- items,
          into: %{},
          do: {item["label"], domain}

    edges =
      for transition <- model["transitions"] || [] do
        {from, to} = {transition["from"], transition["to"]}

        %{
          key: "#{from}-#{to}",
          from: from,
          to: to,
          arrow: "->",
          label: transition["label"],
          name: nil
        }
      end
      |> Plan.edges()

    fn data_id, classes -> part(data_id, classes, parents, edges) end
  end

  defp part(data_id, classes, parents, edges) do
    cond do
      "pele-edge" in classes -> edges[data_id] || {data_id, []}
      "pele-cynefin-region" in classes -> {data_id, Plan.container()}
      "pele-node" in classes -> {data_id, Plan.node(parents[data_id])}
      true -> {data_id, []}
    end
  end
end
