defmodule Expresso.Element.Focus do
  @moduledoc """
  A group of the `highlight` option of a chart

  `Expresso.Element.Chart.check/1` makes one group for each item of the
  option, with the specification `:next`. The groups go into the `focus`
  field of the chart, and not into its series. `Expresso.Overlay.Expand`
  gives each group one step from the counter of the slide, and
  `Expresso.Element.Chart.rules/1` dims each series that is not in the group
  at that step. A group is not an entity of the DSL.

  The `series` field holds the color number of each series of the group, from
  1. The color number is also the value of the `data-series` attribute of the
  series.
  """

  @typedoc "The struct of a group of the highlight option"
  @type t :: %__MODULE__{}

  defstruct [series: []] ++ Expresso.Overlay.fields()
end
