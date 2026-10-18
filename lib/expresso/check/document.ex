defmodule Expresso.Check.Document do
  @moduledoc """
  The checks of `--check` that need no tool: they read the deck and its HTML

  `Expresso.Check` runs these checks at each level. Each check returns a list
  of problems and a list of notes. A problem makes the exit status 1. A note
  tells of a choice that can be correct, such as an image with no `alt` text.

  | Check | Kind | Finds |
  | --- | --- | --- |
  | `theme/1` | problem | Each role of a theme of 16 colors under its minimum of contrast |
  | `size/1` | note | The size of the document, and its largest files |
  | `slides/1` | note | An image with no `alt` text, a diagram with no `alt` text, a slide with only a hidden heading, and a slide with no `h1` |
  """

  @typedoc "The problems and the notes of a check"
  @type result :: %{problems: [String.t()], notes: [String.t()]}

  # The number of the largest files that the note of the size names.
  @largest 3

  @doc """
  Return a problem for each role of the theme of the deck under its minimum of contrast

  The problems are the warnings of `Expresso.ThemeVerifier`. A built-in theme
  has no problem.
  """
  @spec theme(Expresso.Deck.t()) :: result()
  def theme(deck) do
    problems =
      deck.metadata
      |> Map.get(:theme, :default)
      |> Expresso.ThemeVerifier.messages()
      |> Enum.map(&("Theme: " <> &1))

    %{problems: problems, notes: []}
  end

  @doc """
  Return a note with the size of the document, and with the size and the type of its largest files

  A file is a data URI in a `src`, an `href` or an `xlink:href` attribute.
  `Expresso.Assets` keeps one copy of each large file, so the note names each
  file one time.

      iex> Expresso.Check.Document.size(String.duplicate("a", 2_500_000))
      %{problems: [], notes: ["The document is 2.4 MB."]}
  """
  @spec size(String.t()) :: result()
  def size(html) do
    files =
      ~r/ (?:src|href|xlink:href)="data:([^;,"]+)[^,"]*,([^"]{1024,})"/
      |> Regex.scan(html, capture: :all_but_first)
      |> Enum.map(fn [type, data] -> {type, div(byte_size(data) * 3, 4)} end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(@largest)

    note =
      case files do
        [] ->
          "The document is #{amount(byte_size(html))}."

        files ->
          names = Enum.map_join(files, ", ", fn {type, bytes} -> "#{type} #{amount(bytes)}" end)
          "The document is #{amount(byte_size(html))}. The largest files: #{names}."
      end

    %{problems: [], notes: [note]}
  end

  defp amount(bytes) when bytes >= 1_048_576,
    do: "#{:erlang.float_to_binary(bytes / 1_048_576, decimals: 1)} MB"

  defp amount(bytes), do: "#{div(bytes + 1023, 1024)} KB"

  @doc """
  Return a note for each slide with a part that a screen reader reads differently

  The function reads the present view of each slide in the HTML, and it gives
  a note for:

    * an image with an empty `alt`. A screen reader skips such an image.
    * a diagram with no `alt` option. A screen reader reads the text of its SVG.
    * a slide with only a hidden heading. A screen reader reads the heading,
      but the slide shows no title.
    * a slide with no `h1`, from the option `sr_heading false`.
  """
  @spec slides(String.t()) :: result()
  def slides(html) do
    notes =
      html
      |> Floki.parse_document!()
      |> Floki.find("section[id^=slide-]")
      |> Enum.flat_map(&slide_notes/1)

    %{problems: [], notes: notes}
  end

  defp slide_notes({"section", attributes, _children} = section) do
    "slide-" <> number = attributes |> List.keyfind("id", 0) |> elem(1)

    [
      count(section, ~s(img[alt=""]), "an image with no alt text, so a screen reader skips it"),
      count(
        section,
        ".diagram:not([aria-label])",
        "a diagram with no alt text, so a screen reader reads the text of its SVG"
      ),
      heading(section)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&"Slide #{number}: #{&1}.")
  end

  defp count(section, selector, text) do
    case length(Floki.find(section, selector)) do
      0 -> nil
      1 -> "1 × " <> text
      n -> "#{n} × " <> text
    end
  end

  defp heading(section) do
    cond do
      Floki.find(section, "h1") == [] ->
        "no h1, so a screen reader finds no name for the slide"

      Floki.find(section, "h1:not(.slide-hidden-heading)") == [] ->
        "only a hidden heading, so the slide shows no title"

      true ->
        nil
    end
  end
end
