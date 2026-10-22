defmodule Expresso.Element.Diagram.Pele.Quadrant do
  @moduledoc """
  The plan of a quadrant chart of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A quadrant | `1` | `quadrant-1`, as the source names it |
  | A point, with its label | `Charts` | `Charts`, its text |

  A quadrant chart has no edges. A quadrant and a point are nodes. Pele draws
  a point as a `circle`, so `Expresso.Element.Diagram.Pele.name/1` puts it
  into a group with its marks. Pele draws the label of each point with no
  `data-id` in the group `pele-point-labels`, in the order of the source, so
  the label at the index `n` from 0 in that group gets the name of the point
  at that index of the model.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    points = for point <- model["points"] || [], do: get_in(point, ["text", "text"])

    fn
      nil, classes, count ->
        if "pele-point-labels" in classes, do: {Enum.at(points, count), []}, else: {nil, []}

      data_id, classes, _count ->
        cond do
          "pele-quadrant" in classes -> {"quadrant-" <> data_id, Plan.node()}
          "pele-point" in classes -> {data_id, Plan.node()}
          true -> {data_id, []}
        end
    end
  end
end
