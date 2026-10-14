defmodule Expresso.Element.Flow do
  @moduledoc """
  A flow of a sankey chart: a source node, a target node and a value

  The `flow` entity takes the three as its arguments, such as
  `flow "Coal", "Electricity", 120`. The transform of the chart turns the
  flows into its categories and one series, so a flow is the same as a
  category `["Coal", "Electricity"]` with the value 120.
  `Expresso.Element.Chart.Sankey` draws them.
  """

  @typedoc "The struct of a flow"
  @type t :: %__MODULE__{from: String.t(), to: String.t(), value: number()}

  defstruct [:from, :to, :value, __spark_metadata__: nil]
end
