defmodule Expresso.Test.Decks do
  @moduledoc """
  Makes and reads the parts of a deck that several unit tests use

  Put `import Expresso.Test.Decks` in the test module. The names of the
  functions are not names of the DSL, so a deck module inside the test module
  can use the DSL with no conflict.
  """

  alias Expresso.Builder

  @doc """
  Return the slide with a name, from a deck or from the deck of a DSL module
  """
  @spec find_slide(Expresso.Deck.t() | module(), String.t()) :: Expresso.Slide.t() | nil
  def find_slide(module, name) when is_atom(module),
    do: module |> Expresso.parse() |> find_slide(name)

  def find_slide(%Expresso.Deck{slides: slides}, name), do: Enum.find(slides, &(&1.name == name))

  @doc """
  Make a text box that holds one text area with the text
  """
  @spec box(String.t()) :: Expresso.Element.TextBox.t()
  def box(text), do: Builder.text_box(elements: [Builder.text_area(text: text)])
end
