defmodule Expresso.Media do
  @moduledoc """
  The files of the video element and of the audio element

  The document holds a copy of each slide for the present view and one for
  each page of the handout view. A file in each copy would make the document
  many times larger. Therefore an element holds only its number in the deck,
  and the renderer writes each file one time, as a data URI, into a JSON
  element, such as `expresso-videos`. The presenter gives an element its
  source when it plays. `assets/src/media.ts` gives the rules of the script.

  An element module with the field `src` and the field `index` uses these
  functions with its own struct and its own media types, such as
  `%{".webm" => "video/webm"}`.
  """

  alias Expresso.Element.Tree

  @doc """
  Give each element of a module in a deck its number

  Each key gets a number in document order, from 0, and two elements with the
  same key get the same number. The default key is the file, so `sources/4`
  writes each file one time. `Expresso.Element.Embed` gives each embed a key
  of its own with `make_ref/0`, so each embed gets its own number.
  """
  @spec number(Expresso.Deck.t(), module(), (struct() -> term())) :: Expresso.Deck.t()
  def number(%Expresso.Deck{} = deck, module, key \\ & &1.src) do
    {deck, _keys} = Tree.map_reduce_deck(deck, %{}, &number_one(&1, &2, module, key))
    deck
  end

  defp number_one(%module{} = element, keys, module, key) do
    key = key.(element)
    keys = Map.put_new(keys, key, map_size(keys))
    {%{element | index: keys[key]}, keys}
  end

  defp number_one(element, keys, _module, _key), do: {element, keys}

  @doc """
  Return one element of a module for each number in a deck, in the order of
  the numbers

  `number/3` gives the numbers first.
  """
  @spec numbered(Expresso.Deck.t(), module()) :: [struct()]
  def numbered(%Expresso.Deck{slides: slides}, module) do
    slides
    |> Enum.flat_map(&Tree.descendants(&1.elements))
    |> Enum.filter(&is_struct(&1, module))
    |> Enum.uniq_by(& &1.index)
    |> Enum.sort_by(& &1.index)
  end

  @doc """
  Return the data URI of each file of the elements of a module in a deck, in
  the order of their numbers

  The function reads each file through `Expresso.DeckFile`, so the watch mode
  renders the deck again after a change to the file. It raises for a file
  that it cannot read, with the `noun` of the element in the message, such as
  `"video"`.
  """
  @spec sources(Expresso.Deck.t(), module(), %{String.t() => String.t()}, String.t()) ::
          [String.t()]
  def sources(%Expresso.Deck{} = deck, module, types, noun) do
    deck |> numbered(module) |> Enum.map(&data_uri(&1.src, types, noun))
  end

  defp data_uri(src, types, noun) do
    bytes = Expresso.DeckFile.read!(src, noun)
    "data:#{Map.fetch!(types, extension(src))};base64," <> Base.encode64(bytes)
  end

  @doc """
  Write a list of data URIs as JSON, or return `nil` for an empty list

  The renderer writes the value into a `script` element with
  `Expresso.Json.for_script/1`. A deck with no file of a kind gets `nil`, and
  the document then holds no element.
  """
  @spec json([String.t()]) :: String.t() | nil
  def json([]), do: nil
  def json(sources), do: Expresso.Json.for_script(sources)

  @doc """
  Return the extension of a path in lower case, such as `".webm"`

      iex> Expresso.Media.extension("clips/Demo.WEBM")
      ".webm"
  """
  @spec extension(String.t()) :: String.t()
  def extension(path), do: path |> Path.extname() |> String.downcase()

  @doc """
  Make sure that a value is the path of a local file with an extension of the
  types

  This function is the base of the custom type of the first argument of a
  media element. It does not read the file, so a missing file gives an error
  at render time, as for an image. A value with `:` is an address, and the
  element does not take it.
  """
  @spec source(term(), %{String.t() => String.t()}, String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def source(value, types, error) when is_binary(value) do
    if Map.has_key?(types, extension(value)) and not String.contains?(value, ":"),
      do: {:ok, value},
      else: {:error, error}
  end

  def source(_value, _types, error), do: {:error, error}
end
