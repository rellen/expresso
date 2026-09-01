defmodule Expresso.Deck do
  @moduledoc """
  A slide deck
  """

  @type t :: %__MODULE__{:name => String.t(), :metadata => map(), :slides => list()}

  defstruct [:name, :metadata, :slides]

  @doc """
  Create a new deck
  """
  @spec new(name :: String.t(), metadata :: map(), slides :: list()) :: t()
  def new(name, metadata \\ %{}, slides \\ []) do
    %__MODULE__{name: name, metadata: metadata, slides: slides}
  end

  @doc """
  Add a slide to a deck
  """
  @spec add_slide(
          deck :: t(),
          name :: String.t() | nil,
          metadata :: map(),
          elements :: Keyword.t()
        ) ::
          t()
  def add_slide(%__MODULE__{} = deck, name \\ nil, metadata \\ %{}, elements \\ []) do
    new_slide = Expresso.Slide.new(name, metadata, elements)
    %__MODULE__{deck | slides: deck.slides ++ [new_slide]} |> number_slides()
  end

  @doc """
  Write the number of each slide into the metadata of the slide

  The first slide is slide 1.

  A slide from the DSL holds `nil` in its metadata field. This function puts an
  empty map into that field first.
  """
  @spec number_slides(t()) :: t()
  def number_slides(%__MODULE__{slides: slides} = deck) do
    numbered_slides =
      slides
      |> Enum.with_index(1)
      |> Enum.map(fn {%Expresso.Slide{metadata: metadata} = slide, number} ->
        %Expresso.Slide{slide | metadata: Map.put(metadata || %{}, :slide_number, number)}
      end)

    %__MODULE__{deck | slides: numbered_slides}
  end

  @doc """
  Render a deck to HTML

  The HTML starts with the doctype of HTML 5. Floki drops a doctype node when it
  parses a document, so this function puts the doctype in front of the formatted
  tree. Without the doctype a browser uses the quirks mode.
  """
  @spec render(t()) :: String.t()
  def render(deck) do
    Expresso.load_templates()

    body =
      Expresso.Renderer.render(deck: deck)
      |> Phoenix.HTML.safe_to_string()
      |> Floki.parse_document!()
      |> Floki.raw_html(pretty: true)

    "<!DOCTYPE html>\n" <> body
  end
end
