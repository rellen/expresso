defmodule Expresso.Element.Point do
  @moduledoc """
  A point of a scatter plot: its name and its values

  The `point` entity takes the name as its argument, and the options `x` and
  `y` give its place. The name is the label of the mark. A point is a child of
  its group, so it takes the overlay options. `Expresso.Element.Chart.Scatter`
  checks it and draws it.
  """

  @typedoc "The struct of a point"
  @type t :: %__MODULE__{}

  defstruct [
              :name,
              :x,
              :y,
              :class,
              __spark_metadata__: nil
            ] ++ Expresso.Overlay.fields()
end
