defmodule Expresso.Font do
  @moduledoc """
  The font of the theme, with the bytes of each file in the stylesheet

  The document of a deck is one file, and a font cannot be a second file. This
  module reads `assets/fonts.css` at compile time. It replaces the path of each
  `url()` with a data URI of the file, so a browser needs no network for the
  font.

  Atkinson Hyperlegible is the font, and the Braille Institute of America gives
  it under the SIL Open Font License, Version 1.1. `assets/fonts/OFL.txt` holds
  that license, and the license permits this use.

  A browser starts to load a font only when a layout needs it. The first
  layout of the document can thus have the fallback font, and the text moves
  when the font comes. `loader/0` returns a script that starts the load of
  each face before the browser reads the body.
  """

  @external_resource "./assets/fonts.css"

  for file <- Path.wildcard("./assets/fonts/*.woff2") do
    @external_resource file
  end

  @source File.read!("./assets/fonts.css")

  @pattern ~r/url\("([^"]+)"\)/

  @css Regex.replace(@pattern, @source, fn _match, path ->
         bytes = File.read!(Path.join("./assets", path))
         "url(\"data:font/woff2;base64," <> Base.encode64(bytes) <> "\")"
       end)

  # The rules of the stylesheet in sequence. Each one holds:
  #
  # - `text`, the rule in `@css`, with the comment that names its range,
  # - `ranges`, the code points of its `unicode-range`, as a list of
  #   `{first, last}`,
  # - `face`, the font value that `document.fonts.load()` takes, and one
  #   character of the ranges. The browser loads only a face whose range
  #   holds the character. A range can start at a control character, and the
  #   space is the first character that a text can hold.
  # - `always`, which is true for a rule whose ranges hold the space. Each
  #   document needs such a face.
  @rules (for [text, body] <-
                Regex.scan(~r/(?:\/\* [a-z-]+ \*\/\n)?@font-face\s*\{([^}]*)\}\n?/, @css) do
            [_family, family] = Regex.run(~r/font-family:\s*("[^"]+")/, body)
            [_style, style] = Regex.run(~r/font-style:\s*([a-z]+)/, body)
            [_weight, weight] = Regex.run(~r/font-weight:\s*(\d+)/, body)
            [_range, list] = Regex.run(~r/unicode-range:\s*([^;]+);/, body)

            # A part is one code point, such as `U+0131`, or a range, such as
            # `U+0100-02BA`.
            ranges =
              for part <- String.split(list, ","), part = String.trim(part) do
                case String.split(String.trim_leading(part, "U+"), "-") do
                  [point] -> {String.to_integer(point, 16), String.to_integer(point, 16)}
                  [first, last] -> {String.to_integer(first, 16), String.to_integer(last, 16)}
                end
              end

            [{start, _last} | _ranges] = ranges

            %{
              text: text,
              ranges: ranges,
              face: ["#{style} #{weight} 1em #{family}", <<max(start, ?\s)::utf8>>],
              always: Enum.any?(ranges, fn {first, last} -> ?\s in first..last end)
            }
          end)

  # The text of the stylesheet in front of its first rule: the comment with
  # the copyright notice of the font.
  @header @css |> String.split(hd(@rules).text, parts: 2) |> hd()

  @loader """
  if (document.fonts) {
    for (const [font, text] of #{Expresso.Json.for_script(Enum.map(@rules, & &1.face))}) {
      document.fonts.load(font, text).catch(() => {});
    }
  }
  """

  @doc """
  Give the stylesheet of the font, with the bytes of each file in it

  `Expresso.Renderer` writes the result into a `style` element of the document.
  """
  @spec css() :: String.t()
  def css, do: @css

  @doc """
  Give the script that starts the load of each face of the font

  `Expresso.Renderer` writes the result into a `script` element of the `head`,
  after the stylesheet of the font. Without the script, the first layout of
  the document can have the fallback font. The text then moves when the font
  replaces it, and a heading can change its number of lines.

      iex> Expresso.Font.loader() =~ ~s(["normal 400 1em \\"Atkinson Hyperlegible\\"", " "])
      true
  """
  @spec loader() :: String.t()
  def loader, do: @loader

  @doc """
  Remove from a document each face of the font that no character of the
  document needs

  Each document needs the faces whose `unicode-range` holds the space: the
  Latin files. A different face, such as a Latin Extended file, stays only
  when the document holds a character of its range, such as `ő`. The function
  looks at the whole document, with each script and each JSON element, so a
  text that the presenter writes later also counts. It also reads a character
  reference such as `&#337;` and an escape such as `\\u0151` or `\\151`.

  The function removes the `@font-face` rule of each such face and its entry
  in the script of `loader/0`. A document with no stylesheet of this module
  stays as it is.

      iex> html = "<style>" <> Expresso.Font.css() <> "</style><script>" <> Expresso.Font.loader() <> "</script><p>Hello</p>"
      iex> length(String.split(Expresso.Font.trim(html), "@font-face")) - 1
      4
      iex> length(String.split(Expresso.Font.trim(html <> "<p>Erdős</p>"), "@font-face")) - 1
      8
  """
  @spec trim(String.t()) :: String.t()
  def trim(html) do
    with [before, rest] <- String.split(html, @loader, parts: 2),
         kept = kept([before, rest]),
         true <- length(kept) < length(@rules) do
      css = IO.iodata_to_binary([@header | Enum.map(kept, & &1.text)])

      IO.iodata_to_binary([
        String.replace(before, @css, css, global: false),
        loader(Enum.map(kept, & &1.face)),
        rest
      ])
    else
      _no_change -> html
    end
  end

  defp loader(faces) do
    String.replace(
      @loader,
      Expresso.Json.for_script(Enum.map(@rules, & &1.face)),
      Expresso.Json.for_script(faces),
      global: false
    )
  end

  # The rules that the parts of a document need. Rules with the same ranges
  # get one search.
  defp kept(parts) do
    needed =
      @rules
      |> Enum.reject(& &1.always)
      |> Enum.map(& &1.ranges)
      |> Enum.uniq()
      |> Map.new(&{&1, Enum.any?(parts, fn part -> holds?(part, &1) end)})

    Enum.filter(@rules, &(&1.always or needed[&1.ranges]))
  end

  # True when a text holds a character of the ranges, as the character or as
  # an escape. A text that is not UTF-8 gives true, so its faces stay.
  #
  # The pattern holds only the code points of a `unicode-range` of
  # `assets/fonts.css`, which this module reads at compile time. No part of
  # it comes from a deck or from a user.
  # sobelow_skip ["DOS.Regex"]
  defp holds?(text, ranges) do
    class = Enum.map_join(ranges, fn {first, last} -> "\\x{#{hex(first)}}-\\x{#{hex(last)}}" end)

    case Regex.compile!("[" <> class <> "]", "u") |> Regex.run(text, return: :index) do
      nil -> escaped?(text, ranges)
      _found -> true
    end
  rescue
    _not_utf8 -> true
  end

  # A character reference of HTML, an escape of JavaScript and an escape of
  # CSS, each with its code point in hexadecimal or in decimal digits.
  defp escaped?(text, ranges) do
    ~r/&#(x?)([0-9a-fA-F]+);|\\u\{([0-9a-fA-F]{1,6})\}|\\u([0-9a-fA-F]{4})|\\([0-9a-fA-F]{2,6})/
    |> Regex.scan(text, capture: :all_but_first)
    |> Enum.any?(fn groups -> groups |> code_point() |> in_ranges?(ranges) end)
  end

  defp code_point(["", digits]), do: String.to_integer(digits)
  defp code_point(groups), do: groups |> List.last() |> String.to_integer(16)

  defp in_ranges?(code, ranges),
    do: Enum.any?(ranges, fn {first, last} -> code in first..last end)

  defp hex(code), do: Integer.to_string(code, 16)

  @doc """
  Give the number of files that the stylesheet holds

  A test reads this number, so a font file that no rule names gives a failure.
  """
  @spec file_count() :: non_neg_integer()
  def file_count, do: length(Regex.scan(@pattern, @source))
end
