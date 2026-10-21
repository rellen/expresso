defmodule Expresso.Element.DiagramGraphvizTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Diagram
  alias Expresso.Element.Diagram.{Graphviz, Tool}

  @source "test/fixtures/graphviz/flow.dot"

  # The output of `dot -Tsvg` for `@source`, so these tests run without
  # Graphviz. The tests with the tag `:graphviz` run the tool.
  @svg File.read!("test/fixtures/graphviz/flow.svg")

  @names ["cluster_app", "web", "api", "web->api", "store", "api->db", "api->db:2"]

  # A diagram of the source, with the SVG that `Diagram.draw/1` would keep.
  defp drawn(parts) do
    {svg, names} = Graphviz.name(@svg)
    %Diagram{Builder.diagram(@source, elements: parts) | svg: svg, names: names}
  end

  describe "Graphviz.name/1" do
    test "gives each node, edge and cluster the name from its title, in the order of the file" do
      {_svg, names} = Graphviz.name(@svg)
      assert names == @names
    end

    test "writes each name as the id of its element, and keeps an id of the source" do
      {svg, _names} = Graphviz.name(@svg)
      tree = Floki.parse_fragment!(svg)

      ids =
        tree
        |> Floki.find("g.node, g.edge, g.cluster")
        |> Enum.flat_map(&Floki.attribute(&1, "id"))

      assert ids == @names
      assert Floki.find(tree, ~s(g[id="store"])) |> length() == 1
      refute Enum.any?(ids, &Regex.match?(~r/\A(node|edge|clust)\d+\z/, &1))
    end

    test "keeps the id of the root of the graph" do
      {svg, _names} = Graphviz.name(@svg)
      assert svg |> Floki.parse_fragment!() |> Floki.find("g#graph0") |> length() == 1
    end
  end

  describe "a part of a graph" do
    test "names a node, an edge and a cluster in the words of the source" do
      parts = [
        Builder.part("web"),
        Builder.part("web->api", at: 2),
        Builder.part("api->db:2", at: 3),
        Builder.part("cluster_app", on: [Builder.on(4, state: :alert)])
      ]

      svg = [drawn(parts)] |> one_slide() |> document() |> screen(".diagram > svg")

      assert [edge] = svg |> LazyHTML.query(~s(g.edge[id^="web->api-"])) |> Enum.to_list()
      assert LazyHTML.attribute(edge, "data-on") == ["2"]
      assert [second] = svg |> LazyHTML.query(~s(g.edge[id^="api->db:2-"])) |> Enum.to_list()
      assert LazyHTML.attribute(second, "data-on") == ["3"]
      assert count(svg, "g.diagram-part > g.cluster") == 1
    end

    test "with a name that the graph does not have stops the render, and the message lists the names" do
      diagram = drawn([Builder.part("db")])

      error = assert_raise ArgumentError, fn -> Diagram.get_assigns(diagram) end
      assert error.message =~ ~s(has no element with the id "db")

      assert error.message =~
               ~s(The graph has these names: "cluster_app", "web", "api", "web->api", "store")
    end
  end

  describe "the layout option" do
    test "takes a layout engine of Graphviz for a .dot or a .gv file" do
      for src <- ["graph.dot", "graph.gv", "GRAPH.DOT"], layout <- Graphviz.layouts() do
        assert Builder.diagram(src, layout: layout).layout == layout
      end
    end

    test "is refused for an SVG file" do
      assert_raise ArgumentError, ~r/so the diagram "flow.svg" takes no layout option/, fn ->
        Builder.diagram("flow.svg", layout: :neato)
      end
    end
  end

  describe "Tool" do
    @missing %{
      name: "No Tool",
      program: "expresso-no-such-program",
      variable: "EXPRESSO_NO_SUCH_TOOL",
      install: "https://example.com/"
    }

    test "find/3 names the tool, the program and the variable when the program is not on the path" do
      assert {:error, message} = Tool.find(@missing, "g.dot", %{})

      assert message ==
               ~s(the diagram "g.dot" needs No Tool, and the render does not find ) <>
                 "`expresso-no-such-program` on the path. Install No Tool from " <>
                 "https://example.com/, or give its path in EXPRESSO_NO_SUCH_TOOL"
    end

    test "find/3 takes the path of the variable, and refuses a path that does not exist" do
      sh = System.find_executable("sh")
      assert Tool.find(@missing, "g.dot", %{"EXPRESSO_NO_SUCH_TOOL" => sh}) == {:ok, sh}

      assert Tool.find(@missing, "g.dot", %{"EXPRESSO_NO_SUCH_TOOL" => "/no/such/dot"}) ==
               {:error, "EXPRESSO_NO_SUCH_TOOL gives /no/such/dot, and that file does not exist"}
    end

    test "run!/3 returns the file that the program writes, and keeps its other output out" do
      tool = %{@missing | program: "sh"}
      command = &{["-c", "echo warning >&2; printf '<svg/>' > '#{&1}/graph.svg'"], []}
      assert Tool.run!(tool, "g.dot", command) == "<svg/>"
    end

    test "run!/4 writes the files into the private directory, and gives the environment" do
      tool = %{@missing | program: "sh"}

      command =
        &{[
           "-c",
           ~s(cat "$1/a.txt" "$1/b.txt" > "$1/graph.svg"; echo "$NAME" >> "$1/graph.svg"),
           "sh",
           &1
         ], [{"NAME", "env"}]}

      assert Tool.run!(tool, "g.dot", command, [{"a.txt", "a"}, {"b.txt", "b"}]) == "abenv\n"
    end

    test "run!/3 raises with the output and the status of a program that fails" do
      tool = %{@missing | program: "sh"}

      error =
        assert_raise ArgumentError, fn ->
          Tool.run!(tool, "g.dot", fn _dir ->
            {["-c", "echo 'syntax error in line 3' >&2; exit 3"], []}
          end)
        end

      assert error.message ==
               ~s(No Tool did not draw the diagram "g.dot", and it ended with the status 3:\n\n) <>
                 "syntax error in line 3"
    end
  end

  describe "with Graphviz" do
    @describetag :graphviz

    test "the render runs the tool, and the parts name the elements of the source" do
      diagram =
        Builder.diagram(@source,
          elements: [Builder.part("web->api", at: 2), Builder.part("store", at: 3)]
        )

      svg = [diagram] |> one_slide() |> document() |> screen(".diagram > svg")

      assert [edge] = svg |> LazyHTML.query(~s(g.edge[id^="web->api-"])) |> Enum.to_list()
      assert LazyHTML.attribute(edge, "data-on") == ["2"]
      assert count(svg, "g.node") == 3
    end

    test "each layout engine draws the graph, and only dot, neato and fdp draw a cluster" do
      for layout <- Graphviz.layouts() do
        {svg, names} = Graphviz.draw!(@source, layout)
        assert svg =~ "<svg"

        expected = if layout in [:dot, :neato, :fdp], do: @names, else: @names -- ["cluster_app"]
        assert names == expected, inspect(layout)
      end
    end

    test "a syntax error stops the render with the message of Graphviz" do
      diagram = Builder.diagram("test/fixtures/graphviz/bad.dot")

      error = assert_raise ArgumentError, fn -> Diagram.get_assigns(diagram) end

      assert error.message =~
               ~s(Graphviz did not draw the diagram "test/fixtures/graphviz/bad.dot")

      assert error.message =~ "syntax error in line 3"
    end

    test "the render reads the source, so the watch mode sees a change of the source" do
      diagram = Builder.diagram(@source, elements: [Builder.part("web")])

      {_html, paths} =
        Expresso.DeckFile.track(fn -> [diagram] |> one_slide() |> document() end)

      assert Path.expand(@source) in Enum.map(paths, &Path.expand/1)
    end

    test "the signature of the morph comes from the SVG of the graph" do
      deck =
        Builder.deck(
          [
            Builder.slide("one", elements: [Builder.diagram(@source)]),
            Builder.slide("two", elements: [Builder.diagram(@source)]),
            Builder.slide("three", elements: [Builder.diagram(@source, layout: :circo)])
          ],
          name: "graphs"
        )

      # `Expresso.Morph` reads the SVG of each graph for its signature. The
      # same SVG gives the same signature, and a different layout gives a
      # different SVG.
      signatures =
        deck
        |> document()
        |> LazyHTML.query(".screen .diagram")
        |> Enum.flat_map(&LazyHTML.attribute(&1, "data-morph-signature"))

      assert [one, one, three] = signatures
      assert one != three
    end

    test "the fixture of the tests without Graphviz has the names of the source" do
      {_svg, names} = Graphviz.draw!(@source, :dot)
      {_svg, fixture} = Graphviz.name(@svg)
      assert names == fixture
    end
  end
end
