defmodule Expresso.Assets do
  @moduledoc """
  Keeps one copy of each large file that the document holds more than one time

  A deck is one file, so an image or a track goes into the document as a data
  URI. An SVG file of a diagram or of an icon can also hold an image as a data
  URI in an `href` or an `xlink:href` attribute. Each view of the slide holds
  its own copy: the present view, each page of the handout view and the
  picture in the menu. An image of 250 KB in a slide of two steps was then in
  the document six times.

  `dedupe/1` runs on the HTML of the document. For each value of a `src`, an
  `href` or an `xlink:href` attribute that is a data URI of `#{1024}`
  characters or more, and that occurs more than one time:

    * the first element keeps the attribute, and gets `data-asset-N` with the
      name of that attribute, such as `data-asset-0="src"`;
    * each other element loses the attribute, and gets `data-asset-src="0"` or
      `data-asset-href="0"` in its place. An `xlink:href` gets
      `data-asset-href`, because SVG 2 reads `href` in place of `xlink:href`,
      and a selector cannot hold the `:` of the name.

  The presenter script copies the value back into each element when the
  document loads. `assets/src/assets.ts` gives the rules.
  """

  # A data URI under this length costs less than the attribute that replaces it.
  @minimum 1024

  @attribute ~r/ (src|href|xlink:href)="(data:[^"]{#{@minimum},})"/

  # The same attribute as a whole part of the split text.
  @whole ~r/\A (src|href|xlink:href)="(data:[^"]{#{@minimum},})"\z/

  @doc """
  Replace each copy of a large data URI after its first with a reference to the first

      iex> uri = "data:image/png;base64," <> String.duplicate("A", 1100)
      iex> html = ~s(<img src="\#{uri}"><img src="\#{uri}">)
      iex> Expresso.Assets.dedupe(html)
      ~s(<img data-asset-0="src" src="\#{uri}"><img data-asset-src="0">)

  A data URI that occurs one time, or that is short, stays as it is.
  """
  @spec dedupe(String.t()) :: String.t()
  def dedupe(html) do
    counts =
      @attribute
      |> Regex.scan(html, capture: :all_but_first)
      |> Enum.frequencies_by(fn [_name, uri] -> uri end)

    {parts, _ids} =
      @attribute
      |> Regex.split(html, include_captures: true)
      |> Enum.map_reduce(%{}, fn part, ids -> replace(part, counts, ids) end)

    IO.iodata_to_binary(parts)
  end

  defp replace(part, counts, ids) do
    case Regex.run(@whole, part, capture: :all_but_first) do
      [name, uri] ->
        reference(part, name, uri, counts, ids)

      _text ->
        {part, ids}
    end
  end

  defp reference(part, name, uri, counts, ids) do
    cond do
      Map.fetch!(counts, uri) < 2 ->
        {part, ids}

      Map.has_key?(ids, uri) ->
        {~s( data-asset-#{reference_name(name)}="#{Map.fetch!(ids, uri)}"), ids}

      true ->
        id = map_size(ids)
        {~s( data-asset-#{id}="#{name}") <> part, Map.put(ids, uri, id)}
    end
  end

  defp reference_name("xlink:href"), do: "href"
  defp reference_name(name), do: name
end
