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

  @doc """
  Give each element of a module in a deck its number

  Each file gets a number in document order, from 0, and two elements with
  the same file get the same number. `sources/3` writes the file at that
  position, so the document holds each file one time.
  """
  @spec number(Expresso.Deck.t(), module()) :: Expresso.Deck.t()
  def number(%Expresso.Deck{slides: slides} = deck, module) do
    {slides, _files} =
      Enum.map_reduce(slides, %{}, fn slide, files ->
        {elements, files} = number_all(slide.elements || [], module, files)
        {%{slide | elements: elements}, files}
      end)

    %Expresso.Deck{deck | slides: slides}
  end

  defp number_all(elements, module, files) do
    Enum.map_reduce(elements, files, fn
      %^module{src: src} = medium, files ->
        files = Map.put_new(files, src, map_size(files))
        {%{medium | index: files[src]}, files}

      %{elements: children} = element, files when is_list(children) ->
        {children, files} = number_all(children, module, files)
        {%{element | elements: children}, files}

      element, files ->
        {element, files}
    end)
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
  def sources(%Expresso.Deck{slides: slides}, module, types, noun) do
    slides
    |> Enum.flat_map(&all(&1.elements || [], module))
    |> Enum.uniq_by(& &1.index)
    |> Enum.sort_by(& &1.index)
    |> Enum.map(&data_uri(&1.src, types, noun))
  end

  defp all(elements, module) do
    Enum.flat_map(elements, fn
      %^module{} = medium -> [medium]
      %{elements: children} when is_list(children) -> all(children, module)
      _element -> []
    end)
  end

  defp data_uri(src, types, noun) do
    case Expresso.DeckFile.read(src) do
      {:ok, bytes} ->
        "data:#{Map.fetch!(types, extension(src))};base64," <> Base.encode64(bytes)

      {:error, reason} ->
        raise ArgumentError,
              "cannot read the #{noun} \"#{src}\": #{:file.format_error(reason)}. " <>
                "A path is relative to the working directory of the command, or to the " <>
                "root option of the deck."
    end
  end

  @doc """
  Write a list of data URIs as JSON, or return `nil` for an empty list

  The renderer writes the value into a `script` element. A data URI holds no
  `<`, and the function escapes each `<` as for the list of the steps. A deck
  with no file of a kind gets `nil`, and the document then holds no element.
  """
  @spec json([String.t()]) :: String.t() | nil
  def json([]), do: nil
  def json(sources), do: sources |> JSON.encode!() |> String.replace("<", "\\u003c")

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
