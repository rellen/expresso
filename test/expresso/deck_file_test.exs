defmodule Expresso.DeckFileTest do
  use ExUnit.Case, async: true

  alias Expresso.DeckFile

  @moduletag :tmp_dir

  test "read/1 gives the result of File.read/1", %{tmp_dir: dir} do
    path = Path.join(dir, "deck.css")
    File.write!(path, "a {}")

    assert DeckFile.read(path) == {:ok, "a {}"}
    assert DeckFile.read(Path.join(dir, "missing.css")) == {:error, :enoent}
  end

  test "tracking/1 gives each path one time, in the order of the first read", %{tmp_dir: dir} do
    a = Path.join(dir, "a.css")
    File.write!(a, "a {}")

    assert DeckFile.tracking(fn ->
             DeckFile.read(a)
             DeckFile.read(Path.join(dir, "missing.png"))
             DeckFile.read(a)
             :result
           end) == {:result, [a, Path.join(dir, "missing.png")]}
  end

  test "read/1 records nothing outside tracking/1", %{tmp_dir: dir} do
    path = Path.join(dir, "a.css")
    File.write!(path, "a {}")

    DeckFile.read(path)
    assert DeckFile.tracking(fn -> :result end) == {:result, []}
  end

  test "tracking/1 inside tracking/1 keeps the paths of each one apart", %{tmp_dir: dir} do
    outer = Path.join(dir, "outer.css")
    inner = Path.join(dir, "inner.css")

    assert {{:inner, [^inner]}, [^outer]} =
             DeckFile.tracking(fn ->
               DeckFile.read(outer)
               DeckFile.tracking(fn -> DeckFile.read(inner) && :inner end)
             end)
  end

  test "the images, the diagrams and the style sheets read with read/1", %{tmp_dir: dir} do
    css = Path.join(dir, "deck.css")
    File.write!(css, ".slide { color: red; }")
    diagram = Expresso.Element.Diagram.new("test/fixtures/flow.svg")

    {_result, read} =
      DeckFile.tracking(fn ->
        Expresso.Image.data_uri!("test/fixtures/dot.png")
        Expresso.Element.Diagram.get_assigns(diagram)
        Expresso.Css.resolve(css)
      end)

    assert read == ["test/fixtures/dot.png", "test/fixtures/flow.svg", css]
  end
end
