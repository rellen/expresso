defmodule Expresso.LinkPreviewTest do
  # One test changes nothing outside its directory, but the capture of the
  # standard error is global, so the module does not run with other modules.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Expresso.Builder
  alias Expresso.LinkPreview
  alias Expresso.MediaFiles

  doctest LinkPreview

  @moduletag :tmp_dir

  @card "test/fixtures/dot.png"
  @icon "test/fixtures/badge.svg"
  @url "https://example.com/talk/"

  defp deck(options),
    do: Builder.deck([Builder.slide("one", heading: "One")], [name: "A talk"] ++ options)

  # The head of the document of a deck and the copies of its render, with the
  # directory `talk_files`.
  defp head(options) do
    {html, files} =
      MediaFiles.collect("talk_files", fn -> Expresso.Deck.render(deck(options)) end)

    [head, _body] = String.split(html, "<style>", parts: 2)
    {LazyHTML.from_fragment(head), html, files}
  end

  # The `content` of each `meta` element with a property or a name.
  defp content(document, key) do
    document
    |> LazyHTML.query(~s(meta[property="#{key}"], meta[name="#{key}"]))
    |> LazyHTML.attribute("content")
  end

  defp href(document, rel),
    do: document |> LazyHTML.query(~s(link[rel="#{rel}"])) |> LazyHTML.attribute("href")

  # A JPEG file of a width and a height: the start of the image, a segment
  # of an application, and the start of a frame.
  defp jpeg(width, height) do
    <<0xFF, 0xD8, 0xFF, 0xE0, 16::16, 0::size(112), 0xFF, 0xC2, 17::16, 8, height::16, width::16,
      3, 0::size(72)>>
  end

  describe "a deck with no option" do
    test "has no link, no Open Graph tag and no address of a network" do
      {document, html, files} = head([])

      assert LazyHTML.query(document, "link") |> Enum.to_list() == []
      assert LazyHTML.query(document, "meta[property]") |> Enum.to_list() == []
      assert content(document, "twitter:card") == []
      assert content(document, "robots") == []
      refute html =~ "http://"
      refute html =~ "https://"
      assert files == []
    end
  end

  describe "the url option" do
    test "gives the canonical address, the Open Graph tags and the kind of the card" do
      {document, _html, files} = head(url: @url, description: "A talk\nabout tags.")

      assert href(document, "canonical") == [@url]
      assert content(document, "og:type") == ["website"]
      assert content(document, "og:url") == [@url]
      assert content(document, "og:title") == ["A talk"]
      assert content(document, "og:description") == ["A talk about tags."]
      assert content(document, "twitter:card") == ["summary"]
      assert content(document, "og:image") == []
      assert files == []
    end

    test "a deck with no description has no og:description, and the title can come from a heading" do
      {html, _files} =
        MediaFiles.collect("talk_files", fn ->
          [Builder.slide("one", heading: "The first heading")]
          |> Builder.deck(url: @url)
          |> Expresso.Deck.render()
        end)

      assert html =~ ~s(<meta property="og:title" content="The first heading"/>)
      refute html =~ "og:description"
    end

    test "the address of the deck is the only address of a network in the document" do
      {_document, html, _files} = head(url: @url, card: @card)

      addresses = ~r{https?://[^"'\s<)]+} |> Regex.scan(html) |> List.flatten() |> Enum.uniq()

      assert Enum.sort(addresses) ==
               Enum.sort([
                 @url,
                 @url <> "talk_files/" <> MediaFiles.name(@card, File.read!(@card))
               ])
    end

    test "the document escapes each character of the address" do
      {_document, html, _files} = head(url: "https://example.com/talk/?a=1&b=2")

      assert html =~ ~s(href="https://example.com/talk/?a=1&amp;b=2")
      assert html =~ ~s(<meta property="og:url" content="https://example.com/talk/?a=1&amp;b=2"/>)
    end

    test "a language with a region gives og:locale, and a language with no region gives none" do
      for {lang, locale} <- [
            {"pt-BR", ["pt_BR"]},
            {"en-gb", ["en_GB"]},
            {"de", []},
            {"zh-Hant-TW", []}
          ] do
        {document, _html, _files} = head(url: @url, lang: lang)
        assert content(document, "og:locale") == locale, lang
      end
    end

    test "the option refuses a value that is not an absolute address" do
      for value <- ["example.com/talk", "/talk/", "ftp://example.com/", "https://", 5] do
        assert {:error, message} = LinkPreview.url(value)
        assert message =~ "the url option must be an address"
      end
    end
  end

  describe "the card option" do
    test "og:image holds the absolute address of a copy next to the document" do
      {document, html, files} = head(url: @url, card: [image: @card, alt: "The title slide"])
      name = MediaFiles.name(@card, File.read!(@card))

      assert content(document, "og:image") == [@url <> "talk_files/" <> name]
      assert content(document, "og:image:type") == ["image/png"]
      assert content(document, "og:image:width") == ["1"]
      assert content(document, "og:image:height") == ["1"]
      assert content(document, "og:image:alt") == ["The title slide"]
      assert content(document, "twitter:card") == ["summary_large_image"]
      assert files == [{"talk_files/" <> name, File.read!(@card)}]
      # The picture is not in the document as a data URI.
      refute html =~ Base.encode64(File.read!(@card))
    end

    test "the address of the picture is relative to the address of the deck, as in a browser" do
      name = MediaFiles.name(@card, File.read!(@card))

      for {url, image} <- [
            {"https://example.com/talk/index.html", "https://example.com/talk/talk_files/"},
            {"https://example.com/", "https://example.com/talk_files/"},
            {"https://example.com/talk", "https://example.com/talk_files/"}
          ] do
        {document, _html, _files} = head(url: url, card: @card)
        assert content(document, "og:image") == [image <> name], url
      end
    end

    test "a card with no alt text has no og:image:alt", %{tmp_dir: dir} do
      path = Path.join(dir, "card.jpg")
      File.write!(path, jpeg(1200, 630))
      {document, _html, _files} = head(url: @url, card: path)

      assert content(document, "og:image:alt") == []
      assert content(document, "og:image:type") == ["image/jpeg"]
      assert content(document, "og:image:width") == ["1200"]
      assert content(document, "og:image:height") == ["630"]
    end

    test "a file with no header of a picture gives no width and no height", %{tmp_dir: dir} do
      path = Path.join(dir, "card.png")
      File.write!(path, "not a picture")
      {document, _html, _files} = head(url: @url, card: path)

      assert content(document, "og:image:width") == []
      assert [_address] = content(document, "og:image")
    end

    test "a card with no url option is an error at compile time, and in the render" do
      assert_raise Spark.Error.DslError, ~r/the card option needs the url option/, fn ->
        capture_io(:stderr, fn -> deck(card: @card) end)
      end

      # A program can put the value into the metadata of a deck.
      plain = deck([])
      made = %{plain | metadata: Map.put(plain.metadata, :card, %{image: @card, alt: nil})}

      assert_raise ArgumentError, LinkPreview.card_needs_url(), fn ->
        MediaFiles.collect("talk_files", fn -> Expresso.Deck.render(made) end)
      end
    end

    test "the render raises with no directory, and the error names the card option" do
      assert_raise ArgumentError,
                   ~r/the card image "#{@card}" needs an address.*remove the card option/s,
                   fn ->
                     Expresso.Deck.render(deck(url: @url, card: @card))
                   end
    end

    test "a missing file stops the render, and the message tells how to make it" do
      assert_raise ArgumentError, LinkPreview.missing_card("no/such.png"), fn ->
        head(url: @url, card: "no/such.png")
      end

      assert LinkPreview.missing_card("no/such.png") =~
               ~s(the card image "no/such.png" does not exist. ) <>
                 "Make it from a slide of the deck with the export option --card no/such.png."
    end

    test "a file that the render cannot read for a different reason gives the reason",
         %{tmp_dir: dir} do
      path = Path.join(dir, "card.png")
      File.mkdir!(path)

      message = Expresso.DeckFile.read_error(path, "card image", :eisdir)
      assert_raise ArgumentError, message, fn -> head(url: @url, card: path) end
    end

    test "Expresso.main/2 stops for a missing card, and writes no document", %{tmp_dir: dir} do
      input = Path.join(dir, "deck.exs")
      output = Path.join(dir, "index.html")
      card = Path.join(dir, "card.png")

      File.write!(input, """
      import Expresso.Builder

      deck([slide("one", heading: "One")], name: "deck", url: #{inspect(@url)}, card: #{inspect(card)})
      """)

      assert_raise ArgumentError, LinkPreview.missing_card(card), fn ->
        Expresso.main(input, output)
      end

      refute File.exists?(output)
    end

    test "the option refuses a file of a different type, and a list with a different key" do
      for value <- ["card.svg", "card.gif", [image: "card.png", title: "x"], [alt: "x"], 5] do
        assert {:error, message} = LinkPreview.card(value)
        assert message =~ "the card option must be the path"
      end
    end

    test "Expresso.main/2 writes the copy next to the output file", %{tmp_dir: dir} do
      input = Path.join(dir, "deck.exs")

      File.write!(input, """
      import Expresso.Builder

      deck([slide("one", heading: "One")],
        name: "deck",
        url: #{inspect(@url)},
        card: #{inspect(Path.expand(@card))}
      )
      """)

      assert Expresso.main(input, Path.join(dir, "index.html")) == :ok
      name = MediaFiles.name(@card, File.read!(@card))

      assert File.ls!(Path.join(dir, "index_files")) == [name]
      assert File.read!(Path.join(dir, "index.html")) =~ ~s(content="#{@url}index_files/#{name}")
    end
  end

  describe "the favicon option" do
    test "the icon goes into the document as a data URI, with its type" do
      {document, _html, files} = head(favicon: @icon)

      assert href(document, "icon") == [
               "data:image/svg+xml;base64," <> Base.encode64(File.read!(@icon))
             ]

      assert document |> LazyHTML.query(~s(link[rel="icon"])) |> LazyHTML.attribute("type") ==
               ["image/svg+xml"]

      assert files == []
    end

    test "a PNG file has its own type" do
      {document, _html, _files} = head(favicon: @card)

      assert ["data:image/png;base64," <> _data] = href(document, "icon")
    end

    test "a file that the render cannot read stops the render with its path" do
      assert_raise ArgumentError, ~r|cannot read the favicon "no/such.svg"|, fn ->
        head(favicon: "no/such.svg")
      end
    end
  end

  describe "the robots option" do
    test "gives the tag with the directives" do
      {document, _html, _files} = head(robots: " noindex, nofollow ")

      assert content(document, "robots") == ["noindex, nofollow"]
    end
  end

  describe "the DSL" do
    test "takes each option, and it joins the path of the card and of the icon to the root" do
      defmodule PreviewDeck do
        use Expresso

        name "preview"
        root "test/fixtures"
        url("https://example.com/talk/")
        card(image: "dot.png", alt: "A dot")
        favicon("badge.svg")
        robots("noindex")

        slide "one" do
          heading "One"
        end
      end

      {html, files} =
        MediaFiles.collect("d_files", fn -> Expresso.Deck.render(Expresso.parse(PreviewDeck)) end)

      name = MediaFiles.name(@card, File.read!(@card))

      assert files == [{"d_files/" <> name, File.read!(@card)}]

      assert html =~
               ~s(<meta property="og:image" content="https://example.com/talk/d_files/#{name}"/>)

      assert html =~ ~s(<meta property="og:image:alt" content="A dot"/>)
      assert html =~ ~s(<link rel="icon" type="image/svg+xml" href="data:image/svg+xml;base64,)
      assert html =~ ~s(<meta name="robots" content="noindex"/>)
    end
  end

  describe "dimensions/1" do
    test "reads a JPEG file with a segment in front of the frame, and returns nil for a cut file" do
      assert LinkPreview.dimensions(jpeg(1200, 630)) == {1200, 630}
      assert LinkPreview.dimensions(binary_part(jpeg(1200, 630), 0, 12)) == nil
      assert LinkPreview.dimensions(<<0xFF, 0xD8>>) == nil
    end
  end
end
