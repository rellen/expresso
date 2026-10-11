defmodule Expresso.SectionTransformer do
  @moduledoc """
  The Spark transformer of the sections of a deck

  It runs one time for each deck module at compile time, and before
  `Expresso.Overlay.Transformer`. A slide with the `section` option starts a
  section, and the section runs to the next slide with a `section` option. The
  transformer does two things:

  - It puts the title of the section of each slide into the metadata of the
    slide, under the key `:section`. A slide before the first section has no
    key. A template reads it as `@metadata[:section]`.
  - It puts one `Expresso.Element.TocEntry` for each section into each
    `Expresso.Element.Toc`, with a link to the first slide of the section and
    the place of the section from the slide of the toc. The entries are then
    the children of the toc, so the overlay transformer gives them their steps.

  A toc in a deck without a section is an error, which becomes a
  `Spark.Error.DslError` with the path of the slide.
  """

  use Spark.Dsl.Transformer

  alias Expresso.Element.{Toc, TocEntry}
  alias Spark.Dsl.Transformer

  @doc """
  Run this transformer before the overlay transformer, which gives the entries their steps
  """
  @impl Transformer
  @spec before?(module()) :: boolean()
  def before?(Expresso.Overlay.Transformer), do: true
  def before?(_transformer), do: false

  @doc """
  Put the section of each slide into its metadata, and the entries into each toc
  """
  @impl Transformer
  @spec transform(map()) :: {:ok, map()} | {:error, Spark.Error.DslError.t()}
  def transform(dsl_state) do
    module = Transformer.get_persisted(dsl_state, :module)
    slides = Transformer.get_entities(dsl_state, [:deck])
    sections = sections(slides)

    {slides, _current} =
      slides
      |> Enum.with_index(1)
      |> Enum.map_reduce(nil, fn {slide, number}, current ->
        current = current(sections, number, current)
        {slide(slide, sections, current), current}
      end)

    case Enum.find(slides, &match?({:error, _slide}, &1)) do
      nil -> {:ok, Map.replace_lazy(dsl_state, [:deck], &Map.put(&1, :entities, slides))}
      {:error, slide} -> {:error, dsl_error(module, slide)}
    end
  end

  @doc """
  Return the title and the number of the first slide of each section

      iex> slides = [%Expresso.Slide{}, %Expresso.Slide{section: "Why"}, %Expresso.Slide{section: "How"}]
      iex> Expresso.SectionTransformer.sections(slides)
      [{"Why", 2}, {"How", 3}]
  """
  @spec sections([Expresso.Slide.t()]) :: [{String.t(), pos_integer()}]
  def sections(slides) do
    for {%{section: section}, number} <- Enum.with_index(slides, 1),
        section != nil,
        do: {section, number}
  end

  # The index of the section of a slide in the list of the sections, or nil
  # before the first section.
  defp current(sections, number, current) do
    case Enum.find_index(sections, fn {_title, first} -> first == number end) do
      nil -> current
      index -> index
    end
  end

  defp slide(slide, sections, current) do
    metadata =
      case current do
        nil -> slide.metadata
        index -> Map.put(slide.metadata || %{}, :section, sections |> Enum.at(index) |> elem(0))
      end

    slide = %{slide | metadata: metadata}

    cond do
      not has_toc?(slide.elements || []) -> slide
      sections == [] -> {:error, slide}
      true -> %{slide | elements: fill(slide.elements, sections, current)}
    end
  end

  defp has_toc?(elements) do
    Enum.any?(elements, fn
      %Toc{} -> true
      element -> has_toc?(Map.get(element, :elements) || [])
    end)
  end

  # Each toc of the tree, with one entry for each section.
  defp fill(elements, sections, current) do
    Enum.map(elements, fn
      %Toc{} = toc ->
        %Toc{toc | elements: entries(sections, current)}

      %{elements: [_ | _] = children} = element ->
        %{element | elements: fill(children, sections, current)}

      element ->
        element
    end)
  end

  defp entries(sections, current) do
    for {{title, first}, index} <- Enum.with_index(sections) do
      %TocEntry{text: title, goto: %Expresso.Goto{slide: first}, place: place(index, current)}
    end
  end

  defp place(_index, nil), do: :none
  defp place(index, current) when index < current, do: :earlier
  defp place(index, current) when index == current, do: :current
  defp place(_index, _current), do: :later

  defp dsl_error(module, slide) do
    Spark.Error.DslError.exception(
      module: module,
      message:
        "a toc lists the sections of the deck, and no slide has the section option. " <>
          "Give the first slide of each section a section option, such as section \"Why\".",
      path: [:deck, :slide] ++ List.wrap(slide.name)
    )
  end
end
