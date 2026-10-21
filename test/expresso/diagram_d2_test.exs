defmodule Expresso.Element.DiagramD2Test do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Diagram
  alias Expresso.Element.Diagram.D2

  doctest D2

  @source "test/fixtures/d2/flow.d2"

  # The output of `d2 --layout elk` for `@source`, so these tests run without
  # D2. The tests with the tag `:d2` run the tool.
  @svg File.read!("test/fixtures/d2/flow.svg")

  @names [
    "app",
    "db",
    "cache",
    "app.web",
    "app.api",
    "app.web->app.api",
    "app.api->db",
    "app.api->db:2",
    "db<-cache"
  ]

  # A diagram of the source, with the SVG that `Diagram.draw/1` would keep.
  defp drawn(parts) do
    {svg, names} = D2.name(@svg)
    struct!(Builder.diagram(@source, elements: parts), svg: svg, names: names)
  end

  describe "D2.name/1" do
    test "gives each shape, container and connection the name from its key, in the order of the file" do
      {_svg, names} = D2.name(@svg)
      assert names == @names
    end

    test "writes each name as the id of the group with the key, and leaves the other groups" do
      {svg, _names} = D2.name(@svg)
      tree = Floki.parse_fragment!(svg)

      for name <- @names do
        assert [{"g", _attrs, _children}] = Floki.find(tree, ~s(g[id="#{name}"])), name
      end

      assert tree |> Floki.find("g.shape") |> Enum.flat_map(&Floki.attribute(&1, "id")) == []
    end

    test "writes the ends of a connection in a container with the key of the container" do
      svg = ~s(<svg><g class="#{Base.encode64("a.b.(x -&gt; y)[0]")}"></g></svg>)
      assert {_svg, ["a.b.x->a.b.y"]} = D2.name(svg)
    end

    test "keeps each arrow of D2 in the name" do
      for {arrow, escaped} <- [
            {"->", "-&gt;"},
            {"<-", "&lt;-"},
            {"<->", "&lt;-&gt;"},
            {"--", "--"}
          ] do
        svg = ~s(<svg><g class="#{Base.encode64("(x #{escaped} y)[0]")}"></g></svg>)
        assert D2.name(svg) |> elem(1) == ["x#{arrow}y"]
      end
    end
  end

  describe "a part of a graph" do
    test "names a shape, a connection and a container in the words of the source" do
      parts = [
        Builder.part("app.web"),
        Builder.part("app.web->app.api", at: 2),
        Builder.part("app.api->db:2", at: 3),
        Builder.part("app", on: [Builder.on(4, state: :alert)])
      ]

      svg = [drawn(parts)] |> one_slide() |> document() |> screen(".diagram > svg")

      assert [edge] = svg |> LazyHTML.query(~s(g[id^="app.web->app.api-"])) |> Enum.to_list()
      assert LazyHTML.attribute(edge, "data-on") == ["2"]
      assert [second] = svg |> LazyHTML.query(~s(g[id^="app.api->db:2-"])) |> Enum.to_list()
      assert LazyHTML.attribute(second, "data-on") == ["3"]
      assert count(svg, ~s(g.diagram-part > g[id^="app-"])) == 1
    end

    test "with a name that the graph does not have stops the render, and the message lists the names" do
      diagram = drawn([Builder.part("web")])

      error = assert_raise ArgumentError, fn -> Diagram.get_assigns(diagram) end
      assert error.message =~ ~s(has no element with the id "web")
      assert error.message =~ ~s(The graph has these names: "app", "db", "cache", "app.web")
    end
  end

  describe "the layout option" do
    test "takes a layout engine of D2 for a .d2 file" do
      for layout <- D2.layouts() do
        assert Builder.diagram("graph.d2", layout: layout).layout == layout
      end
    end

    test "refuses a layout of Graphviz for a .d2 file, and a layout of D2 for a .dot file" do
      assert_raise ArgumentError,
                   ~r/the layout of the diagram "graph.d2" is one of :elk, :dagre/,
                   fn ->
                     Builder.diagram("graph.d2", layout: :neato)
                   end

      assert_raise ArgumentError, ~r/the layout of the diagram "graph.dot" is one of :dot/, fn ->
        Builder.diagram("graph.dot", layout: :elk)
      end
    end
  end

  describe "with D2" do
    @describetag :d2

    test "the render runs the tool, and the parts name the elements of the source" do
      diagram =
        Builder.diagram(@source,
          elements: [Builder.part("app.web->app.api", at: 2), Builder.part("db", at: 3)]
        )

      svg = [diagram] |> one_slide() |> document() |> screen(".diagram > svg")

      assert [edge] = svg |> LazyHTML.query(~s(g[id^="app.web->app.api-"])) |> Enum.to_list()
      assert LazyHTML.attribute(edge, "data-on") == ["2"]
    end

    test "each layout engine draws the graph with the same names" do
      for layout <- D2.layouts() do
        {svg, names} = D2.draw!(@source, layout)
        assert svg =~ "<svg"
        assert names == @names, inspect(layout)
      end
    end

    test "a syntax error stops the render with the message of D2" do
      diagram = Builder.diagram("test/fixtures/d2/bad.d2")

      error = assert_raise ArgumentError, fn -> Diagram.get_assigns(diagram) end
      assert error.message =~ ~s(D2 did not draw the diagram "test/fixtures/d2/bad.d2")
      assert error.message =~ "bad.d2:2"
    end

    test "the fixture of the tests without D2 has the names of the source" do
      {_svg, names} = D2.draw!(@source, :elk)
      {_svg, fixture} = D2.name(@svg)
      assert names == fixture
    end
  end
end
