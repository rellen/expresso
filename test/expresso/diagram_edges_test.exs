defmodule Expresso.Element.DiagramEdgesTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Diagram.{D2, Graphviz}

  # The fixtures of `test/expresso/diagram_graphviz_test.exs` and
  # `test/expresso/diagram_d2_test.exs`, with the SVG that `Diagram.draw/1`
  # would keep, so these tests run without the tools.
  defp drawn(tool, src, svg, opts) do
    {svg, names} = tool.name(File.read!(svg))
    struct!(Builder.diagram(src, opts), svg: svg, names: names)
  end

  defp graphviz(opts),
    do:
      drawn(Graphviz, "test/fixtures/graphviz/flow.dot", "test/fixtures/graphviz/flow.svg", opts)

  defp d2(opts), do: drawn(D2, "test/fixtures/d2/flow.d2", "test/fixtures/d2/flow.svg", opts)

  # The steps of the element of the present view with the name, from its
  # `data-on`, or nil for an element that shows at each step.
  defp steps(diagram, name) do
    svg = [diagram] |> one_slide() |> document() |> screen(".diagram > svg")
    [element] = svg |> LazyHTML.query(~s([id^="#{name}-"])) |> Enum.to_list()

    case LazyHTML.attribute(element, "data-on") do
      [steps] -> steps
      [] -> nil
    end
  end

  describe "the ends of an edge" do
    test "Graphviz gives each edge the ids of its two nodes" do
      {svg, _names} = Graphviz.name(File.read!("test/fixtures/graphviz/flow.svg"))
      tree = Floki.parse_fragment!(svg)

      ends =
        for edge <- Floki.find(tree, "g.edge"),
            do: {Floki.attribute(edge, "data-graph-from"), Floki.attribute(edge, "data-graph-to")}

      # The node `db` has the id `store` in the source.
      assert ends == [{["web"], ["api"]}, {["api"], ["store"]}, {["api"], ["store"]}]
    end

    test "Graphviz leaves the port out of an end" do
      svg = """
      <svg><g id="node1" class="node"><title>web</title></g>
      <g id="node2" class="node"><title>api</title></g>
      <g id="edge1" class="edge"><title>web:out&#45;&gt;api</title></g></svg>
      """

      {svg, _names} = Graphviz.name(svg)
      [edge] = svg |> Floki.parse_fragment!() |> Floki.find("g.edge")
      assert Floki.attribute(edge, "data-graph-from") == ["web"]
      assert Floki.attribute(edge, "data-graph-to") == ["api"]
    end

    test "D2 gives each connection the keys of its two ends" do
      {svg, _names} = D2.name(File.read!("test/fixtures/d2/flow.svg"))

      ends =
        for edge <- svg |> Floki.parse_fragment!() |> Floki.find("g[data-graph-from]"),
            do:
              {hd(Floki.attribute(edge, "id")), hd(Floki.attribute(edge, "data-graph-from")),
               hd(Floki.attribute(edge, "data-graph-to"))}

      assert ends == [
               {"app.web->app.api", "app.web", "app.api"},
               {"app.api->db", "app.api", "db"},
               {"app.api->db:2", "app.api", "db"},
               {"db<-cache", "db", "cache"}
             ]
    end
  end

  describe "edges :follow, the default" do
    test "an edge without a part shows from the step where both of its ends show" do
      diagram =
        graphviz(
          elements: [Builder.part("api", at: [from: 2]), Builder.part("store", at: [from: 3])]
        )

      # `web` has no part, so the edge from `web` follows `api`.
      assert steps(diagram, "web->api") == "2 3"
      assert steps(diagram, "api->db") == "3"
      assert steps(diagram, "api->db:2") == "3"
    end

    test "an edge with its own part keeps its own steps" do
      diagram =
        graphviz(
          elements: [
            Builder.part("api", at: [from: 2]),
            Builder.part("store", at: [from: 3]),
            Builder.part("api->db", at: 2)
          ]
        )

      assert steps(diagram, "api->db") == "2"
      assert steps(diagram, "api->db:2") == "3"
    end

    test "an edge with two ends that show at each step shows at each step" do
      diagram = graphviz(elements: [Builder.part("store", at: [from: 2])])
      assert steps(diagram, "web->api") == nil
    end

    test "an end with only the steps of a list shows the edge at the steps of both ends" do
      diagram =
        graphviz(elements: [Builder.part("api", at: [1, 3]), Builder.part("store", at: 2..3)])

      assert steps(diagram, "api->db") == "3"
    end

    test "a connection of D2 follows its ends, and a container is not an end" do
      diagram = d2(elements: [Builder.part("db", at: [from: 2]), Builder.part("app", at: 3)])

      assert steps(diagram, "db<-cache") == "2 3"
      assert steps(diagram, "app.api->db") == "2 3"
      assert steps(diagram, "app.web->app.api") == nil
    end
  end

  describe "edges :own" do
    test "an edge without a part shows at each step" do
      diagram =
        graphviz(
          edges: :own,
          elements: [Builder.part("api", at: [from: 2]), Builder.part("store", at: [from: 3])]
        )

      assert steps(diagram, "web->api") == nil
      assert steps(diagram, "api->db") == nil
    end
  end

  describe "the edges option" do
    test "is refused for an SVG file" do
      assert_raise ArgumentError, ~r/so the diagram "flow.svg" takes no edges option/, fn ->
        Builder.diagram("flow.svg", edges: :own)
      end
    end

    test "takes :follow and :own for the source of a graph" do
      for edges <- [:follow, :own], src <- ["g.dot", "g.d2"] do
        assert Builder.diagram(src, edges: edges).edges == edges
      end
    end
  end
end
