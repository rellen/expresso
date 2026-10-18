defmodule Expresso.DeckFileTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.DeckFile

  doctest DeckFile

  @moduletag :tmp_dir

  describe "read!/2" do
    test "returns the bytes of a file, and raises the message of read_error/3", %{tmp_dir: dir} do
      path = Path.join(dir, "a.svg")
      File.write!(path, "<svg/>")

      assert DeckFile.read!(path, "diagram") == "<svg/>"

      assert_raise ArgumentError, DeckFile.read_error("no/such.svg", "diagram", :enoent), fn ->
        DeckFile.read!("no/such.svg", "diagram")
      end
    end

    # The render of a deck with one element that names a missing file.
    defp render(element) do
      [Builder.slide("one", elements: [element])] |> Builder.deck() |> Expresso.Deck.render()
    end

    test "each element that reads a file at render time gives the same message" do
      for {element, path, noun} <- [
            {Builder.diagram("no/such.svg"), "no/such.svg", "diagram"},
            {Builder.embed("no/such.html", title: "x"), "no/such.html", "page"},
            {Builder.video("no/such.webm", title: "x", poster: "test/fixtures/dot.png"),
             "no/such.webm", "video"},
            {Builder.video("test/fixtures/clip.webm",
               title: "x",
               poster: "test/fixtures/dot.png",
               captions: "no/such.vtt"
             ), "no/such.vtt", "captions"},
            {Builder.audio("no/such.ogg", title: "x"), "no/such.ogg", "sound"},
            {Builder.image("no/such.png"), "no/such.png", "image"}
          ] do
        assert_raise ArgumentError, DeckFile.read_error(path, noun, :enoent), fn ->
          render(element)
        end
      end
    end
  end

  describe "read_text/1" do
    # Latin-1 writes the character é as the one byte E9, which is not UTF-8.
    @latin1 "caf\xE9 = 1\n"

    test "returns the text of a UTF-8 file, and :not_utf8 for a different file", %{tmp_dir: dir} do
      utf8 = Path.join(dir, "a.toml")
      latin1 = Path.join(dir, "legacy.toml")
      File.write!(utf8, "café = 1\n")
      File.write!(latin1, @latin1)

      assert DeckFile.read_text(utf8) == {:ok, "café = 1\n"}
      assert DeckFile.read_text(latin1) == {:error, :not_utf8}
      assert DeckFile.read_text(Path.join(dir, "missing.toml")) == {:error, :enoent}

      assert_raise ArgumentError, DeckFile.read_error(latin1, "page", :not_utf8), fn ->
        DeckFile.read_text!(latin1, "page")
      end
    end

    test "a code file that is not UTF-8 gives an error that names the file", %{tmp_dir: dir} do
      path = Path.join(dir, "legacy.toml")
      File.write!(path, @latin1)

      for code <- [Builder.code("toml", src: path), Builder.code(src: path)] do
        error =
          assert_raise Spark.Error.DslError, fn ->
            [Builder.slide("one", elements: [code])] |> Builder.deck()
          end

        assert Exception.message(error) =~ DeckFile.read_error(path, "code file", :not_utf8)
      end
    end

    test "a chart file that is not UTF-8 gives an error that names the file", %{tmp_dir: dir} do
      path = Path.join(dir, "legacy.csv")
      File.write!(path, "Caf\xE9,Orders\nA,1\n")

      error =
        assert_raise Spark.Error.DslError, fn ->
          [Builder.slide("one", elements: [Builder.chart(:bar, title: "x", src: path)])]
          |> Builder.deck()
        end

      assert Exception.message(error) =~ DeckFile.read_error(path, "chart file", :not_utf8)
    end

    test "a local page that is not UTF-8 gives an error that names the file", %{tmp_dir: dir} do
      path = Path.join(dir, "legacy.html")
      File.write!(path, "<p>caf\xE9</p>")

      assert_raise ArgumentError, DeckFile.read_error(path, "page", :not_utf8), fn ->
        render(Builder.embed(path, title: "x"))
      end
    end
  end

  describe "read/1" do
    test "returns the result of File.read/1", %{tmp_dir: dir} do
      path = Path.join(dir, "deck.css")
      File.write!(path, "a {}")

      assert DeckFile.read(path) == {:ok, "a {}"}
      assert DeckFile.read(Path.join(dir, "missing.css")) == {:error, :enoent}
    end

    test "records nothing outside track/1", %{tmp_dir: dir} do
      path = Path.join(dir, "a.css")
      File.write!(path, "a {}")

      DeckFile.read(path)
      assert DeckFile.track(fn -> :result end) == {:result, []}
    end
  end

  describe "track/1" do
    test "returns each path one time, in the order of the first read", %{tmp_dir: dir} do
      found = Path.join(dir, "a.css")
      missing = Path.join(dir, "missing.png")
      File.write!(found, "a {}")

      assert DeckFile.track(fn ->
               DeckFile.read(found)
               DeckFile.read(missing)
               DeckFile.read(found)
               :result
             end) == {:result, [found, missing]}
    end

    test "keeps the paths of an inner call apart from the outer call", %{tmp_dir: dir} do
      outer = Path.join(dir, "outer.css")
      inner = Path.join(dir, "inner.css")

      assert {{:inner, [^inner]}, [^outer]} =
               DeckFile.track(fn ->
                 DeckFile.read(outer)
                 DeckFile.track(fn -> DeckFile.read(inner) && :inner end)
               end)
    end

    test "returns the files of images, diagrams and style sheets", %{tmp_dir: dir} do
      css = Path.join(dir, "deck.css")
      File.write!(css, ".slide { color: red; }")
      diagram = Expresso.Builder.diagram("test/fixtures/flow.svg")

      {_result, paths} =
        DeckFile.track(fn ->
          Expresso.Image.data_uri!("test/fixtures/dot.png")
          Expresso.Element.Diagram.get_assigns(diagram)
          Expresso.Css.resolve(css)
        end)

      assert paths == ["test/fixtures/dot.png", "test/fixtures/flow.svg", css]
    end
  end
end
