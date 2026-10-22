defmodule Expresso.Element.Diagram.Pele.Radar do
  @moduledoc """
  The plan of a radar chart of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A curve, with its item of the legend | `x` | `x`, its name in the source |
  | The label of an axis | `a` | `axis-a`, `axis-` and the name of the axis |

  A radar chart has no edges. A curve and the label of an axis are nodes. The
  name of an axis has a prefix, because the source can give an axis and a
  curve the same name. Pele draws a curve as a `path`, so
  `Expresso.Element.Diagram.Pele.name/1` puts it into a group with its marks.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(_model) do
    fn data_id, classes ->
      cond do
        "pele-curve" in classes -> {data_id, Plan.node()}
        "pele-axis-label" in classes -> {"axis-" <> data_id, Plan.node()}
        true -> {data_id, []}
      end
    end
  end
end
