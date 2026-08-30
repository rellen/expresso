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

  A slide from the DSL holds `nil` in its metadata field. This function puts an
  empty map into that field first.
  """
  @spec number_slides(t()) :: t()
  def number_slides(%__MODULE__{slides: slides} = deck) do
    numbered_slides =
      slides
      |> Enum.with_index(fn %Expresso.Slide{metadata: metadata} = slide, index ->
        %Expresso.Slide{slide | metadata: Map.put(metadata || %{}, :slide_number, index)}
      end)

    %__MODULE__{deck | slides: numbered_slides}
  end

  @doc """
  Render a deck to HTML
  """
  @spec render(t()) :: String.t()
  def render(deck) do
    Expresso.load_templates()

    Expresso.Renderer.render(deck: deck)
    |> Phoenix.HTML.safe_to_string()
    |> Floki.parse_document!()
    |> Floki.raw_html(pretty: true)
  end
end
