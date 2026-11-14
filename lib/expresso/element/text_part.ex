defmodule Expresso.Element.TextPart do
  @moduledoc """
  A part of the text of an element that shows or changes at its own steps

  A tag in the text of a text area or of an item takes the attribute `at`,
  such as `<span at="2-">42</span>`. `Expresso.Overlay.Inline` makes one
  struct of this module for each such tag, and it puts the structs into the
  `elements` of the text element. The expansion of the overlays then gives a
  part its steps as it gives them to an element, and the counter of the slide
  goes through the parts in the order of the text.

  `index` is the number of the part in its text, from 1. The tag in the text
  holds the same number in `data-text-part`, and the render writes the
  attributes of the overlay contract after it.

  A part with the attribute `state` shows at each step. Its steps are in an
  `on` entity with the state, as `on 3, state: :alert` in an element.
  `docs/inline-steps.md` gives the design.
  """

  @typedoc "The struct of a part of a text"
  @type t :: %__MODULE__{}

  defstruct [:index, __spark_metadata__: nil] ++ Expresso.Overlay.fields()
end
