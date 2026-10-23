defmodule Expresso.Element.Diagram.Pele.Wardley do
  @moduledoc """
  The plan of a Wardley map of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | An anchor or a component, with the arrow of its evolution | `Renderer` | `Renderer` |
  | A link | `Deck-Renderer` | `Deck->Renderer`, by its source and its target |

  A link is an edge from its source to its target. Pele gives the arrow of
  the evolution of a component, from `evolve Renderer 0.70`, the name of the
  component as its `data-id`, so a part of a component shows its evolution
  too. The frame, the stages and the notes show at each step.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    edges =
      for link <- model["links"] || [] do
        {from, to} = {link["source"], link["target"]}
        %{key: "#{from}-#{to}", from: from, to: to, arrow: "->", label: nil, name: nil}
      end
      |> Plan.edges()

    fn data_id, classes ->
      cond do
        "pele-edge" in classes -> edges[data_id] || {data_id, []}
        "pele-node" in classes -> {data_id, Plan.node()}
        true -> {data_id, []}
      end
    end
  end
end
