defmodule Expresso.Element.Diagram.Pele.Packet do
  @moduledoc """
  The plan of a packet diagram of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A field | `0-15` | `0-15`, its first and its last bit |

  A packet diagram has no edges. Each field is a node. The name of a field is
  its range of bits, because two fields can have the same label, such as
  `Reserved`. A field that wraps to the next row has one part for each row,
  such as `16-31` and `32-47` for `16-47`. The numbers of the bits show at
  each step.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(_model) do
    fn data_id, classes ->
      if "pele-node" in classes, do: {data_id, Plan.node()}, else: {data_id, []}
    end
  end
end
