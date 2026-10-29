defmodule Expresso.Element.MathFontTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Math.Font

  # The family of the math font that the style sheet of each font names.
  @families %{
    latin_modern: "Latin Modern Math",
    stix: "STIX2",
    libertinus: "Libertinus Math",
    noto: "NotoSans Math"
  }

  defp math_deck(opts \\ []) do
    Builder.deck(
      [Builder.slide("a", elements: [Builder.math(~S(<math><mi>x</mi></math>))])],
      opts
    )
  end

  defp head_styles(deck) do
    deck |> Expresso.Deck.render() |> LazyHTML.from_document() |> texts("head style")
  end

  describe "css/1" do
    test "gives each font a data URI of each of its files, and no other url of a file" do
      for name <- Font.names() do
        css = Font.css(name)

        assert css =~ ~s(url("data:font/woff2;base64,), inspect(name)
        refute css =~ ~r/url\(['"]?\.?\/?[\w.-]+\.(woff2|woff|ttf)/, inspect(name)
        assert css =~ ".math mtext {\n  font-family: var(--font-text);", inspect(name)
      end
    end

    test "keeps the data URI of the SVG of \\cancelto" do
      assert Font.css(:latin_modern) =~ "url(%23a)"
    end

    test "names the family of the math font of each font, and :system holds the Temml font only" do
      for {name, family} <- @families do
        assert Font.css(name) =~ family, inspect(name)
      end

      assert length(Regex.scan(~r/data:font\/woff2/, Font.css(:system))) == 1
      assert length(Regex.scan(~r/data:font\/woff2/, Font.css(:latin_modern))) == 2
    end
  end

  describe "the files" do
    test "each font has its file and its license, and SOURCE names each file" do
      source = File.read!("priv/fonts/math/SOURCE")

      for file <-
            ~w(latinmodernmath.woff2 STIXTwoMath.woff2 LibertinusMath-Regular.woff2
               NotoSansMath-Regular.woff2 Temml.woff2 GUST-FONT-LICENSE.txt OFL-STIX.txt
               OFL-Libertinus.txt OFL-Noto.txt) do
        assert File.regular?(Path.join("priv/fonts/math", file)), file
        assert source =~ file, file
      end

      assert File.read!("priv/fonts/math/GUST-FONT-LICENSE.txt") =~ "GUST Font License"

      for file <- ~w(OFL-STIX.txt OFL-Libertinus.txt OFL-Noto.txt) do
        assert File.read!(Path.join("priv/fonts/math", file)) =~ "SIL Open Font License", file
      end
    end
  end

  describe "the document" do
    test "a deck with a math element holds the math font of its option" do
      assert Enum.any?(head_styles(math_deck()), &(&1 =~ "Latin Modern Math"))
      assert Enum.any?(head_styles(math_deck(math_font: :stix)), &(&1 =~ "STIX2"))
      refute Enum.any?(head_styles(math_deck(math_font: :stix)), &(&1 =~ "Latin Modern Math"))
    end

    test "a deck without a math element holds no math font" do
      deck = Builder.deck([Builder.slide("a", elements: [Builder.text_area(text: "x")])])
      refute Enum.any?(head_styles(deck), &(&1 =~ "Temml"))
    end

    test "a math element in a box also brings the font" do
      math = Builder.math(~S(<math><mi>x</mi></math>))
      deck = Builder.deck([Builder.slide("a", elements: [Builder.text_box(elements: [math])])])
      assert Enum.any?(head_styles(deck), &(&1 =~ "Latin Modern Math"))
    end

    test "the deck option takes one of the five fonts" do
      assert math_deck().metadata.math_font == :latin_modern
      assert math_deck(math_font: :noto).metadata.math_font == :noto

      assert_raise ArgumentError, ~r/invalid value for :math_font option/, fn ->
        math_deck(math_font: :comic)
      end
    end
  end
end
