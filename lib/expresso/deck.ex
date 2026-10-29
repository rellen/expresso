defmodule Expresso.Deck do
  @moduledoc """
  A slide deck

  The metadata of a deck can hold `:progress`. The value `false` hides the
  progress bar of the present view at the start, and the key `g` can still
  show it. A deck without the key shows the progress bar.

  The metadata can also hold `:print_notes`. The value `false` leaves the
  notes of the speaker out of the handout view and of the print. The speaker
  view still shows them. A deck without the key prints the notes.

  The metadata can also hold `:slide_numbers`. The value `true` shows the
  number of each slide and the number of slides, such as `3 / 12`, in a
  corner of the slide. Slide 1 shows no number, because it is usually the
  title slide. A deck without the key shows no number.

  The metadata can also hold `:duration`, the length of the talk in minutes.
  The speaker view then shows the time left and the pace. A deck without the
  key, or with `nil`, shows neither.

  The metadata can also hold `:transition`, the transition from one slide to
  the next in the present view: `:fade`, `:slide`, `:zoom`, `:none` or a
  transition of the CSS of the deck. The metadata of a slide can hold
  `:transition` too, and it replaces the value of the deck for the move into
  that slide. A deck without the key fades. The DSL makes sure that a
  transition has a rule, and a struct of this module does not.

  The metadata can also hold `:morph`, how the elements of two neighbor
  slides move from one slide to the next: `:auto`, `:named` or `:off`. The
  metadata of a slide can hold `:morph` too, and it replaces the value of the
  deck for the move into that slide. A deck without the key uses `:auto`.
  `docs/reference/morph-option.md` gives the rules.

  The metadata can also hold `:lang`, the language of the text of the deck as
  a language tag, such as `"de"`. The renderer writes it into the `lang`
  attribute of the `html` element. A deck without the key is English.

  The metadata can also hold `:dim_contrast`, the minimum contrast ratio of
  dimmed text, from 3 to 7. A deck without the key, or with `nil`, dims to
  3:1. `Expresso.Palette.with_dim_contrast/2` gives the rules.

  The metadata can also hold `:math_font`, the font of each math element, one
  of `Expresso.Element.Math.Font.names/0`. A deck without the key gets
  `:latin_modern`. The renderer puts the font into a document with a math
  element only.

  The metadata can also hold `:effect`, the way in which an element with steps
  shows and hides, such as `:grow`. The metadata of a slide and the `effect`
  field of an element can hold it too, and the nearest value applies. A deck
  without the key fades. `Expresso.Overlay.Render.identify/1` gives the rules.

  The metadata can also hold `:speed` and `:easing`, the time and the easing
  of each animation in a slide. The speed is `:fast`, `:normal`, `:slow` or a
  number of milliseconds, and the easing is `:ease_in_out`, `:ease_out`,
  `:linear` or `:spring`. They follow the same rules as `:effect`. A deck
  without the keys uses the time and the easing of the theme.

  The metadata can also hold `:css`, a style sheet or the path of a file that
  holds one. `Expresso.Css.resolve/1` gives the rules. The renderer puts the
  style sheet into the document after the theme.
  """

  @type t :: %__MODULE__{:name => String.t(), :metadata => map(), :slides => list()}

  defstruct [:name, :metadata, :slides]

  @doc """
  Make the struct of a deck

  `Expresso.from_dsl_state/1` calls this function. Make a deck with the DSL
  or with `Expresso.Builder`.
  """
  @spec new(name :: String.t(), metadata :: map(), slides :: list()) :: t()
  def new(name, metadata \\ %{}, slides \\ []) do
    %__MODULE__{name: name, metadata: metadata, slides: slides}
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
  Validate the minimum contrast ratio of dimmed text

  The value is a number from 3 to 7. 3 is the default of Expresso, 4.5 is the
  minimum of WCAG 2.2 for normal text, and 7 is its enhanced minimum.

      iex> Expresso.Deck.dim_contrast(4.5)
      {:ok, 4.5}
      iex> Expresso.Deck.dim_contrast(2)
      {:error, "the dim_contrast option must be a number from 3 to 7, such as 4.5, and not 2"}
  """
  @spec dim_contrast(term()) :: {:ok, number()} | {:error, String.t()}
  def dim_contrast(value) when is_number(value) and value >= 3 and value <= 7, do: {:ok, value}

  def dim_contrast(value),
    do:
      {:error,
       "the dim_contrast option must be a number from 3 to 7, such as 4.5, and not #{inspect(value)}"}

  @doc """
  Validate the language of a deck

  The value is a language tag of BCP 47 in its usual form: a language of two
  or three letters, then subtags of letters and digits, each after a hyphen.

      iex> Expresso.Deck.lang("pt-BR")
      {:ok, "pt-BR"}
      iex> Expresso.Deck.lang("en_US")
      {:error, "the lang option must be a language tag, such as \\"en\\" or \\"pt-BR\\", and not \\"en_US\\""}
  """
  @spec lang(term()) :: {:ok, String.t()} | {:error, String.t()}
  def lang(value) when is_binary(value) do
    if value =~ ~r/\A[A-Za-z]{2,3}(-[A-Za-z0-9]{1,8})*\z/,
      do: {:ok, value},
      else: {:error, lang_error(value)}
  end

  def lang(value), do: {:error, lang_error(value)}

  defp lang_error(value),
    do:
      "the lang option must be a language tag, such as \"en\" or \"pt-BR\", and not #{inspect(value)}"

  @doc """
  Render a deck to HTML

  The HTML starts with the doctype of HTML 5. Floki drops a doctype node when it
  parses a document, so this function puts the doctype in front of the tree.
  Without the doctype a browser uses the quirks mode.

  Each large data URI that the document holds more than one time stays in it
  one time. `Expresso.Assets` gives the rules.

  Floki writes the tree with no indentation. The pretty printer of Floki puts a
  line break between two elements, and it does not know an inline element.
  A line break becomes a space, and the text of a deck then gets a space in
  front of each inline element and after it.
  """
  @spec render(t()) :: String.t()
  def render(deck) do
    Expresso.load_templates()

    body =
      Expresso.Renderer.render(deck: deck)
      |> Phoenix.HTML.safe_to_string()
      |> Floki.parse_document!()
      |> Floki.raw_html()
      |> Expresso.Assets.dedupe()

    "<!DOCTYPE html>\n" <> body
  end
end
