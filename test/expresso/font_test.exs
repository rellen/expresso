defmodule Expresso.FontTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Font

  describe "css/0" do
    test "holds the bytes of each file of the stylesheet" do
      assert length(Regex.scan(~r/url\("data:font\/woff2;base64,/, Font.css())) ==
               Font.file_count()
    end

    test "gives each url a data URI, and no address of a network" do
      schemes =
        ~r/url\("([a-z]+):/
        |> Regex.scan(Font.css(), capture: :all_but_first)
        |> List.flatten()
        |> Enum.uniq()

      assert schemes == ["data"]
      refute Font.css() =~ "fonts.googleapis.com"
      refute Font.css() =~ "fonts.gstatic.com"
    end

    test "keeps the rules of the stylesheet" do
      assert Font.css() =~ ~s(font-family: "Atkinson Hyperlegible")
      assert Font.css() =~ "unicode-range:"
    end

    test "gives bytes that decode" do
      [[_, encoded] | _] = Regex.scan(~r/base64,([^"]+)"/, Font.css())

      assert {:ok, bytes} = Base.decode64(encoded)
      # Each woff2 file starts with the signature `wOF2`.
      assert <<"wOF2", _rest::binary>> = bytes
    end
  end

  describe "loader/0" do
    test "starts the load of one face for each file of the stylesheet" do
      [_all, list] = Regex.run(~r/of (\[\[.*\]\])\) \{/, Font.loader())
      faces = JSON.decode!(list)

      assert length(faces) == Font.file_count()
      assert Enum.uniq(faces) == faces

      for style <- ["normal", "italic"], weight <- ["400", "700"], text <- [" ", "Ā"] do
        assert [~s(#{style} #{weight} 1em "Atkinson Hyperlegible"), text] in faces
      end
    end

    test "gives each face a character of its unicode range" do
      [_all, list] = Regex.run(~r/of (\[\[.*\]\])\) \{/, Font.loader())

      # The range of the Latin file starts at U+0000, which a text cannot
      # hold, so its character is the space.
      assert list |> JSON.decode!() |> Enum.map(&List.last/1) |> Enum.uniq() == [" ", "Ā"]
    end

    test "does nothing in a browser with no font loading API" do
      assert Font.loader() =~ "if (document.fonts) {"
    end
  end

  describe "trim/1" do
    # A document with the stylesheet, the script and a text.
    defp document(text) do
      "<style>" <> Font.css() <> "</style><script>" <> Font.loader() <> "</script><p>#{text}</p>"
    end

    defp rules(html), do: length(String.split(html, "@font-face")) - 1

    defp entries(html) do
      [_all, list] = Regex.run(~r/of (\[\[.*\]\])\) \{/, html)
      JSON.decode!(list)
    end

    test "removes the Latin Extended faces from a document with no character of their range" do
      html = Font.trim(document("A text of ASCII, with é, ü and “quotes”."))

      assert rules(html) == 4
      assert Enum.map(entries(html), &List.last/1) |> Enum.uniq() == [" "]
      assert length(entries(html)) == 4
      refute html =~ "latin-ext"
      # The copyright notice of the font stays.
      assert html =~ "Copyright 2020 Braille Institute of America"
      assert html =~ "<p>A text of ASCII"
    end

    test "makes the document smaller by the data URIs of four files" do
      html = document("Hello")

      sizes =
        for file <- Path.wildcard("assets/fonts/*-latin-ext.woff2"), do: File.stat!(file).size

      assert length(sizes) == 4
      assert byte_size(html) - byte_size(Font.trim(html)) > Enum.sum(sizes) * 4 / 3
    end

    test "keeps each face for a document with a character of Latin Extended" do
      for text <- ["Erdős", "Łódź", "Ș", "ẞ"] do
        html = document(text)
        assert Font.trim(html) == html, text
      end
    end

    test "keeps each face for a character that the two ranges hold" do
      # U+0308 is a combining mark, and the two ranges hold it. A rule later
      # in the stylesheet has precedence, so the browser reads the Latin
      # Extended file first.
      html = document("a\u0308")
      assert Font.trim(html) == html
    end

    test "reads a character reference and an escape of JavaScript and of CSS" do
      for text <- ["&#337;", "&#x151;", ~S(\u0151), ~S(\u{151}), ~S(content: "\151 ")] do
        html = document(text)
        assert Font.trim(html) == html, text
      end

      for text <- ["&#233;", "&#xe9;", ~S(\u00e9), ~S(\u003c), ~S(content: "\e9 ")] do
        assert rules(Font.trim(document(text))) == 4, text
      end
    end

    test "does not count the character of the script of loader/0" do
      # The script holds `Ā` as the character of the Latin Extended faces.
      assert Font.loader() =~ "Ā"
      assert rules(Font.trim(document("Hello"))) == 4
    end

    test "returns a document with no script of loader/0 as it is" do
      html = "<style>" <> Font.css() <> "</style><p>Hello</p>"
      assert Font.trim(html) == html
    end
  end

  describe "file_count/0" do
    test "counts each file that the stylesheet names" do
      files = Path.wildcard("assets/fonts/*.woff2")

      assert Font.file_count() == length(files)
      assert Font.file_count() > 0
    end
  end

  describe "the document" do
    test "starts the load of the font after its stylesheet and before the body" do
      html = Expresso.Example |> Expresso.parse() |> Expresso.Deck.render()

      [head, _body] = String.split(html, "</head>", parts: 2)
      {rules, _} = :binary.match(head, "@font-face")
      {script, _} = :binary.match(head, "document.fonts.load(font, text)")

      assert rules < script
      assert length(String.split(html, "document.fonts.load(")) == 2
    end

    test "holds four faces for a deck with no character of Latin Extended, and eight with one" do
      plain = Expresso.Example |> Expresso.parse() |> Expresso.Deck.render()

      extended =
        [Builder.slide("one", heading: "Paul Erdős")] |> Builder.deck() |> Expresso.Deck.render()

      assert length(Regex.scan(~r/data:font\/woff2;base64,/, plain)) == 4
      assert length(Regex.scan(~r/data:font\/woff2;base64,/, extended)) == 8
    end

    test "names no address of a network" do
      html = Expresso.Example |> Expresso.parse() |> Expresso.Deck.render()

      refute html =~ "http://"
      refute html =~ "https://"
    end
  end
end
