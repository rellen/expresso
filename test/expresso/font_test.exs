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

  describe "file_count/0" do
    test "counts each file that the stylesheet names" do
      files = Path.wildcard("assets/fonts/*.woff2")

      assert Font.file_count() == length(files)
      assert Font.file_count() > 0
    end
  end

  describe "the document" do
    test "names no address of a network" do
      html = Expresso.Example |> Expresso.parse() |> Expresso.Deck.render()

      refute html =~ "http://"
      refute html =~ "https://"
    end
  end
end
