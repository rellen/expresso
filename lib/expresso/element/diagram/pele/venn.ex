defmodule Expresso.Element.Diagram.Pele.Venn do
  @moduledoc """
  The plan of a Venn diagram of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A set, with its circle and its label | `Desirable` | `Desirable` |
  | The label of an intersection | `Desirable\\|Feasible` | `Desirable\\|Feasible`, the sets with `\\|` between them |
  | A text in a set | `D1` | `D1`, its id |

  A Venn diagram has no edges. A set, an intersection and a text are nodes.
  Pele draws a set as a `circle`, so `Expresso.Element.Diagram.Pele.name/1`
  puts it into a group with its marks, and the label of the set gets the same
  name. An intersection has no shape of its own, so its part shows its label.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @marked ["pele-venn-set", "pele-venn-region", "pele-venn-text"]

  @impl Plan
  def plan(_model) do
    fn data_id, classes ->
      if Enum.any?(@marked, &(&1 in classes)), do: {data_id, Plan.node()}, else: {data_id, []}
    end
  end
end
