defmodule Expresso.Element.DiagramTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
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

  test "Expresso.Builder.diagram/2 makes a diagram with parts and a width" do
    assert %Diagram{src: @svg, elements: [], width: nil} = Builder.diagram(@svg)

    assert [%Part{id: "arrow"}] =
             Builder.diagram(@svg, elements: [Builder.part("arrow")]).elements

    assert Builder.diagram(@svg, width: "60%").width == "60%"
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
      {:ok, document: document(DiagramDeck)}
    end

    test "writes the SVG as an element of the document", %{document: document} do
      assert [svg] = LazyHTML.query(document, "#slide-1 .diagram > svg") |> Enum.to_list()
      assert LazyHTML.attribute(svg, "viewbox") == ["0 0 300 100"]
      assert count(svg, "defs lineargradient") == 1
    end

    test "writes the overlay attributes of each part on its element", %{document: document} do
      assert document
             |> LazyHTML.query("#slide-1 .diagram g[id^='arrow-']")
             |> LazyHTML.attribute("data-on") ==
               ["2"]

      [output] =
        LazyHTML.query(document, "#slide-1 .diagram rect[id^='output-']") |> Enum.to_list()

      assert LazyHTML.attribute(output, "data-on") == []
      assert LazyHTML.attribute(output, "data-el") == []

      assert count(document, "#slide-1 .diagram rect[id^='input-']:not([data-on])") == 1
    end

    test "puts a part with an on entity into a wrapper with the attributes", %{
      document: document
    } do
      [wrapper] =
        LazyHTML.query(document, "#slide-1 .diagram svg > g.diagram-part") |> Enum.to_list()

      assert LazyHTML.attribute(wrapper, "data-on") == ["3"]
      assert LazyHTML.attribute(wrapper, "data-el") == ["s1-e3"]

      assert [{"rect", _attrs, _children}] =
               wrapper |> LazyHTML.child_nodes() |> LazyHTML.to_tree()

      assert count(wrapper, "rect[id^='output-']") == 1
    end

    test "writes the overlay attributes of the diagram on the root tag", %{document: document} do
      assert document |> LazyHTML.query("#slide-2 .diagram") |> LazyHTML.attribute("data-on") == [
               "1"
             ]
    end

    test "gives each copy of the file its own ids, and keeps its references", %{
      document: document
    } do
      copies = LazyHTML.query(document, ".diagram")
      assert Enum.count(copies) > 1

      ids =
        for copy <- copies do
          [id] = copy |> LazyHTML.query("lineargradient") |> LazyHTML.attribute("id")
          assert id =~ ~r/^fill-\d+$/

          assert copy |> LazyHTML.query("rect[id^='input-']") |> LazyHTML.attribute("fill") == [
                   "url(##{id})"
                 ]

          id
        end

      assert Enum.uniq(ids) == ids
    end

    test "writes the width option as a custom property, with a percentage in vw", %{
      document: document
    } do
      assert document |> LazyHTML.query("#slide-2 .diagram") |> LazyHTML.attribute("style") ==
               ["--diagram-width: 60vw"]

      assert count(document, "#slide-1 .diagram:not([style])") == 1
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

      svg =
        Diagram.get_assigns(%Diagram{src: src, elements: parts}).svg |> LazyHTML.from_fragment()

      [wrapper] = LazyHTML.query(svg, "g.diagram-part") |> Enum.to_list()
      assert LazyHTML.attribute(wrapper, "transform") == []
      assert LazyHTML.attribute(wrapper, "data-el") == ["s1-e2"]
      assert [turned] = LazyHTML.query(wrapper, "g[id^='turned-']") |> Enum.to_list()
      assert LazyHTML.attribute(turned, "transform") == ["rotate(30)"]

      [word] = LazyHTML.query(svg, "text > tspan[id^='word-']") |> Enum.to_list()
      assert LazyHTML.attribute(word, "data-el") == ["s1-e3"]
      assert LazyHTML.attribute(word, "data-on") == ["1"]
    end

    test "takes a file with an XML declaration, a DOCTYPE and a processing instruction" do
      # Graphviz writes the declaration and the DOCTYPE, and Illustrator writes
      # an `xpacket` instruction in the metadata.
      diagram =
        Builder.diagram("test/fixtures/prolog.svg",
          elements: [
            Builder.part("web_api", at: 2),
            Builder.part("api", on: [Builder.on(2, move_to: "web")])
          ]
        )

      document = [diagram] |> one_slide() |> document()
      svg = screen(document, ".diagram > svg")

      assert [edge] = LazyHTML.query(svg, "g.edge") |> Enum.to_list()
      assert LazyHTML.attribute(edge, "data-on") == ["2"]
      assert count(svg, "g.diagram-part > g.node") == 1

      html = LazyHTML.to_html(document)
      refute html =~ "<?xml"
      refute html =~ "DTD SVG"
    end

    test "raises for an id that the file does not hold" do
      diagram = Builder.diagram(@svg, elements: [Builder.part("no-such-id")])

      assert_raise ArgumentError, ~r/has no element with the id "no-such-id"/, fn ->
        Diagram.get_assigns(diagram)
      end
    end

    test "raises for a file that it cannot read" do
      assert_raise ArgumentError, ~r/cannot read the diagram "no\/such\/file.svg"/, fn ->
        Diagram.get_assigns(Builder.diagram("no/such/file.svg"))
      end
    end
  end
end
