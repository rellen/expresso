defmodule Expresso.Element.DiagramMermaidTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Diagram
  alias Expresso.Element.Diagram.{Outline, Pele, Tool}

  doctest Pele

  @source "test/fixtures/mermaid/flow.mmd"

  # The output of `priv/pele/render.mjs` for `@source`, so these tests run
  # without Node. The tests with the tag `:mermaid` run Pele.
  @result "test/fixtures/mermaid/flow.json" |> File.read!() |> JSON.decode!()

  @names ["app", "web->api", "api->db", "api->db:2", "cache->db", "web", "api", "db", "cache"]

  # A diagram of the source, with the SVG that `Diagram.draw/1` would keep.
  defp drawn(opts \\ []) do
    {svg, names} = Pele.name(@result)
    struct!(Builder.diagram(@source, opts), svg: svg, names: names)
  end

  defp tree, do: @result |> Pele.name() |> elem(0) |> Floki.parse_fragment!()

  defp attrs(tree, selector),
    do: tree |> Floki.find(selector) |> Enum.map(fn {_tag, attrs, _} -> Map.new(attrs) end)

  describe "Pele.name/1" do
    test "gives each part of a flowchart its name, in the order of the file" do
      assert @result |> Pele.name() |> elem(1) == @names
    end

    test "names an edge by its ends and its arrow, and counts a second edge between the same ends" do
      edges = attrs(tree(), "g.pele-edge")

      assert Enum.map(edges, & &1["id"]) == ["web->api", "api->db", "api->db:2", "cache->db"]

      assert %{
               "data-graph-kind" => "edge",
               "data-graph-from" => "api",
               "data-graph-to" => "db",
               "data-graph-arrow" => "->",
               "data-graph-label" => "reads"
             } = Enum.at(edges, 1)
    end

    test "gives the label of an edge the id of the edge, and the marks only to the edge" do
      [label] = attrs(tree(), "g.pele-edge-label")

      assert label["id"] == "api->db"
      refute Map.has_key?(label, "data-graph-kind")
    end

    test "marks a subgraph as a container, and each member of a subgraph with its parent" do
      tree = tree()

      assert [%{"id" => "app", "data-graph-kind" => "container"}] = attrs(tree, "g.pele-cluster")

      parents =
        for node <- attrs(tree, "g.pele-node"), do: {node["id"], node["data-graph-parent"]}

      assert parents == [{"web", "app"}, {"api", "app"}, {"db", nil}, {"cache", nil}]
    end

    test "takes the id of an edge from the source, and names an edge with no head or two heads" do
      svg = """
      <svg><g class="pele-edge" data-id="e1"></g><g class="pele-edge" data-id="L_a_c_0"></g>
      <g class="pele-edge" data-id="L_a_d_0"></g></svg>
      """

      model = %{
        "subgraphs" => [],
        "edges" => [
          %{
            "id" => "e1",
            "start" => "a",
            "end" => "b",
            "type" => "arrow_point",
            "isUserDefinedId" => true
          },
          %{"id" => "L_a_c_0", "start" => "a", "end" => "c", "type" => "arrow_open"},
          %{"id" => "L_a_d_0", "start" => "a", "end" => "d", "type" => "double_arrow_circle"}
        ]
      }

      assert {_svg, ["e1", "a--c", "a<->d"]} =
               Pele.name(%{"svg" => svg, "type" => "flowchart", "model" => model})
    end

    test "a type with no plan keeps the data-id of each part as its name, with no marks" do
      svg = ~s(<svg><g class="pele-node" data-id="Alice"></g></svg>)

      assert {named, ["Alice"]} =
               Pele.name(%{"svg" => svg, "type" => "sequence", "model" => %{}})

      refute named =~ "data-graph-kind"
    end
  end

  describe "the render" do
    test "a flowchart with the colors of the theme has the class of the graph and of Pele" do
      figure = [drawn()] |> one_slide() |> document() |> screen(".diagram")
      assert LazyHTML.attribute(figure, "class") == ["diagram diagram-graph diagram-pele"]

      tool = [drawn(colors: :tool)] |> one_slide() |> document() |> screen(".diagram")
      assert LazyHTML.attribute(tool, "class") == ["diagram"]
    end

    test "an edge follows its ends, and its label shows at the steps of the edge" do
      diagram =
        drawn(elements: [Builder.part("api", at: [from: 2]), Builder.part("db", at: [from: 3])])

      svg = [diagram] |> one_slide() |> document() |> screen(".diagram > svg")
      steps = fn selector -> LazyHTML.attribute(LazyHTML.query(svg, selector), "data-on") end

      assert steps.(~s(g.pele-edge[id^="api->db-"])) == ["3"]
      assert steps.(~s(g.pele-edge[id^="api->db:2-"])) == ["3"]
      assert steps.(~s(g.pele-edge-label[id^="api->db-"])) == ["3"]
      assert steps.(~s(g.pele-edge[id^="web->api-"])) == ["2 3"]
    end

    test "the list for a screen reader holds the label of an edge" do
      {svg, _names} = Pele.name(@result)

      assert [
               %{label: "App", children: [%{label: "Web", edges: ["to API"]}, api]},
               %{label: "DB"},
               %{label: "Cache", edges: ["to DB"]}
             ] = Outline.items(svg)

      assert api.edges == ["to DB (reads)", "to DB"]
    end

    test "a part that the diagram does not have names the parts of the source" do
      assert_raise ArgumentError, ~r/no element with the id "nope".*"web->api"/, fn ->
        [drawn(elements: [Builder.part("nope", at: 2)])] |> one_slide() |> document()
      end
    end
  end

  describe "the options" do
    test "a diagram takes a file or the source option with lang" do
      assert Builder.diagram(source: "flowchart LR\n  a --> b", lang: :mermaid).lang == :mermaid

      for {opts, message} <- [
            {[], ~r/takes the path of a file, or the source option/},
            {[source: "x"], ~r/needs the lang option/},
            {[source: "x", lang: :dot], ~r/invalid value for :lang option/}
          ] do
        assert_raise ArgumentError, message, fn -> Builder.diagram(opts) end
      end

      assert_raise ArgumentError, ~r/takes a file or the source option, and not both/, fn ->
        Builder.diagram("flow.mmd", source: "x", lang: :mermaid)
      end

      assert_raise ArgumentError, ~r/takes no lang option/, fn ->
        Builder.diagram("flow.mmd", lang: :mermaid)
      end
    end

    test "a diagram of Mermaid takes no layout, and takes edges, colors and font" do
      assert_raise ArgumentError, ~r/Pele draws the diagram "flow.mmd" with its one layout/, fn ->
        Builder.diagram("flow.mmd", layout: :dot)
      end

      assert %Diagram{edges: :own, colors: :tool, font: "fonts"} =
               Builder.diagram("flow.mmd", edges: :own, colors: :tool, font: "fonts")
    end

    test "an SVG file refuses the options of a graph, and the message names a .mmd file" do
      assert_raise ArgumentError, ~r/\.mmd file, so the diagram "flow.svg" takes no edges/, fn ->
        Builder.diagram("flow.svg", edges: :own)
      end
    end

    test "the tool is Node, and EXPRESSO_NODE gives a different path" do
      assert %{program: "node", variable: "EXPRESSO_NODE"} = Pele.tool()

      assert Tool.find(Pele.tool(), "flow.mmd", %{"EXPRESSO_NODE" => "/no/node"}) ==
               {:error, "EXPRESSO_NODE gives /no/node, and that file does not exist"}
    end
  end

  describe "the copy of Pele" do
    test "has the version of package.json, its license and the type module" do
      package = "package.json" |> File.read!() |> JSON.decode!()
      assert package["devDependencies"]["pele"] == Pele.version()

      assert File.read!("priv/pele/LICENSE") =~ "MIT License"

      assert File.read!("priv/pele/package.json") |> JSON.decode!() |> Map.fetch!("type") ==
               "module"

      assert File.exists?(Pele.script())
    end
  end

  describe "with Pele" do
    @describetag :mermaid

    test "Pele gives the names of the fixture, and the fixture agrees with Pele" do
      {_svg, names} = Pele.draw!(File.read!(@source), @source)
      assert names == @names
    end

    test "a deck renders a diagram from the source option" do
      diagram = Builder.diagram(source: "flowchart LR\n  a --> b", lang: :mermaid)
      svg = [diagram] |> one_slide() |> document() |> screen(".diagram > svg")

      assert count(svg, ~s(g[id^="a->b-"][data-graph-kind="edge"])) == 1
    end

    test "Pele measures each text with the widths of the theme font" do
      {svg, _names} = Pele.draw!("flowchart LR\n  a[mmmmmmmmmm] --> b[iiiiiiiiii]", "inline")

      [wide, narrow] =
        for {"rect", attrs, _} <- svg |> Floki.parse_fragment!() |> Floki.find("g.pele-node rect"),
            do: attrs |> Map.new() |> Map.fetch!("width") |> Float.parse() |> elem(0)

      # The two boxes have the same padding, so the difference of their widths
      # is the difference of the texts in the theme font, at 16 pixels.
      widths =
        Expresso.Element.Diagram.Font.advances(Expresso.Element.Diagram.Font.builtin(), "mi")["0"]

      expected = 10 * (widths["109"] - widths["105"]) * 16

      assert_in_delta wide - narrow, expected, 1
    end

    test "Pele writes the family of the font, and a syntax error stops the render with its message" do
      {svg, _names} = Pele.draw!("flowchart LR\n  a --> b", "inline")
      assert svg =~ "Atkinson Hyperlegible"

      assert_raise ArgumentError, ~r/Node did not draw the diagram "bad.mmd".*Parse error/s, fn ->
        Pele.draw!("flowchart LR\n  a --> ", "bad.mmd")
      end
    end
  end
end
