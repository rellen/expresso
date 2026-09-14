defmodule Expresso.Element.On do
  @moduledoc """
  A state of an element for a set of steps

  The `on` entity is inside an element. Its first argument is an overlay
  specification, and its options are `state` and `set`. `docs/overlays.md`
  gives the rules. The transformer expands the specification, and the renderer
  writes the state and the properties as CSS rules.
  """

  @typedoc "The struct of an on entity"
  @type t :: %__MODULE__{
          at: Expresso.Overlay.t() | nil,
          state: atom() | nil,
          set: keyword() | nil
        }

  defstruct [:at, :state, :set, __spark_metadata__: nil]
end
