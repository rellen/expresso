defmodule Expresso.Element.DiagramTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.{Diagram, Part}

  @svg "test/fixtures/flow.svg"

  defmodule DiagramDeck do
    use Expresso

    name "diagram deck"

    slide "flow" do
      diagram "test/fixtures/flow.svg" do
        part "arrow", at: 2

        part "output" do
          at from: 3
          on 3, state: :alert
        end
      end
    end

    slide "in a box" do
      text_box do
        diagram "test/fixtures/flow.svg" do
          at from: :next
          width "60%"
        end
      end
    end
  end

  defp document(deck), do: deck |> Expresso.parse() |> Expresso.Deck.render()

  test "new/3 makes a diagram with parts and a width" do
    assert Diagram.new(@svg) == %Diagram{src: @svg, elements: [], width: nil}
    assert [%Part{id: "arrow"}] = Diagram.new(@svg, [Part.new("arrow")]).elements
    assert Diagram.new(@svg, [], "60%").width == "60%"
  end

  describe "the DSL entity" do
    test "takes the path as its first argument, and parts with the overlays" do
      [flow, box] = Expresso.parse(DiagramDeck).slides

      assert [%Diagram{src: @svg, steps: nil} = diagram] = flow.elements

      assert [%Part{id: "arrow", steps: [2]}, %Part{id: "output", steps: [3]} = output] =
               diagram.elements

      assert [%{state: :alert, steps: [3]}] = output.on
      assert [%{elements: [%Diagram{steps: [1]}]}] = box.elements
    end
  end

  describe "render/1" do
    setup do
      {:ok, document: DiagramDeck |> document() |> Floki.parse_document!()}
    end

    test "writes the SVG as an element of the document", %{document: document} do
      assert [svg] = Floki.find(document, "#slide-1 .diagram > svg")
      assert Floki.attribute([svg], "viewbox") == ["0 0 300 100"]
      assert [_] = Floki.find([svg], "defs lineargradient")
    end

    test "writes the overlay attributes of each part on its element", %{document: document} do
      assert document
             |> Floki.find("#slide-1 .diagram g[id^='arrow-']")
             |> Floki.attribute("data-on") ==
               ["2"]

      [output] = Floki.find(document, "#slide-1 .diagram rect[id^='output-']")
      assert Floki.attribute([output], "data-on") == []
      assert Floki.attribute([output], "data-el") == []

      assert document
             |> Floki.find("#slide-1 .diagram rect[id^='input-']")
             |> Floki.attribute("data-on") ==
               []
    end

    test "puts a part with an on entity into a wrapper with the attributes", %{
      document: document
    } do
      [wrapper] = Floki.find(document, "#slide-1 .diagram svg > g.diagram-part")

      assert Floki.attribute([wrapper], "data-on") == ["3"]
      assert Floki.attribute([wrapper], "data-el") == ["s1-e3"]
      assert [{"rect", _attrs, _children}] = Floki.children(wrapper)
      assert [_] = Floki.find([wrapper], "rect[id^='output-']")
    end

    test "writes the overlay attributes of the diagram on the root tag", %{document: document} do
      assert document |> Floki.find("#slide-2 .diagram") |> Floki.attribute("data-on") == ["1"]
    end

    test "gives each copy of the file its own ids, and keeps its references", %{
      document: document
    } do
      copies = Floki.find(document, ".diagram")
      assert length(copies) > 1

      ids =
        for copy <- copies do
          [id] = copy |> Floki.find("lineargradient") |> Floki.attribute("id")
          assert id =~ ~r/^fill-\d+$/

          assert copy |> Floki.find("rect[id^='input-']") |> Floki.attribute("fill") == [
                   "url(##{id})"
                 ]

          id
        end

      assert Enum.uniq(ids) == ids
    end

    test "writes the width option as a custom property, with a percentage in vw", %{
      document: document
    } do
      assert document |> Floki.find("#slide-2 .diagram") |> Floki.attribute("style") ==
               ["--diagram-width: 60vw"]

      assert document |> Floki.find("#slide-1 .diagram") |> Floki.attribute("style") == []
    end

    @tag :tmp_dir
    test "keeps the transform of a part in the wrapper, and wraps no part of a text", %{
      tmp_dir: tmp_dir
    } do
      src = Path.join(tmp_dir, "parts.svg")

      File.write!(src, """
      <svg viewBox="0 0 10 10">
        <g id="turned" transform="rotate(30)"><rect width="2" height="2"/></g>
        <text><tspan id="word">a</tspan></text>
      </svg>
      """)

      parts = [
        %Part{id: "turned", el: "s1-e2", steps: [1]},
        %Part{id: "word", el: "s1-e3", steps: [1]}
      ]

      svg = Diagram.get_assigns(Diagram.new(src, parts)).svg |> Floki.parse_fragment!()

      [wrapper] = Floki.find(svg, "g.diagram-part")
      assert Floki.attribute([wrapper], "transform") == []
      assert Floki.attribute([wrapper], "data-el") == ["s1-e2"]
      assert [turned] = Floki.find([wrapper], "g[id^='turned-']")
      assert Floki.attribute([turned], "transform") == ["rotate(30)"]

      [word] = Floki.find(svg, "text > tspan[id^='word-']")
      assert Floki.attribute([word], "data-el") == ["s1-e3"]
      assert Floki.attribute([word], "data-on") == ["1"]
    end

    test "raises for an id that the file does not hold" do
      diagram = Diagram.new(@svg, [Part.new("no-such-id")])

      assert_raise ArgumentError, ~r/has no element with the id "no-such-id"/, fn ->
        Diagram.get_assigns(diagram)
      end
    end

    test "raises for a file that it cannot read" do
      assert_raise ArgumentError, ~r/cannot read the diagram "no\/such\/file.svg"/, fn ->
        Diagram.get_assigns(Diagram.new("no/such/file.svg"))
      end
    end
  end
end
