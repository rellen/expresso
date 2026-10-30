defmodule Expresso.Element.Part do
  @moduledoc """
  A part of a diagram

  The `part` entity takes the `id` of an element of the SVG file as its first
  argument, and its `at` option gives the steps that show that element.
  `Expresso.Element.Diagram` gives the rules.

  A `copy` entity of a part goes into `copies`. `Expresso.Element.Copy.expand/1`
  gives each copy its own part, with the source in `copy_of` and the target in
  `copy_to`. A copy of a copy has the target of its source in `copy_start`.
  """

  @typedoc "The struct of a part"
  @type t :: %__MODULE__{}

  defstruct [
              :id,
              :copy_of,
              :copy_to,
              :copy_start,
              copies: [],
              __spark_metadata__: nil
            ] ++ Expresso.Overlay.fields()
end
