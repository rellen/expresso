defmodule Expresso.Element.DiagramOutlineTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Diagram.{D2, Graphviz, Outline}

  # The fixtures of the tools, named as `Diagram.draw/1` names them, so these
  # tests run without the tools.
  defp graphviz,
    do: "test/fixtures/graphviz/flow.svg" |> File.read!() |> Graphviz.name() |> elem(0)

  defp d2, do: "test/fixtures/d2/flow.svg" |> File.read!() |> D2.name() |> elem(0)

  defp drawn(src, svg, opts \\ []), do: struct!(Builder.diagram(src, opts), svg: svg, names: [])

  describe "Outline.items/1" do
    test "a graph of Graphviz: each cluster holds its nodes, and each node has the edges that leave it" do
      assert Outline.items(graphviz()) == [
               %{
                 label: "App",
                 edges: [],
                 children: [
                   %{label: "web", edges: ["to api"], children: []},
                   %{label: "api", edges: ["to db", "to db (replica)"], children: []}
                 ]
               },
               %{label: "db", edges: [], children: []}
             ]
    end

    test "a graph of D2: a connection with <- leaves its second end" do
      assert [_app, _db, %{label: "cache", edges: ["to db"]}] = Outline.items(d2())
    end

    test "an edge with no direction goes with its first end, and an element with no text has its name" do
      svg = """
      <svg><g id="a" data-graph-kind="node"></g><g id="b" data-graph-kind="node"><text>B</text></g>
      <g id="a--b" data-graph-kind="edge" data-graph-from="a" data-graph-to="b" data-graph-arrow="--"></g></svg>
      """

      assert Outline.items(svg) == [
               %{label: "a", edges: ["with B"], children: []},
               %{label: "B", edges: [], children: []}
             ]
    end

    test "an SVG without marks has no items" do
      assert Outline.items(File.read!("test/fixtures/flow.svg")) == []
    end
  end

  describe "the render" do
    test "a graph gets a nested list for a screen reader, and its SVG is hidden from the screen reader" do
      figure =
        [drawn("test/fixtures/graphviz/flow.dot", graphviz())]
        |> one_slide()
        |> document()
        |> screen(".diagram")

      assert count(figure, ~s(.diagram > svg[aria-hidden="true"])) == 1

      assert figure |> texts(".graph-list > li > ul > li") |> Enum.map(&String.trim/1) == [
               "web, to api",
               "api, to db, to db (replica)"
             ]

      assert count(figure, ".graph-list > li") == 2
      assert LazyHTML.attribute(LazyHTML.query(figure, ".graph-list"), "aria-label") == ["Graph"]
    end

    test "a graph with the alt option is one image, with no list" do
      figure =
        [drawn("test/fixtures/d2/flow.d2", d2(), alt: "The system")]
        |> one_slide()
        |> document()
        |> screen(".diagram")

      assert count(figure, ".graph-list") == 0
      assert count(figure, "svg[aria-hidden]") == 0
      assert LazyHTML.attribute(figure, "role") == ["img"]
    end

    test "a diagram of an SVG file gets no list" do
      figure =
        [Builder.diagram("test/fixtures/flow.svg")]
        |> one_slide()
        |> document()
        |> screen(".diagram")

      assert count(figure, ".graph-list") == 0
      assert count(figure, "svg[aria-hidden]") == 0
    end
  end
end
