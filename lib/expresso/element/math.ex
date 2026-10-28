defmodule Expresso.Element.Math do
  @moduledoc """
  An element that shows a formula in MathML

  The `math` entity takes the formula in one of two forms:

  - The MathML as its first argument, from the `<math>` tag to the `</math>`
    tag. Give the `math` tag the attribute `display="block"` for a formula on
    its own line, which is the usual form on a slide.
  - The LaTeX in the `tex` option. `typeset/1` makes the MathML with
    `Expresso.Element.Math.Tex`, in one run of Node for the deck.

  A browser renders MathML Core without a script and without a font file, and
  each browser of the floor of this project supports it. The text goes into
  the document as it is, as the text of a text area does.
  `docs/math-parts.md` gives the design of the LaTeX.
  """

  use Expresso.Element

  alias Expresso.Element.Diagram.Cache
  alias Expresso.Element.Math.Tex

  @typedoc "The struct of a math element"
  @type t :: %__MODULE__{}

  defstruct [
              :class,
              :text,
              :tex,
              __spark_metadata__: nil
            ] ++ Expresso.Overlay.fields()

  @doc """
  Check that a math element has one source: the MathML or the `tex` option

  The entity of the DSL and `Expresso.Builder` call this function.
  """
  @spec check(t()) :: {:ok, t()} | {:error, String.t()}
  def check(%__MODULE__{text: nil, tex: nil}),
    do: {:error, "a math element takes the MathML as its argument, or the tex option"}

  def check(%__MODULE__{text: text, tex: tex}) when is_binary(text) and is_binary(tex),
    do: {:error, "a math element takes the MathML or the tex option, and not both"}

  def check(%__MODULE__{} = math), do: {:ok, math}

  @doc """
  Make the MathML of each math element of a deck with the `tex` option

  `Expresso.Renderer` calls this function before the render. One run of Node
  makes the MathML of each formula of the deck, and the watch mode keeps the
  MathML of each source from one render to the next, so a change of one slide
  runs Node for the formulas that changed. A deck with no LaTeX runs no Node.

  `render` makes the MathML of a list of sources. The default is
  `Expresso.Element.Math.Tex.render!/1`, and a test can give a function that
  needs no Node. The function raises an `ArgumentError` with the message of
  Temml for a source that Temml cannot read.
  """
  @spec typeset(Expresso.Deck.t(), ([String.t()] -> [Tex.result()])) :: Expresso.Deck.t()
  def typeset(%Expresso.Deck{} = deck, render \\ &Tex.render!/1) do
    {_deck, sources} =
      Expresso.Element.Tree.map_reduce_deck(deck, [], fn
        %__MODULE__{text: nil, tex: tex} = math, sources when is_binary(tex) ->
          {math, [tex | sources]}

        element, sources ->
          {element, sources}
      end)

    case sources |> Enum.reverse() |> Enum.uniq() do
      [] -> deck
      sources -> typeset(deck, sources, render)
    end
  end

  defp typeset(deck, sources, render) do
    # The key of each source holds the version of Temml, so a new version
    # makes each formula again.
    keys = Enum.map(sources, &{Tex, Tex.version(), &1})

    results =
      keys
      |> Cache.fetch_many(fn missing -> missing |> Enum.map(&elem(&1, 2)) |> render.() end)
      |> then(&Map.new(Enum.zip(sources, &1)))

    Expresso.Element.Tree.map_deck(deck, fn
      %__MODULE__{text: nil, tex: tex} = math when is_binary(tex) ->
        %__MODULE__{math | text: mathml!(Map.fetch!(results, tex), tex)}

      element ->
        element
    end)
  end

  defp mathml!({:ok, mathml}, _tex), do: mathml

  defp mathml!({:error, message}, tex) do
    raise ArgumentError,
          "Temml cannot read the formula #{inspect(tex)} of a math element:\n\n#{message}"
  end

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`.
  """
  @spec get_assigns(t()) :: map()
  @impl Expresso.Element
  def get_assigns(math) do
    %__MODULE__{text: text} = math
    %{text: text, overlay: Expresso.Overlay.Render.attributes(math)}
  end

  @doc """
  Make the HTML of a math element

  The MathML goes into one block element inside the root tag.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  @impl Expresso.Element
  def render(assigns) do
    temple do
      div class: Expresso.Element.classes("math", assigns[:class]), rest!: @overlay do
        div do
          Phoenix.HTML.raw(@text)
        end
      end
    end
  end
end
