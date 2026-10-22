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
  #     with `edges :follow`, or `nil` for a type with no edges.
  #   * `outline` - the label of the first item of the list for a screen
  #     reader, and the edges of that item.
  @types %{
    "architecture" => %{
      names: [
        "cloud",
        "web->api",
        "api--hub",
        "hub--db",
        "db<->disk",
        "web",
        "api",
        "db",
        "disk",
        "hub"
      ],
      kinds: %{"cloud" => "container", "hub" => "node", "api--hub" => "edge"},
      ends: %{"db<->disk" => {"db", "disk"}},
      parents: %{"web" => "cloud", "hub" => "cloud", "disk" => nil},
      follow: {[{"api", 2}, {"hub", 3}], "api--hub", "3"},
      outline: {"Cloud", []}
    },
    "block" => %{
      names: [
        "store",
        "client->server",
        "server->db",
        "server->cache",
        "client",
        "server",
        "db",
        "cache"
      ],
      kinds: %{"store" => "container", "db" => "node", "server->db" => "edge"},
      ends: %{"server->cache" => {"server", "cache"}},
      parents: %{"db" => "store", "cache" => "store", "client" => nil},
      follow: {[{"server", 2}, {"db", 3}], "server->db", "3"},
      outline: {"store", []}
    },
    "c4" => %{
      names: ["shop", "customer->web", "web->db", "web<->pay", "customer", "pay", "web", "db"],
      kinds: %{"shop" => "container", "customer" => "node", "web->db" => "edge"},
      ends: %{"web<->pay" => {"web", "pay"}},
      parents: %{"web" => "shop", "db" => "shop", "pay" => nil, "shop" => nil},
      follow: {[{"web", 2}, {"db", 3}], "web->db", "3"},
      outline: {"Shop [ENTERPRISE]", []}
    },
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
    "er" => %{
      names: [
        "CUSTOMER--ORDER",
        "ORDER--LINE-ITEM",
        "PRODUCT--LINE-ITEM",
        "CUSTOMER",
        "ORDER",
        "LINE-ITEM",
        "PRODUCT"
      ],
      kinds: %{"CUSTOMER" => "node", "ORDER--LINE-ITEM" => "edge"},
      ends: %{"PRODUCT--LINE-ITEM" => {"PRODUCT", "LINE-ITEM"}},
      parents: %{"ORDER" => nil},
      follow: {[{"ORDER", 2}, {"LINE-ITEM", 3}], "ORDER--LINE-ITEM", "3"},
      outline:
        {"CUSTOMER string name string email", ["with ORDER int id PK date placed (places)"]}
    },
    "flowchart" => %{
      names: ["app", "web->api", "api->db", "api->db:2", "cache->db", "web", "api", "db", "cache"],
      kinds: %{"app" => "container", "web" => "node", "web->api" => "edge"},
      ends: %{"api->db:2" => {"api", "db"}},
      parents: %{"web" => "app", "db" => nil},
      follow: {[{"api", 2}, {"db", 3}], "api->db", "3"},
      outline: {"App", []}
    },
    "gantt" => %{
      names: ["write", "charts", "review", "release", "Build", "Ship"],
      kinds: %{"write" => "node", "release" => "node"},
      ends: %{},
      parents: %{"write" => nil},
      follow: nil,
      outline: {"Write the deck", []}
    },
    "gitGraph" => %{
      names: [
        "main",
        "feature",
        "deck--chart",
        "tests--merge",
        "init--deck",
        "chart--tests",
        "deck--docs",
        "docs--merge",
        "init",
        "deck",
        "chart",
        "tests",
        "docs",
        "merge"
      ],
      kinds: %{"main" => "container", "chart" => "node", "docs--merge" => "edge"},
      ends: %{"tests--merge" => {"tests", "merge"}, "deck--chart" => {"deck", "chart"}},
      parents: %{"chart" => "feature", "merge" => "main", "main" => nil},
      follow: {[{"chart", 2}, {"tests", 3}], "chart--tests", "3"},
      outline: {"main", []}
    },
    "ishikawa" => %{
      names: ["Assets", "Code", "Network", "A slow deck"],
      kinds: %{"Assets" => "node", "A slow deck" => "node"},
      ends: %{},
      parents: %{"Code" => nil},
      follow: nil,
      outline: {"Assets Many fonts Large images", []}
    },
    "journey" => %{
      names: [
        "Before",
        "Write the deck",
        "Check the slides",
        "During",
        "Give the talk",
        "Ask a question",
        "Audience",
        "Presenter",
        "Reviewer"
      ],
      kinds: %{"Before" => "container", "Give the talk" => "node"},
      ends: %{},
      parents: %{"Write the deck" => "Before", "Ask a question" => "During", "Before" => nil},
      follow: nil,
      outline: {"Before Write the deck Check the slides", []}
    },
    "kanban" => %{
      names: ["todo", "charts", "Write the guide", "doing", "mermaid", "done", "trees"],
      kinds: %{"todo" => "container", "charts" => "node", "Write the guide" => "node"},
      ends: %{},
      parents: %{
        "charts" => "todo",
        "Write the guide" => "todo",
        "trees" => "done",
        "todo" => nil
      },
      follow: nil,
      outline: {"To do 2 Add the charts Write the guide", []}
    },
    "mindmap" => %{
      names: [
        "root--Elements",
        "Elements--Code",
        "Elements--Diagram",
        "Elements",
        "Code",
        "Diagram",
        "root--Presenter",
        "Presenter--Keys",
        "Presenter",
        "Keys",
        "root"
      ],
      kinds: %{"root" => "node", "Code" => "node", "Elements--Code" => "edge"},
      ends: %{"root--Presenter" => {"root", "Presenter"}},
      parents: %{"Code" => nil},
      follow: {[{"Elements", 2}, {"Code", 3}], "Elements--Code", "3"},
      outline: {"Elements", ["with Code", "with Diagram"]}
    },
    "packet" => %{
      names: ["0-15", "16-31", "32-47", "48-63", "64-95"],
      kinds: %{"0-15" => "node", "64-95" => "node"},
      ends: %{},
      parents: %{"32-47" => nil},
      follow: nil,
      outline: {"Source Port", []}
    },
    "pie" => %{
      names: ["Slides", "Demo", "Questions"],
      kinds: %{"Slides" => "node", "Questions" => "node"},
      ends: %{},
      parents: %{"Demo" => nil},
      follow: nil,
      outline: {"Slides", []}
    },
    "quadrantChart" => %{
      names: ["quadrant-1", "quadrant-2", "quadrant-3", "quadrant-4", "Themes", "Charts"],
      kinds: %{"quadrant-1" => "node", "Charts" => "node"},
      ends: %{},
      parents: %{"Charts" => nil},
      follow: nil,
      outline: {"Plan", []}
    },
    "radar" => %{
      names: ["x", "y", "axis-a", "axis-b", "axis-c"],
      kinds: %{"x" => "node", "axis-b" => "node"},
      ends: %{},
      parents: %{"y" => nil},
      follow: nil,
      outline: {"x", []}
    },
    "requirement" => %{
      names: ["bundle->fast", "bundle->offline", "offline->fast", "fast", "offline", "bundle"],
      kinds: %{"fast" => "node", "bundle" => "node", "offline->fast" => "edge"},
      ends: %{"bundle->offline" => {"bundle", "offline"}},
      parents: %{"fast" => nil},
      follow: {[{"offline", 2}, {"fast", 3}], "offline->fast", "3"},
      outline: {
        "«Requirement» fast ID 1 Text The page loads in one second Risk High Verification Test",
        []
      }
    },
    "sankey" => %{
      names: [
        "Sales->Revenue",
        "Services->Revenue",
        "Revenue->Costs",
        "Revenue->Profit",
        "Sales",
        "Revenue",
        "Services",
        "Costs",
        "Profit"
      ],
      kinds: %{"Revenue" => "node", "Revenue->Costs" => "edge"},
      ends: %{"Services->Revenue" => {"Services", "Revenue"}},
      parents: %{"Costs" => nil},
      follow: {[{"Revenue", 2}, {"Profit", 3}], "Revenue->Profit", "3"},
      outline: {"Sales", ["to Revenue (60)"]}
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
    },
    "swimlane" => %{
      names: ["Reviewer", "Presenter", "write->review", "review->give", "write", "give", "review"],
      kinds: %{"Reviewer" => "container", "write" => "node", "review->give" => "edge"},
      ends: %{"write->review" => {"write", "review"}},
      parents: %{"write" => "Presenter", "review" => "Reviewer", "Presenter" => nil},
      follow: {[{"write", 2}, {"review", 3}], "write->review", "3"},
      outline: {"Reviewer", []}
    },
    "timeline" => %{
      names: ["Early", "2024", "2024/1", "2025", "2025/1", "2025/2", "Late", "2026", "2026/1"],
      kinds: %{"Early" => "container", "2025" => "container", "2025/2" => "node"},
      ends: %{},
      parents: %{"2025" => "Early", "2025/2" => "2025", "2026/1" => "2026", "Late" => nil},
      follow: nil,
      outline: {"Early 2024 The first slide 2025 Charts Diagrams", []}
    },
    "treemap" => %{
      names: ["Code", "Docs", "Assets", "Elixir", "Guides", "TypeScript", "CSS"],
      kinds: %{"Code" => "container", "Assets" => "container", "CSS" => "node"},
      ends: %{},
      parents: %{"Assets" => "Code", "CSS" => "Assets", "Guides" => "Docs", "Code" => nil},
      follow: nil,
      outline: {"Code 100", []}
    },
    "treeView" => %{
      names: ["lib", "expresso", "diagram.ex", "expresso.ex", "mix.exs"],
      kinds: %{"lib" => "container", "expresso" => "container", "mix.exs" => "node"},
      ends: %{},
      parents: %{"expresso" => "lib", "diagram.ex" => "expresso", "mix.exs" => nil},
      follow: nil,
      outline: {"lib", []}
    },
    "usecase" => %{
      names: [
        "Expresso",
        "Presenter->Talk",
        "Presenter->Notes",
        "Audience->Follow",
        "Talk->Notes",
        "Presenter",
        "Audience",
        "Talk",
        "Follow",
        "Notes"
      ],
      kinds: %{"Expresso" => "container", "Presenter" => "node", "Talk->Notes" => "edge"},
      ends: %{"Audience->Follow" => {"Audience", "Follow"}},
      parents: %{"Talk" => "Expresso", "Presenter" => nil},
      follow: {[{"Presenter", 2}, {"Talk", 3}], "Presenter->Talk", "3"},
      outline: {"Expresso", []}
    },
    "venn" => %{
      names: [
        "Desirable",
        "Feasible",
        "Viable",
        "D1",
        "Desirable|Feasible",
        "Desirable|Feasible|Viable"
      ],
      kinds: %{"Desirable" => "node", "D1" => "node", "Desirable|Feasible" => "node"},
      ends: %{},
      parents: %{"Viable" => nil},
      follow: nil,
      outline: {"Desirable", []}
    },
    "xychart" => %{
      names: ["Shop", "bar2", "line1"],
      kinds: %{"Shop" => "node", "bar2" => "node", "line1" => "node"},
      ends: %{},
      parents: %{"line1" => nil},
      follow: nil,
      outline: {"Shop", []}
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

  test "the edges of an architecture diagram with one data-id get their names in the order of the model" do
    svg = """
    <svg><g class="pele-edge" data-id="a-b"></g><g class="pele-edge" data-id="a-b"></g>
    <g class="pele-edge" data-id="a-b"></g><g class="pele-edge-label" data-id="a-b"></g></svg>
    """

    edge = fn into, title ->
      %{"lhsId" => "a", "rhsId" => "b", "lhsInto" => false, "rhsInto" => into, "title" => title}
    end

    model = %{"edges" => [edge.(true, nil), edge.(true, nil), edge.(false, "calls")]}

    {named, names} = Pele.name(%{"svg" => svg, "type" => "architecture", "model" => model})
    assert names == ["a->b", "a->b:2", "a--b"]
    assert named =~ ~s(class="pele-edge-label" data-id="a-b" id="a--b")
  end

  test "an edge of a block diagram without a head has the arrow --" do
    svg =
      ~s(<svg><g class="pele-edge" data-id="1-a-b"></g><g class="pele-edge" data-id="2-a-b"></g></svg>)

    model = %{
      "edges" => [
        %{
          "id" => "1-a-b",
          "start" => "a",
          "end" => "b",
          "arrowTypeStart" => "arrow_open",
          "arrowTypeEnd" => ""
        },
        %{
          "id" => "2-a-b",
          "start" => "a",
          "end" => "b",
          "arrowTypeStart" => "arrow_point",
          "arrowTypeEnd" => "arrow_cross"
        }
      ]
    }

    assert {_svg, ["a--b", "a<->b"]} =
             Pele.name(%{"svg" => svg, "type" => "block", "model" => model})
  end

  test "each line of a git graph goes from the commit of its parent to its commit" do
    {svg, _names} = "gitGraph" |> result() |> Pele.name()
    tree = Floki.parse_fragment!(svg)

    centers =
      for {_tag, attrs, [{"circle", circle, _} | _]} <- Floki.find(tree, "g.pele-commit"),
          attrs = Map.new(attrs),
          circle = Map.new(circle),
          into: %{},
          do: {attrs["id"], "#{circle["cx"]},#{circle["cy"]}"}

    lines = Floki.find(tree, ~s(g[data-graph-kind="edge"]))
    assert length(lines) == 6

    for {"g", attrs, [{"path", path, _}]} <- lines do
      attrs = Map.new(attrs)
      points = Regex.scan(~r/-?[\d.]+,-?[\d.]+/, Map.new(path)["d"]) |> List.flatten()

      assert {hd(points), List.last(points)} ==
               {centers[attrs["data-graph-from"]], centers[attrs["data-graph-to"]]},
             attrs["id"]
    end
  end

  test "Pele draws each bar series of an XY chart before each line series, and each name follows its series" do
    {svg, _names} = "xychart" |> result() |> Pele.name()

    types =
      for {"g", attrs, _} <- svg |> Floki.parse_fragment!() |> Floki.find(".pele-series"),
          attrs = Map.new(attrs),
          do: {attrs["id"], attrs["class"]}

    assert types == [
             {"Shop", "pele-series pele-bars"},
             {"bar2", "pele-series pele-bars"},
             {"line1", "pele-series pele-line"}
           ]
  end

  test "the label of a point of a quadrant chart gets the name of its point, and a label of a quadrant does not" do
    tree = "quadrantChart" |> result() |> Pele.name() |> elem(0) |> Floki.parse_fragment!()

    assert for(
             {"text", attrs, [text]} <- Floki.find(tree, ".pele-point-labels text"),
             do: {Map.new(attrs)["id"], text}
           ) == [{"Charts", "Charts"}, {"Themes", "Themes"}]

    assert Floki.find(tree, ".pele-quadrant text[id]") == []
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

      test "gives each element with a data-id an id, or a group with the id around it" do
        tree = @type_name |> result() |> Pele.name() |> elem(0) |> Floki.parse_fragment!()

        assert Floki.find(tree, "[data-id]:not([id])") ==
                 Floki.find(tree, "g[id][data-graph-kind] > [data-id]:not([id])")
      end

      if @expected.follow do
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
      end

      test "gives a screen reader a list of its parts" do
        {label, edges} = @expected.outline
        {svg, _names} = @type_name |> result() |> Pele.name()

        assert [%{label: ^label, edges: ^edges} | _rest] = Outline.items(svg)
      end
    end
  end
end
