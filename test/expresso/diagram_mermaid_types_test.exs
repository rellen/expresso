defmodule Expresso.Element.DiagramMermaidTypesTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Diagram.{Outline, Pele}

  doctest Expresso.Element.Diagram.Pele.Plan

  # The expected names and marks of each type of Pele with a plan, for the
  # fixture `test/fixtures/mermaid/<type>.mmd`:
  #
  #   * `names` - the names of the parts, in the order of the SVG.
  #   * `kinds` - the kind of some parts: `node`, `container` or `edge`.
  #   * `ends` - the two ends of some edges.
  #   * `parents` - the parent of some parts.
  #   * `follow` - two parts with steps, an edge, and the steps of that edge
  #     with `edges :follow`.
  #   * `outline` - the label of the first item of the list for a screen
  #     reader, and the edges of that item.
  @types %{
    "class" => %{
      names: [
        "Reef",
        "note0--Turtle",
        "Animal<-Turtle",
        "Animal<-Shark",
        "Turtle->Shark",
        "Animal<-Whale",
        "Turtle",
        "Shark",
        "Animal",
        "Whale",
        "note0"
      ],
      kinds: %{
        "Reef" => "container",
        "Turtle" => "node",
        "Animal<-Turtle" => "edge",
        "note0--Turtle" => "edge",
        "note0" => "node"
      },
      ends: %{"Animal<-Shark" => {"Animal", "Shark"}, "note0--Turtle" => {"note0", "Turtle"}},
      parents: %{"Turtle" => "Reef", "Shark" => "Reef", "Animal" => nil},
      follow: {[{"Animal", 2}, {"Turtle", 3}], "Animal<-Turtle", "3"},
      outline: {"Reef", []}
    },
    "flowchart" => %{
      names: ["app", "web->api", "api->db", "api->db:2", "cache->db", "web", "api", "db", "cache"],
      kinds: %{"app" => "container", "web" => "node", "web->api" => "edge"},
      ends: %{"api->db:2" => {"api", "db"}},
      parents: %{"web" => "app", "db" => nil},
      follow: {[{"api", 2}, {"db", 3}], "api->db", "3"},
      outline: {"App", []}
    },
    "sequence" => %{
      names: [
        "Customer",
        "Web",
        "API",
        "Customer->Web",
        "Web->API",
        "API->Web",
        "Web->Customer",
        "note1"
      ],
      kinds: %{"Customer" => "node", "Web->API" => "edge", "note1" => "node"},
      ends: %{"API->Web" => {"API", "Web"}},
      parents: %{"Web" => nil},
      follow: {[{"Web", 2}, {"API", 3}], "Web->API", "3"},
      outline: {"One order", []}
    },
    "state" => %{
      names: [
        "Review",
        "root_start->Draft",
        "Draft->Submitted",
        "Review_start->Screening",
        "Screening->Decision",
        "Submitted->Review",
        "Review->Published",
        "Review->Draft",
        "Published->root_end",
        "note1--Draft",
        "root_start",
        "Submitted",
        "Published",
        "root_end",
        "Review_start",
        "Screening",
        "Decision",
        "Draft",
        "note1"
      ],
      kinds: %{
        "Review" => "container",
        "Draft" => "node",
        "root_start" => "node",
        "Review->Published" => "edge",
        "note1" => "node",
        "note1--Draft" => "edge"
      },
      ends: %{"Review->Draft" => {"Review", "Draft"}, "note1--Draft" => {"note1", "Draft"}},
      parents: %{"Screening" => "Review", "Review_start" => "Review", "Draft" => nil},
      follow: {[{"Submitted", 2}, {"Review", 3}], "Submitted->Review", "3"},
      outline: {"Review", ["to Published (approved)", "to Draft (rejected)"]}
    }
  }

  defp result(type),
    do: "test/fixtures/mermaid/#{type}.json" |> File.read!() |> JSON.decode!()

  defp marked(type) do
    {svg, _names} = type |> result() |> Pele.name()

    for {_tag, attrs, _} <- svg |> Floki.parse_fragment!() |> Floki.find("[data-graph-kind]"),
        attrs = Map.new(attrs),
        into: %{},
        do: {attrs["id"], attrs}
  end

  test "each type with a plan has a fixture and an entry in this test" do
    assert Pele.planned() == @types |> Map.keys() |> Enum.sort()

    for type <- Pele.planned(), do: assert(File.exists?("test/fixtures/mermaid/#{type}.json"))
  end

  test "a state of a concurrent region has the composite state as its parent" do
    svg =
      ~s(<svg><g class="pele-cluster" data-id="Active"></g><g class="pele-node" data-id="A"></g></svg>)

    region = %{
      "stmt" => "state",
      "id" => "divider-id-1",
      "type" => "divider",
      "doc" => [%{"stmt" => "state", "id" => "A"}]
    }

    model = %{"rootDoc" => [%{"stmt" => "state", "id" => "Active", "doc" => [region]}]}

    {named, _names} = Pele.name(%{"svg" => svg, "type" => "state", "model" => model})
    assert named =~ ~s(data-id="A" id="A" data-graph-kind="node" data-graph-parent="Active")
  end

  for {type, expected} <- @types do
    @type_name type
    @expected expected

    describe "a #{type}" do
      test "names its parts in the order of the SVG" do
        assert @type_name |> result() |> Pele.name() |> elem(1) == @expected.names
      end

      test "marks its parts with their kinds, their ends and their parents" do
        marked = marked(@type_name)

        for {name, kind} <- @expected.kinds,
            do: assert(marked[name]["data-graph-kind"] == kind, name)

        for {name, {from, to}} <- @expected.ends do
          assert {marked[name]["data-graph-from"], marked[name]["data-graph-to"]} == {from, to}
        end

        for {name, parent} <- @expected.parents,
            do: assert(marked[name]["data-graph-parent"] == parent, name)
      end

      test "gives each element with a data-id an id" do
        {svg, _names} = @type_name |> result() |> Pele.name()

        for {_tag, attrs, _} <- svg |> Floki.parse_fragment!() |> Floki.find("[data-id]") do
          assert List.keymember?(attrs, "id", 0), inspect(attrs)
        end
      end

      test "an edge without a part shows where both of its ends show" do
        {parts, edge, steps} = @expected.follow
        {svg, names} = @type_name |> result() |> Pele.name()

        diagram =
          struct!(
            Builder.diagram("#{@type_name}.mmd",
              elements: for({name, from} <- parts, do: Builder.part(name, at: [from: from]))
            ),
            svg: svg,
            names: names
          )

        rendered = [diagram] |> one_slide() |> document() |> screen(".diagram > svg")
        query = LazyHTML.query(rendered, ~s([data-graph-kind="edge"][id^="#{edge}-"]))

        assert LazyHTML.attribute(query, "data-on") == [steps]
      end

      test "gives a screen reader a list of its parts" do
        {label, edges} = @expected.outline
        {svg, _names} = @type_name |> result() |> Pele.name()

        assert [%{label: ^label, edges: ^edges} | _rest] = Outline.items(svg)
      end
    end
  end
end
