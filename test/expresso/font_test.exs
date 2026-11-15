defmodule Expresso.FontTest do
  use ExUnit.Case, async: true

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

    test "names no address of a network" do
      html = Expresso.Example |> Expresso.parse() |> Expresso.Deck.render()

      refute html =~ "http://"
      refute html =~ "https://"
    end
  end
end
