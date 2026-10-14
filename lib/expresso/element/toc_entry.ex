defmodule Expresso.Element.TocEntry do
  @moduledoc """
  An entry of a table of contents: the title of a section and a link to its
  first slide

  `Expresso.SectionTransformer` makes the entries of each
  `Expresso.Element.Toc`. An entry is a child of the toc, so it takes the
  overlay options, and the `reveal` and `dim` options of the toc give it its
  steps. `place` tells where the section is, from the slide of the toc:
  `:earlier`, `:current`, `:later`, or `:none` before the first section.
  """

  @typedoc "The struct of an entry of a table of contents"
  @type t :: %__MODULE__{}

  defstruct [
              :text,
              :goto,
              :class,
              place: :none,
              __spark_metadata__: nil
            ] ++ Expresso.Overlay.fields()
end
