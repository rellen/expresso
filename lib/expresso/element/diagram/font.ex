defmodule Expresso.Element.Diagram.Font do
  @moduledoc """
  The font that a tool gets for the text of a graph

  Each tool measures a text with the font that it gets, and it calculates the
  size of each box from that measure. Therefore the render gives the font of
  the slide to the tool, and the browser shows the text in the same font.

  The built-in theme uses Atkinson Hyperlegible. The document holds that font
  as WOFF2 files, and the tools read TTF files, so `assets/fonts/` also holds
  the four TTF files of the font. This module reads them at compile time, as
  `Expresso.Font` reads the WOFF2 files, so a release does not need the
  `assets/` directory.

  The `font` option of a diagram gives a directory with the TTF files of a
  different font. `read!/1` takes the family and the style of each file from
  the `name` table of the file. A style that the directory does not have takes
  the regular file.
  """

  @typedoc "A font: its family, and the bytes of the TTF file of each style"
  @type t :: %{
          family: String.t(),
          regular: binary(),
          bold: binary(),
          italic: binary(),
          bold_italic: binary()
        }

  @styles [regular: "Regular", bold: "Bold", italic: "Italic", bold_italic: "BoldItalic"]

  for {_style, name} <- @styles do
    @external_resource "./assets/fonts/AtkinsonHyperlegible-#{name}.ttf"
  end

  @builtin Map.new(@styles, fn {style, name} ->
             {style, File.read!("./assets/fonts/AtkinsonHyperlegible-#{name}.ttf")}
           end)
           |> Map.put(:family, "Atkinson Hyperlegible")

  @doc "The font of the built-in theme, Atkinson Hyperlegible"
  @spec builtin() :: t()
  def builtin, do: @builtin

  @doc """
  Read the TTF files of a directory

  The function raises an `ArgumentError` for a directory without a TTF file
  with the style Regular, and for files of more than one family.
  """
  @spec read!(Path.t()) :: t()
  def read!(dir) do
    files =
      dir
      |> Path.join("*.ttf")
      |> Path.wildcard()
      |> Enum.sort()
      |> Enum.map(&{&1, Expresso.DeckFile.read!(&1, "font")})
      |> Enum.map(fn {path, bytes} -> {path, bytes, names(bytes)} end)

    case Enum.uniq(for {_path, _bytes, {family, _style}} <- files, do: family) do
      [family] ->
        collect(dir, family, files)

      [] ->
        raise ArgumentError, "the font directory \"#{dir}\" has no TTF file"

      families ->
        raise ArgumentError,
              "the font directory \"#{dir}\" has more than one family: " <>
                Enum.join(families, ", ")
    end
  end

  defp collect(dir, family, files) do
    by_style = Map.new(files, fn {_path, bytes, {_family, style}} -> {style(style), bytes} end)

    case by_style[:regular] do
      nil ->
        raise ArgumentError,
              "the font directory \"#{dir}\" has no TTF file with the style Regular"

      regular ->
        Map.new(@styles, fn {style, _name} -> {style, Map.get(by_style, style, regular)} end)
        |> Map.put(:family, family)
    end
  end

  defp style(name) do
    case name |> String.downcase() |> String.replace(" ", "") do
      "bold" -> :bold
      "italic" -> :italic
      "bolditalic" -> :bold_italic
      _other -> :regular
    end
  end

  @doc """
  The files of a font, with a name for each style

  A tool reads them from its private directory.
  """
  @spec files(t()) :: [{String.t(), binary()}]
  def files(font), do: for({style, _name} <- @styles, do: {"font-#{style}.ttf", font[style]})

  @doc """
  The family and the style of a TTF file, from its `name` table

  The family is the name with the id 1, and the style is the name with the id
  2, such as `{"Atkinson Hyperlegible", "Bold"}`. The function prefers the
  names for Windows, in UTF-16, and it takes the names for the Mac when the
  file has no other.
  """
  @spec names(binary()) :: {String.t(), String.t()}
  def names(
        <<_version::32, count::16, _rest::binary-6, records::binary-size(count * 16), _::binary>> =
          ttf
      ) do
    table =
      for <<tag::binary-4, _checksum::32, offset::32, length::32 <- records>>,
          tag == "name",
          do: binary_part(ttf, offset, length)

    case table do
      [name] -> {name(name, 1), name(name, 2)}
      [] -> raise ArgumentError, "a TTF file has no name table"
    end
  end

  def names(_bytes), do: raise(ArgumentError, "a font file is not a TTF file")

  defp name(
         <<_format::16, count::16, start::16, records::binary-size(count * 12), _::binary>> =
           table,
         id
       ) do
    found =
      for <<platform::16, _encoding::16, _language::16, ^id::16, length::16,
            offset::16 <- records>>,
          platform in [1, 3],
          do: {platform, binary_part(table, start + offset, length)}

    case Enum.sort_by(found, fn {platform, _text} -> -platform end) do
      [{3, text} | _rest] -> :unicode.characters_to_binary(text, {:utf16, :big})
      [{1, text} | _rest] -> :unicode.characters_to_binary(text, :latin1)
      [] -> ""
    end
  end
end
