defmodule Expresso.Element.Diagram.Pele.Pie do
  @moduledoc """
  The plan of a pie chart of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A slice, with its item of the legend | `Slides` | `Slides`, its label |

  A pie has no edges. Each slice is a node, and its item of the legend gets
  the same name, so a part of a slice shows its item of the legend too. Pele
  draws a slice as a `path`, so `Expresso.Element.Diagram.Pele.name/1` puts it
  into a group with its marks.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(_model) do
    fn data_id, classes ->
      if "pele-slice" in classes, do: {data_id, Plan.node()}, else: {data_id, []}
    end
  end
end
