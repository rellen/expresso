defmodule Expresso.Element.Node do
  @moduledoc """
  The settings of one node of a chart of flows: its label, its column, its order and its class

  The `node` entity takes the name of the node as its argument, such as
  `node "Losses", column: 3`. The name is the name in the flows, and the
  options change only how the chart shows the node.
  `Expresso.Element.Chart.Sankey` and `Expresso.Element.Chart.Chord` read
  them. Only a sankey takes the `column` option.
  """

  @typedoc "The struct of a node"
  @type t :: %__MODULE__{
          name: String.t(),
          label: String.t() | nil,
          column: pos_integer() | nil,
          order: integer() | nil,
          class: String.t() | nil
        }

  defstruct [:name, :label, :column, :order, :class, __spark_metadata__: nil]
end
