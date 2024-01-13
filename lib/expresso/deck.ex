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
  @spec add_slide(deck :: t(), name :: String.t() | nil, metadata :: map(), data :: Keyword.t()) ::
          t()
  def add_slide(deck, name \\ nil, metadata \\ %{}, data \\ []) do
    new_slide = Expresso.Slide.new(name, metadata, data)
    %__MODULE__{deck | slides: deck.slides ++ [new_slide]} |> number_slides()
  end

  defp number_slides(deck) do
    %__MODULE__{slides: slides} = deck

    numbered_slides =
      slides
      |> Enum.with_index(fn slide, index ->
        %Expresso.Slide{metadata: metadata} = slide
        %Expresso.Slide{slide | metadata: Map.put(metadata, :slide_number, index)}
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
