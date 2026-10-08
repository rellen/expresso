defmodule Expresso.Element.Pause do
  @moduledoc """
  A step in the counter of a slide

  The `pause` entity increments the counter of the slide, and it has no
  content. Its `label` option names the step that the pause starts, such as
  `pause label: "The restart"`. The transformer removes each `pause` from the elements of a slide
  after it reads the counter. The renderer also skips it, for a slide that no
  transformer expanded. `docs/overlays.md` gives the rules.
  """

  @typedoc "The struct of a pause entity"
  @type t :: %__MODULE__{label: String.t() | nil}

  defstruct label: nil, __spark_metadata__: nil
end
