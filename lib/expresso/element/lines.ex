defmodule Expresso.Element.Lines do
  @moduledoc """
  A group of lines of a code element

  `Expresso.Element.Code.build/1` makes one group for each item of the
  `reveal` option, with the specification `[from: :next]`. The groups are the
  children of the code element, so the transformer gives each group its steps,
  and the verifier checks each group against the code element. A group is not
  an entity of the DSL.
  """

  @typedoc "The struct of a group of lines"
  @type t :: %__MODULE__{}

  defstruct [:at, :steps, :el, numbers: [], on: []]
end
