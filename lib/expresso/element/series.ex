defmodule Expresso.Element.Series do
  @moduledoc """
  A series of a chart: its name and one value for each category

  The `series` entity takes the name and the list of values as its
  arguments. A series of a scatter plot is a group of points: it holds its
  points in `elements`, and `symbol` and `color` give the default symbol and
  color of its points. `Expresso.Element.Chart.Scatter` makes the groups of a
  chart without series. With `reveal true`, `Expresso.Element.Chart.Waterfall`
  puts the columns of a waterfall chart into groups: each group is a copy of
  the series, and `columns` holds the indexes of its columns. A series is a
  child of a chart, so it takes the overlay options,
  and the `reveal` and `dim` options of the chart give it its steps.
  `Expresso.Element.Chart` draws it.
  """

  @typedoc "The struct of a series"
  @type t :: %__MODULE__{}

  defstruct [
              :name,
              :values,
              :class,
              :symbol,
              :color,
              :columns,
              elements: [],
              __spark_metadata__: nil
            ] ++ Expresso.Overlay.fields()
end
