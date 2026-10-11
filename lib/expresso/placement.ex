defmodule Expresso.Placement do
  @moduledoc """
  The places of the elements: which element can hold which child

  The DSL accepts an element in more places than these rules give, because
  the macros of the outer entities stay in scope in each nested block. See
  "The definitions of the elements" in `docs/architecture.md`.
  `Expresso.PlacementTransformer` calls `slide/1` for each slide, and it refuses
  an element in a wrong place. `docs/reference/placement.md` gives the rules.

  A transformer adds children to two elements, and these children are in their
  place: the `Expresso.Element.Lines` of a code element and the
  `Expresso.Element.TocEntry` of a toc. `Expresso.Overlay.Check` reports a
  `pause` inside an element, so this module accepts a pause in each place.
  """

  alias Expresso.Element.{
    Audio,
    Callout,
    Chart,
    Code,
    Column,
    Columns,
    Diagram,
    Embed,
    Footnote,
    Frame,
    Icon,
    Image,
    Item,
    Lines,
    List,
    Math,
    Part,
    Pause,
    QrCode,
    Quotation,
    Row,
    Series,
    Shape,
    Spacer,
    Stat,
    Table,
    TextArea,
    TextBox,
    Toc,
    TocEntry,
    Video
  }

  alias Expresso.Slide
  alias Shoddy.Result

  # The elements that a text box, a column and a callout hold
  @inner [
    TextArea,
    Image,
    List,
    Table,
    Quotation,
    Spacer,
    Code,
    Math,
    Diagram,
    Embed,
    Video,
    Audio,
    QrCode,
    Chart,
    Stat,
    Icon
  ]

  # The children of each element, for each key that holds children. An element
  # that is not in the map holds no children.
  @children %{
    Slide => [elements: [TextBox, Columns, Callout, Toc] ++ @inner ++ [Footnote, Shape, Pause]],
    TextBox => [elements: @inner ++ [Columns, Callout, Toc]],
    Columns => [elements: [Column]],
    Column => [elements: @inner ++ [Callout, Toc]],
    Callout => [elements: @inner],
    List => [elements: [Item]],
    Item => [elements: [List]],
    Table => [elements: [Row]],
    Diagram => [elements: [Part]],
    Chart => [elements: [Series], timeline: [Frame]],
    Frame => [elements: [Series]],
    Code => [elements: [Lines]],
    Toc => [elements: [TocEntry]]
  }

  @doc """
  Return the children that an element holds under a key, as a list of modules

      iex> Expresso.Element.Columns in Expresso.Placement.children(Expresso.Element.TextBox, :elements)
      true
      iex> Expresso.Placement.children(Expresso.Element.Callout, :elements) |> Enum.member?(Expresso.Element.Callout)
      false
  """
  @spec children(module(), atom()) :: [module()]
  def children(parent, key), do: @children |> Map.get(parent, []) |> Keyword.get(key, [])

  @doc """
  Give an error for the first element of a slide in a wrong place

      iex> alias Expresso.Builder
      iex> Expresso.Placement.slide(Builder.slide("s", elements: [Builder.callout(:tip)]))
      :ok
      iex> slide = Builder.slide("s", elements: [Builder.callout(:tip, elements: [Builder.callout(:note)])])
      iex> {:error, message} = Expresso.Placement.slide(slide)
      iex> message =~ "a callout is inside a callout"
      true
  """
  @spec slide(Slide.t()) :: :ok | {:error, String.t()}
  def slide(%Slide{} = slide), do: check(slide)

  defp check(parent) do
    for key <- [:elements, :timeline],
        child <- Map.get(parent, key) || [],
        is_struct(child) do
      {key, child}
    end
    |> Stream.map(fn {key, child} -> place(parent, key, child) end)
    |> Result.collect()
    |> Result.ignore()
  end

  defp place(_parent, _key, %Pause{}), do: :ok

  defp place(%parent{}, key, %child{} = element) do
    allowed = children(parent, key)

    if child in allowed do
      check(element)
    else
      {:error, message(parent, child, allowed)}
    end
  end

  defp message(Slide, child, allowed) do
    "a #{name(child)} is at the level of the slide, and a slide holds #{names(allowed)}"
  end

  defp message(parent, child, []) do
    "a #{name(child)} is inside a #{name(parent)}, and a #{name(parent)} holds no elements"
  end

  defp message(parent, child, allowed) do
    "a #{name(child)} is inside a #{name(parent)}, and a #{name(parent)} holds #{names(allowed)}"
  end

  defp names(modules), do: modules |> Enum.reject(&(&1 == Pause)) |> Enum.map_join(", ", &name/1)

  defp name(module), do: module |> Module.split() |> Elixir.List.last() |> Macro.underscore()
end
