defmodule Expresso.Element.On do
  @moduledoc """
  A state of an element for a set of steps

  The `on` entity is inside an element. Its first argument is an overlay
  specification, and its options are `state`, `set` and `move_to`.
  `docs/overlays.md` gives the rules. The transformer expands the
  specification into the `steps` field, and the renderer writes the state and
  the properties as CSS rules.

  `move_to` takes the id of an element of a diagram, or the name of a part of
  a formula, and only an `on` entity of a `part` takes it.
  `Expresso.Element.Diagram.place/1` replaces it with `x` and `y` in `set`
  before the render: the distance from the center of the part to the center
  of that element. `Expresso.Element.Math.place/1` puts custom properties
  into `x` and `y`, and the presenter script measures the distance.

  `copy_to` takes a list of targets, and only an `on` entity of a `part`
  takes it. `Expresso.Element.Copy.expand/1` replaces it with one copy of
  the part for each target, from the first step of the entity.
  """

  @typedoc "The struct of an on entity"
  @type t :: %__MODULE__{
          at: Expresso.Overlay.t() | nil,
          state: atom() | nil,
          set: keyword() | nil,
          move_to: String.t() | nil,
          copy_to: [String.t()] | nil,
          steps: [pos_integer()] | nil
        }

  defstruct [:at, :state, :set, :move_to, :copy_to, :steps, __spark_metadata__: nil]
end
