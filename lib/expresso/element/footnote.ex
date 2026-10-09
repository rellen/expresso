defmodule Expresso.Element.Footnote do
  @moduledoc """
  An element that gives a source or a note at the bottom of a slide

  The `footnote` entity takes its text as its first argument. The text can
  contain HTML, as the text of a text area does. A footnote shows nothing in
  the place where the deck writes it. The renderer puts the footnotes of a
  slide into one numbered list at the bottom of the slide, under the slide
  template, in the order of the deck. `of_slide/1` returns them.

  The number of a footnote is its position in the list of its slide, from 1.
  Write the same number in the text, such as `<sup>1</sup>`, to point to it.

  A footnote takes the overlay options, so it can show at the step of the
  text that it supports. The `auto_reveal` option of a slide does not give a
  footnote a step of its own.

  The handout view and paper also get a page with the title "Sources" after
  the last slide. It holds the footnotes of each slide, under the number and
  the name of the slide.
  """

  use Expresso.Element

  @typedoc "The struct of a footnote"
  @type t :: %__MODULE__{}

  defstruct [
    :class,
    :text,
    :at,
    :steps,
    :el,
    :effect,
    :speed,
    :easing,
    on: [],
    __spark_metadata__: nil
  ]

  @doc """
  Return the footnotes of a slide, in the order of the deck

  A footnote can be at the level of the slide or inside an element that holds
  elements, such as a text box.

      iex> alias Expresso.Builder
      iex> slide =
      ...>   Builder.slide("s",
      ...>     elements: [
      ...>       Builder.footnote("one"),
      ...>       Builder.text_box(elements: [Builder.footnote("two")])
      ...>     ]
      ...>   )
      iex> slide |> Expresso.Element.Footnote.of_slide() |> Enum.map(& &1.text)
      ["one", "two"]
  """
  @spec of_slide(map()) :: [t()]
  def of_slide(slide), do: collect(slide.elements || [])

  defp collect(elements) do
    Enum.flat_map(elements, fn
      %__MODULE__{} = footnote -> [footnote]
      %{elements: [_ | _] = children} -> collect(children)
      _element -> []
    end)
  end

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(footnote) do
    %__MODULE__{text: text} = footnote
    %{text: text, overlay: Expresso.Overlay.Render.attributes(footnote)}
  end

  @doc """
  Return the text of a footnote as HTML

  The text comes from the deck, as the text of a text area does, and it goes
  into the document with no escape. The page of the sources calls this
  function, because its items have no overlay.
  """
  @spec html(t()) :: Phoenix.HTML.safe()
  # The author of the deck writes the text, as the text of a text area.
  # sobelow_skip ["XSS.Raw"]
  def html(%__MODULE__{text: text}), do: Phoenix.HTML.raw(text)

  @doc """
  Make the HTML of a footnote: an item of the list at the bottom of a slide

  `Expresso.Template.render_elements/1` does not call this function, because
  a footnote shows nothing in its place. The renderer calls it for each
  footnote of the slide.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    temple do
      li class: Expresso.Element.classes("footnote", assigns[:class]), rest!: @overlay do
        div do
          Phoenix.HTML.raw(@text)
        end
      end
    end
  end
end
