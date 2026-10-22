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
  The advance width of each character of `text` in each style of a font

  The width is a part of the size of the font, such as `0.55` for a character
  that is a little more than half of an em wide. The keys of the result are
  the styles of Pele: `0` regular, `1` bold, `2` italic and `3` bold italic.
  Each style maps the code point of a character to its width. A character that
  the font does not have is not in the map, and a measurer gives it a default
  width. The widths ignore kerning.

  `Expresso.Element.Diagram.Pele` gives the widths to its measurer, so Pele
  sizes each box for the text in the font of the slide.
  """
  @spec advances(t(), String.t()) :: %{String.t() => %{String.t() => float()}}
  def advances(font, text) do
    codes = text |> String.to_charlist() |> Enum.uniq() |> Enum.sort()

    for {key, style} <- [{"0", :regular}, {"1", :bold}, {"2", :italic}, {"3", :bold_italic}],
        into: %{} do
      {key, widths(font[style], codes)}
    end
  end

  defp widths(ttf, codes) do
    tables = tables(ttf)
    <<_::binary-18, units::16, _::binary>> = tables["head"]
    <<_::binary-34, metrics::16, _::binary>> = tables["hhea"]
    hmtx = tables["hmtx"]
    glyph = glyph_finder(tables["cmap"])

    for code <- codes, id = glyph.(code), id != 0, into: %{} do
      advance = u16(hmtx, min(id, metrics - 1) * 2)
      {Integer.to_string(code), Float.round(advance / units, 4)}
    end
  end

  defp tables(
         <<_version::32, count::16, _rest::binary-6, records::binary-size(count * 16), _::binary>> =
           ttf
       ) do
    for <<tag::binary-4, _checksum::32, offset::32, length::32 <- records>>, into: %{} do
      {tag, binary_part(ttf, offset, length)}
    end
  end

  # The function that gives the glyph of a code point, from the subtable of the
  # `cmap` for Unicode: format 12 for each code point, or format 4 for the
  # basic plane.
  defp glyph_finder(
         <<_version::16, count::16, records::binary-size(count * 8), _::binary>> = cmap
       ) do
    subtables =
      for <<platform::16, encoding::16, offset::32 <- records>>,
          {platform, encoding} in [{3, 10}, {0, 4}, {3, 1}, {0, 3}],
          do: binary_part(cmap, offset, byte_size(cmap) - offset)

    subtables =
      subtables
      |> Enum.map(&{u16(&1, 0), &1})
      |> Enum.filter(fn {format, _subtable} -> format in [4, 12] end)

    case Enum.sort_by(subtables, fn {format, _subtable} -> -format end) do
      [{12, subtable} | _rest] -> &format12(subtable, &1)
      [{4, subtable} | _rest] -> &format4(subtable, &1)
      [] -> raise ArgumentError, "a TTF file has no cmap for Unicode"
    end
  end

  defp format12(<<12::16, _::binary-10, groups::32, rest::binary>>, code) do
    found =
      for <<start::32, stop::32, glyph::32 <- binary_part(rest, 0, groups * 12)>>,
          code >= start and code <= stop,
          do: glyph + code - start

    List.first(found, 0)
  end

  defp format4(
         <<4::16, _length::16, _language::16, double::16, _::binary-6, rest::binary>> = table,
         code
       )
       when code <= 0xFFFF do
    count = div(double, 2)

    <<ends::binary-size(^double), _pad::16, starts::binary-size(^double),
      deltas::binary-size(^double), _::binary>> = rest

    offsets_at = 16 + 3 * double

    0..(count - 1)
    |> Enum.find(fn index -> code <= u16(ends, index) end)
    |> case do
      nil ->
        0

      index ->
        start = u16(starts, index)
        offset = u16(binary_part(table, offsets_at, double), index)
        format4_glyph(table, code, index, start, offset, u16(deltas, index), offsets_at)
    end
  end

  defp format4(_table, _code), do: 0

  defp format4_glyph(_table, code, _index, start, _offset, _delta, _at) when code < start, do: 0

  defp format4_glyph(_table, code, _index, _start, 0, delta, _at),
    do: rem(code + delta, 65_536)

  defp format4_glyph(table, code, index, start, offset, delta, at) do
    glyph = u16(table, div(at + index * 2 + offset + (code - start) * 2, 2))
    if glyph == 0, do: 0, else: rem(glyph + delta, 65_536)
  end

  # The unsigned 16-bit number at the index of a table of such numbers.
  defp u16(binary, index), do: binary |> binary_part(index * 2, 2) |> :binary.decode_unsigned()

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
