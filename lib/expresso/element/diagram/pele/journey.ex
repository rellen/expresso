defmodule Expresso.Element.Diagram.Pele.Journey do
  @moduledoc """
  The plan of a user journey of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A section | `Before` | `Before` |
  | A task | `Write the deck` | `Write the deck`, its text |
  | An item of the legend of the actors | `Presenter` | `Presenter` |

  A user journey has no edges. A section is a container, and each task has
  its section as its parent. Pele draws the line of the scores as one path,
  and the face of each score with no `data-id`, so they show at each step.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    parents = for task <- model["tasks"] || [], into: %{}, do: {task["task"], task["section"]}

    fn data_id, classes ->
      cond do
        "pele-section" in classes -> {data_id, Plan.container()}
        "pele-task" in classes -> {data_id, Plan.node(parents[data_id])}
        true -> {data_id, []}
      end
    end
  end
end
