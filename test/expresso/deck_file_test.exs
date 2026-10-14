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
