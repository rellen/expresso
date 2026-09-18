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

  @doc """
  Give the stylesheet of the font, with the bytes of each file in it

  `Expresso.Renderer` writes the result into a `style` element of the document.
  """
  @spec css() :: String.t()
  def css, do: @css

  @doc """
  Give the number of files that the stylesheet holds

  A test reads this number, so a font file that no rule names gives a failure.
  """
  @spec file_count() :: non_neg_integer()
  def file_count, do: length(Regex.scan(@pattern, @source))
end
