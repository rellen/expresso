defmodule Expresso.Element.MathRewrite do
  @moduledoc """
  A line of a derivation that a substitution makes from a line before it

  The `rewrite` entity takes the relation of the new line as its optional
  first argument, such as `~S"\\to_\\beta"`. The default is `=`. The entity
  makes its line from the line before it, or from the line that `from` names.
  `replace` names the occurrences in the old line: a `\\part`, or a symbol
  that `within` can limit to a part. `by` names a part of an earlier line,
  and a copy of it goes into each place. `by_tex` gives new LaTeX in place
  of `by`. The option is not `with`, because `with` is a special form of
  Elixir. `to` gives a template, and each `\\use{name}` in it is a copy of the
  part `name`. Without `replace`, the template is the whole new line. `drop`
  names the parts of the old line that the new line does not hold. `rule`
  gives a left side and a right side with the variables of `vars`, and
  `Expresso.Element.Math.Rule` finds the left side in the old line, or in
  the part of `replace`.

  `Expresso.Element.Math.check/1` turns each rewrite into an
  `Expresso.Element.MathLine` with `Expresso.Element.Math.Rewrite.expand/1`.
  `docs/line-rewrites.md` gives the design.
  """

  @typedoc "The struct of a rewrite of a derivation"
  @type t :: %__MODULE__{}

  defstruct [
    :relation,
    :from,
    :replace,
    :within,
    :by,
    :by_tex,
    :to,
    :rule,
    :why,
    :name,
    drop: [],
    vars: [],
    __spark_metadata__: nil
  ]
end
