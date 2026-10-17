defmodule Expresso.Element.EmbedTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Embed
  alias Expresso.Presenter.Schema.Check

  doctest Embed

  defmodule EmbedDeck do
    use Expresso

    slide "one" do
      embed "test/fixtures/page.html" do
        title "A page that counts"
        fallback("test/fixtures/dot.png")
        width "60%"
        aspect("4/3")
      end
    end

    slide "two" do
      columns do
        column do
          embed "https://example.com/a?b=c&d=e" do
            title "An example page"
            interactive(true)
          end
        end
      end
    end
  end

  defp deck, do: Expresso.parse(EmbedDeck)
  defp document, do: deck() |> document()

  describe "the document" do
    test "writes no source on a frame, and each frame names its embed" do
      document = document()
      frames = count(document, "iframe.embed-frame")

      assert frames > 0
      assert count(document, "iframe.embed-frame:not([src]):not([srcdoc])") == frames

      assert document
             |> screen("iframe")
             |> Enum.map(&LazyHTML.attribute(&1, "data-embed")) ==
               [["0"], ["1"]]
    end

    test "writes the source of each embed one time, in the order of the numbers" do
      [block] = document() |> LazyHTML.query("script#expresso-embeds") |> Enum.to_list()
      text = LazyHTML.text(block)

      refute text =~ "<"
      assert [local, address] = JSON.decode!(text)
      assert local["kind"] == "srcdoc"
      assert local["value"] == File.read!("test/fixtures/page.html")
      assert address == %{"kind" => "src", "value" => "https://example.com/a?b=c&d=e"}
      assert Check.check(JSON.decode!(text), :written_embeds) == :ok
    end

    test "gives a local page scripts only, and a page of the network its own origin" do
      [local, address] = document() |> screen("iframe") |> Enum.to_list()

      assert LazyHTML.attribute(local, "sandbox") == ["allow-scripts"]
      assert LazyHTML.attribute(address, "sandbox") == ["allow-scripts allow-same-origin"]
      assert LazyHTML.attribute(local, "referrerpolicy") == ["no-referrer"]
    end

    test "keeps the key Tab out of a frame that is not interactive" do
      [local, address] = document() |> screen("iframe") |> Enum.to_list()

      assert LazyHTML.attribute(local, "tabindex") == ["-1"]
      assert LazyHTML.attribute(local, "data-interactive") == []
      assert LazyHTML.attribute(address, "tabindex") == []
      assert LazyHTML.attribute(address, "data-interactive") != []
    end

    test "writes the title on the frame and on the fallback, and a placeholder without a fallback" do
      [local, address] = document() |> screen(".embed") |> Enum.to_list()

      assert local |> LazyHTML.query("img.embed-fallback") |> LazyHTML.attribute("alt") == [
               "A page that counts"
             ]

      assert local |> LazyHTML.query("iframe") |> LazyHTML.attribute("title") == [
               "A page that counts"
             ]

      assert address |> LazyHTML.query(".embed-placeholder") |> LazyHTML.text() =~
               "An example page"

      assert texts(address, ".embed-address") == ["https://example.com/a?b=c&d=e"]
    end

    test "writes the width as a viewport unit, and the ratio" do
      [local, _address] = document() |> screen(".embed") |> Enum.to_list()

      assert LazyHTML.attribute(local, "style") == ["--embed-width: 60vw; --embed-aspect: 4/3"]
    end

    test "a deck with no embed gets no block of sources" do
      html =
        [Builder.slide("one", elements: [Builder.text_area(text: "a")])]
        |> Builder.deck()
        |> Expresso.Deck.render()

      assert html |> LazyHTML.from_document() |> count("body:not(:has(script#expresso-embeds))") ==
               1
    end

    test "raises for a local page that it cannot read" do
      message = Expresso.DeckFile.read_error("no/such.html", "page", :enoent)

      assert_raise ArgumentError, message, fn ->
        [Builder.slide("one", elements: [Builder.embed("no/such.html", title: "x")])]
        |> Builder.deck()
        |> Expresso.Deck.render()
      end
    end

    test "records a local page for the watch mode" do
      deck = deck()
      {_html, paths} = Expresso.DeckFile.track(fn -> Expresso.Deck.render(deck) end)

      assert "test/fixtures/page.html" in paths
    end
  end

  describe "number/1" do
    test "counts the embeds of the deck in document order" do
      embeds =
        deck()
        |> Embed.number()
        |> Map.get(:slides)
        |> Enum.flat_map(&tree(&1.elements))
        |> Enum.filter(&is_struct(&1, Embed))

      assert Enum.map(embeds, & &1.index) == [0, 1]
    end
  end

  describe "the options" do
    test "source/1 refuses each value that is not an address or an HTML file" do
      for value <- [
            "ftp://example.com/",
            "javascript:alert(1)",
            "page.txt",
            "c:/page.html",
            "https://a b",
            ~s(https://a"b),
            :page
          ] do
        assert {:error, _message} = Embed.source(value), inspect(value)
      end
    end

    test "aspect/1 takes two positive numbers with a slash" do
      assert Embed.aspect(" 16 / 9 ") == {:ok, "16/9"}
      assert Embed.aspect("2.35/1") == {:ok, "2.35/1"}

      for value <- ["16:9", "0/9", "16/0", "16", "a/b", 1.5] do
        assert {:error, _message} = Embed.aspect(value), inspect(value)
      end
    end

    test "the compiler needs a title" do
      source = """
      defmodule Expresso.Element.EmbedTest.NoTitle do
        use Expresso

        slide "one" do
          embed "https://example.com/"
        end
      end
      """

      error = assert_raise Spark.Error.DslError, fn -> Code.compile_string(source) end
      assert Exception.message(error) =~ "title"
    end
  end

  defp tree(elements),
    do: Enum.flat_map(elements, &[&1 | tree(Map.get(&1, :elements) || [])])
end
