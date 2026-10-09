defmodule Expresso.Element.Series do
  @moduledoc """
  A series of a chart: its name and one value for each category

  The `series` entity takes the name and the list of values as its
  arguments. A series is a child of a chart, so it takes the overlay options,
  and the `reveal` and `dim` options of the chart give it its steps.
  `Expresso.Element.Chart` draws it.
  """

  @typedoc "The struct of a series"
  @type t :: %__MODULE__{}

  defstruct [
    :name,
    :values,
    :class,
    :at,
    :steps,
    :el,
    :effect,
    :speed,
    :easing,
    on: [],
    __spark_metadata__: nil
  ]
end
