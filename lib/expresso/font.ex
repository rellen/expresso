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

  # One entry for each `@font-face` rule of the stylesheet: the font value that
  # `document.fonts.load()` takes, and one character of the `unicode-range` of
  # the rule. The browser loads only a face whose range holds the character.
  # A range can start at a control character, and the space is the first
  # character that a text can hold.
  @faces (for [_rule, body] <- Regex.scan(~r/@font-face\s*\{([^}]*)\}/, @source) do
            [_family, family] = Regex.run(~r/font-family:\s*("[^"]+")/, body)
            [_style, style] = Regex.run(~r/font-style:\s*([a-z]+)/, body)
            [_weight, weight] = Regex.run(~r/font-weight:\s*(\d+)/, body)
            [_range, start] = Regex.run(~r/unicode-range:\s*U\+([0-9A-Fa-f]+)/, body)
            sample = max(String.to_integer(start, 16), ?\s)
            ["#{style} #{weight} 1em #{family}", <<sample::utf8>>]
          end)

  @loader """
  if (document.fonts) {
    for (const [font, text] of #{Expresso.Json.for_script(@faces)}) {
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
  Give the number of files that the stylesheet holds

  A test reads this number, so a font file that no rule names gives a failure.
  """
  @spec file_count() :: non_neg_integer()
  def file_count, do: length(Regex.scan(@pattern, @source))
end
