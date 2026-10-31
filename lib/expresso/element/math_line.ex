defmodule Expresso.Element.MathLine do
  @moduledoc """
  A line of a derivation in a `math` element

  The `line` entity takes the relation of the line as its first argument, such
  as `"="` or `~S"\\to_\\beta"`, in LaTeX. The `tex` option gives the term of
  the line in LaTeX, and the `why` option gives the reason as plain text.
  `Expresso.Element.Math.check/1` writes the lines into one formula of the
  environment `aligned`, so the lines align on their relations, and each line
  becomes a part with the name `line1`, `line2` and so on, or with its `name`.

  The `steps` option takes 1 or 2. With 2, the links of the line move at its
  first step, and the other symbols of the line show at the next step.
  """

  @typedoc "The struct of a line of a derivation"
  @type t :: %__MODULE__{}

  defstruct [:relation, :tex, :why, :name, steps: 1, __spark_metadata__: nil]
end
