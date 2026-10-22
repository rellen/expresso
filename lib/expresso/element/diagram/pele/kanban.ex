defmodule Expresso.Element.Diagram.Pele.Kanban do
  @moduledoc """
  The plan of a kanban board of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A column | `todo` | `todo` |
  | A card | `charts` | `charts`, its id, or its text for a card without an id |

  A kanban board has no edges. A column is a container, and each card has its
  column as its parent.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    parents =
      for section <- model["sections"] || [],
          item <- section["items"] || [],
          into: %{},
          do: {item["id"], section["id"]}

    fn data_id, classes ->
      cond do
        "pele-column" in classes -> {data_id, Plan.container()}
        "pele-card" in classes -> {data_id, Plan.node(parents[data_id])}
        true -> {data_id, []}
      end
    end
  end
end
