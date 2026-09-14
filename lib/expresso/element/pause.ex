defmodule Expresso.Element.Pause do
  @moduledoc """
  A step in the counter of a slide

  The `pause` entity increments the counter of the slide, and it has no
  content. The transformer removes each `pause` from the elements of a slide
  after it reads the counter. The renderer also skips it, for a slide that no
  transformer expanded. `docs/overlays.md` gives the rules.
  """

  @typedoc "The struct of a pause entity"
  @type t :: %__MODULE__{}

  defstruct __spark_metadata__: nil
end
