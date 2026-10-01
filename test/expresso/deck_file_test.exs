defmodule Expresso.DeckFileTest do
  use ExUnit.Case, async: true

  alias Expresso.DeckFile

  @moduletag :tmp_dir

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
