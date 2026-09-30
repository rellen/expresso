defmodule Expresso.Presenter.Mode do
  @moduledoc """
  The target of the `mode` entity of the presenter DSL

  `Expresso.Presenter.Definition.from/1` makes a map of
  `t:Expresso.Presenter.Definition.mode/0` from it. The option `match` of the
  DSL becomes the key `when` of the map, because Spark cannot make an option
  with the name `when`.
  """

  alias Expresso.Presenter.{Binding, Definition}

  @typedoc "A mode of the DSL"
  @type t :: %__MODULE__{
          name: atom(),
          match: keyword(),
          bindings: [Binding.t()],
          each: [Definition.command()],
          any: [Definition.command()] | nil,
          other: boolean(),
          element: boolean()
        }

  defstruct [
    :name,
    :match,
    :any,
    bindings: [],
    each: [],
    other: false,
    element: false,
    __spark_metadata__: nil
  ]
end
