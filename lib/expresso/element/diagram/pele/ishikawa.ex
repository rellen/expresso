defmodule Expresso.Element.Diagram.Pele.Ishikawa do
  @moduledoc """
  The plan of an Ishikawa diagram of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | The head, the effect | `A slow deck` | `A slow deck`, its text |
  | A category, with its bone and its causes | `Assets` | `Assets`, its text |

  An Ishikawa diagram has no edges. The head and each category are nodes.
  Pele draws the causes of a category in its group with no `data-id`, so a
  part of a category shows its causes too. The spine shows at each step.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(_model) do
    fn data_id, classes ->
      if "pele-ishikawa-category" in classes or "pele-ishikawa-head" in classes,
        do: {data_id, Plan.node()},
        else: {data_id, []}
    end
  end
end
