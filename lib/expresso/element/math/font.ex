defmodule Expresso.Element.Math.Font do
  @moduledoc """
  The math font of a deck, and the style sheet of Temml for it

  The deck option `math_font` takes one of `names/0`. `Expresso.Renderer` writes
  `css/1` into a `style` element of a document with a `math` element, so a
  deck with no formula holds no math font.

  Temml gives one style sheet for each font, in `priv/temml/css/`, with rules
  for its classes and the sizes of its stretched accents. `priv/fonts/math/`
  holds the font files, their licenses and the file `SOURCE`. `css/1` replaces
  each `url()` of a font file with a data URI of the file, because the
  document is one file. The font `:system` holds no math font, and the
  browser takes a math font of the computer.

  The text of `\\text{…}` in a formula, an `mtext`, takes the font of the
  slide, from the custom property `--font-text` of the theme.
  """

  # The style sheet of Temml for each font, and the file of the deck for each
  # file that the style sheet names. Each style sheet also names `Temml.woff2`.
  @fonts %{
    latin_modern:
      {"Temml-Latin-Modern.css", %{"latinmodernmath.woff2" => "latinmodernmath.woff2"}},
    stix: {"Temml-STIX2.css", %{"STIXTwoMath.woff2" => "STIXTwoMath.woff2"}},
    libertinus:
      {"Temml-Libertinus.css",
       %{"LibertinusMath-Regular.woff2" => "LibertinusMath-Regular.woff2"}},
    noto: {"Temml-NotoSans.css", %{"NotoSansMath-Regular.ttf" => "NotoSansMath-Regular.woff2"}},
    system: {"Temml-Local.css", %{}}
  }

  @names [:latin_modern, :stix, :libertinus, :noto, :system]

  # Each `url()` of a font file. The rule of `\cancelto` holds a data URI with
  # an SVG, and that SVG holds `url(%23a)`, so the pattern takes only the name
  # of a font file.
  @url ~r/url\(\s*['"]?(?:\.\/)?([\w.-]+\.(?:woff2|woff|ttf))['"]?\s*\)/

  @text_rule """
  .math mtext {
    font-family: var(--font-text);
  }
  """

  @doc "The names of the math fonts, with the default first"
  @spec names() :: [atom()]
  def names, do: @names

  @doc "The math font of a deck without the `math_font` option"
  @spec default() :: atom()
  def default, do: :latin_modern

  @doc """
  The style sheet of a math font, with a data URI of each of its files

  The function raises for a style sheet that names a file that the deck does
  not have.
  """
  @spec css(atom()) :: String.t()
  # The name of each file comes from the table of this module, and not from a
  # user.
  # sobelow_skip ["Traversal.FileModule"]
  def css(name) do
    {sheet, files} = Map.fetch!(@fonts, name)
    files = Map.put(files, "Temml.woff2", "Temml.woff2")
    source = File.read!(Path.join(dir(:css), sheet))

    Regex.replace(@url, source, fn _match, file ->
      case files do
        %{^file => own} ->
          "url(\"#{data_uri(own)}\")"

        _files ->
          raise ArgumentError, "#{sheet} names the font file #{file}, and the deck has none"
      end
    end) <> "\n" <> @text_rule
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp data_uri(file) do
    bytes = File.read!(Path.join(dir(:fonts), file))
    "data:font/woff2;base64," <> Base.encode64(bytes)
  end

  defp dir(:css), do: Application.app_dir(:expresso, "priv/temml/css")
  defp dir(:fonts), do: Application.app_dir(:expresso, "priv/fonts/math")
end
