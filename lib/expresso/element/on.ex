defmodule Expresso.Element.On do
  @moduledoc """
  A state of an element for a set of steps

  The `on` entity is inside an element. Its first argument is an overlay
  specification, and its options are `state`, `set` and `move_to`.
  `docs/overlays.md` gives the rules. The transformer expands the
  specification into the `steps` field, and the renderer writes the state and
  the properties as CSS rules.

  `move_to` takes the id of an element of a diagram, and only an `on` entity
  of a `part` takes it. `Expresso.Element.Diagram.place/1` replaces it with
  `x` and `y` in `set` before the render: the distance from the center of the
  part to the center of that element.
  """

  @typedoc "The struct of an on entity"
  @type t :: %__MODULE__{
          at: Expresso.Overlay.t() | nil,
          state: atom() | nil,
          set: keyword() | nil,
          move_to: String.t() | nil,
          steps: [pos_integer()] | nil
        }

  defstruct [:at, :state, :set, :move_to, :steps, __spark_metadata__: nil]
end
