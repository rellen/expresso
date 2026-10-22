defmodule Expresso.Element.Diagram.Pele.Gantt do
  @moduledoc """
  The plan of a Gantt chart of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A task or a milestone | `write` | `write`, its id |
  | The label of a section | `Build` | `Build` |

  A Gantt chart draws no line between two tasks, so a task is a node with no
  edges. A task without an id in the source gets the id of Mermaid, such as
  `task1`. The label of a section is not a group, so it gets no marks.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(_model) do
    fn data_id, classes ->
      if "pele-task" in classes, do: {data_id, Plan.node()}, else: {data_id, []}
    end
  end
end
