defmodule Expresso.Element.Part do
  @moduledoc """
  A part of a diagram

  The `part` entity takes the `id` of an element of the SVG file as its first
  argument, and its `at` option gives the steps that show that element.
  `Expresso.Element.Diagram` gives the rules.
  """

  @typedoc "The struct of a part"
  @type t :: %__MODULE__{}

  defstruct [:id, :at, :steps, :el, :effect, :speed, :easing, on: [], __spark_metadata__: nil]

  @doc """
  Make a part with the id of an element of the SVG file
  """
  @spec new(String.t()) :: t()
  def new(id), do: %__MODULE__{id: id}
end
