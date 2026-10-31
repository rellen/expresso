defmodule Expresso.Element.MathReduce do
  @moduledoc """
  A line of a derivation that one β-reduction makes from a line before it

  The `reduce` entity takes the redex as its first argument: the name of a
  `\\part` of the old line that holds the redex, or `:leftmost` for the
  leftmost outermost redex. It makes its line from the line before it, or from
  the line that `from` names. The default relation is `\\to_\\beta`, and the
  default reason is the variable, `:=` and the argument.

  `Expresso.Element.Math.Rewrite.expand/1` turns each reduce into a line with
  `Expresso.Element.Math.Reduce.prepare/3`. `docs/beta-reductions.md` gives
  the design.
  """

  @typedoc "The struct of a β-reduction of a derivation"
  @type t :: %__MODULE__{}

  defstruct [:redex, :relation, :from, :why, :name, __spark_metadata__: nil]
end
