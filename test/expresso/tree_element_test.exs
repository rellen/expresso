defmodule Expresso.TreeElementTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Hierarchy
  alias Expresso.Element.Hierarchy.Layout
  alias Expresso.Element.Node

  doctest Hierarchy
  doctest Layout
  doctest Node

  # The plant: a root with three nodes, and nodes under two of them.
  defp plant(opts \\ []) do
    Builder.tree(
      [
        title: "The plant",
        elements: [
          Builder.node("Ana",
            detail: "Plant manager",
            elements: [
              Builder.node("Ben",
                detail: "Production",
                elements: [Builder.node("Cy"), Builder.node("Di")]
              ),
              Builder.node("Eve", label: "Eve L.", class: "lead"),
              Builder.node("Hal", elements: [Builder.node("Gus")])
            ]
          )
        ]
      ] ++ opts
    )
  end

  defp figure(tree),
    do: tree |> one_slide() |> document() |> screen("figure.tree") |> only!()

  # The number value of an attribute of each element that a selector finds.
  defp numbers(html, selector, attribute) do
    html
    |> LazyHTML.query(selector)
    |> LazyHTML.attribute(attribute)
    |> Enum.map(&String.to_integer/1)
  end

  describe "the layout" do
    test "a node is at the center above the row of its nodes, and the levels have one top each" do
      root = %Node{
        name: "A",
        elements: [
          %Node{name: "B", elements: [%Node{name: "D"}, %Node{name: "E"}]},
          %Node{name: "C"}
        ]
      }

      layout = Layout.top_down(root, [%{width: 100, height: 40}])
      boxes = Map.new(layout.boxes, &{&1.node.name, &1})

      # B holds D and E: 100 + 24 + 100. C is 100 wide, with a gap of 24.
      assert {boxes["D"].x, boxes["E"].x, boxes["C"].x} == {0, 124, 248}
      assert boxes["B"].x == 62
      # A is at the center of the row of 348, and not between B and C.
      assert boxes["A"].x == 124
      assert Enum.map([boxes["A"], boxes["B"], boxes["D"]], & &1.y) == [0, 88, 176]
      assert {layout.width, layout.height} == {348, 216}
    end

    test "a wide parent makes its subtree as wide as its box, and its nodes go to the center" do
      root = %Node{name: "A", elements: [%Node{name: "B"}]}
      layout = Layout.top_down(root, [%{width: 300, height: 40}, %{width: 100, height: 40}])

      assert Enum.map(layout.boxes, &{&1.node.name, &1.x, &1.width}) == [
               {"A", 0, 300},
               {"B", 100, 100}
             ]

      assert layout.width == 300
    end

    test "each level has its size, and the last size applies to each deeper level" do
      root = %Node{name: "A", elements: [%Node{name: "B", elements: [%Node{name: "C"}]}]}
      layout = Layout.top_down(root, [%{width: 200, height: 100}, %{width: 120, height: 60}])

      assert Enum.map(layout.boxes, &{&1.width, &1.height, &1.y}) == [
               {200, 100, 0},
               {120, 60, 148},
               {120, 60, 256}
             ]
    end

    test "a line goes down to the middle of the gap, along, and down to the top of the child" do
      root = %Node{name: "A", elements: [%Node{name: "B"}, %Node{name: "C"}]}
      layout = Layout.top_down(root, [%{width: 100, height: 40}])

      assert layout.lines == ["M112 40 V64 H50 V88", "M112 40 V64 H174 V88"]
    end

    test "a place that is not an integer keeps its fraction" do
      root = %Node{name: "A", elements: [%Node{name: "B"}, %Node{name: "C"}]}
      layout = Layout.top_down(root, [%{width: 101, height: 40}, %{width: 100, height: 40}])

      assert [%{x: 61.5} | _rest] = layout.boxes
    end
  end

  describe "the box option" do
    test "takes one size or a list of sizes" do
      assert Hierarchy.box(width: 1, height: 2) == {:ok, [%{width: 1, height: 2}]}

      assert Hierarchy.box([[height: 2, width: 1], [width: 3, height: 4]]) ==
               {:ok, [%{width: 1, height: 2}, %{width: 3, height: 4}]}
    end

    test "refuses a size with a missing, an extra or a wrong value" do
      for value <- [
            [width: 1],
            [width: 1, height: 2, depth: 3],
            [width: -1, height: 2],
            [width: 1.5, height: 2],
            [[width: 1, height: 2], [width: 1]],
            [],
            "220x96",
            nil
          ] do
        assert {:error, message} = Hierarchy.box(value), inspect(value)
        assert message =~ "a box option takes the width and the height of each level"
      end
    end

    test "sets the size of the boxes in the drawing" do
      figure = figure(plant(box: [[width: 300, height: 120], [width: 200, height: 80]]))

      assert numbers(figure, "foreignObject", "width") == [300, 200, 200, 200, 200, 200, 200]
      assert numbers(figure, "foreignObject", "height") == [120, 80, 80, 80, 80, 80, 80]
    end
  end

  describe "the HTML" do
    test "a box for each node in the order of the tree, with the label and the detail" do
      figure = figure(plant())

      assert texts(figure, ".tree-box .tree-label") ==
               ["Ana", "Ben", "Cy", "Di", "Eve L.", "Hal", "Gus"]

      assert texts(figure, ".tree-box .tree-detail") == ["Plant manager", "Production"]
      assert count(figure, "foreignObject > div.tree-box.lead") == 1

      assert figure |> LazyHTML.query(".tree-box") |> LazyHTML.attribute("xmlns") |> Enum.uniq() ==
               ["http://www.w3.org/1999/xhtml"]
    end

    test "a line for each node under a node, and the default box of 220 by 96" do
      figure = figure(plant())

      assert count(figure, "svg g.tree-lines path.tree-line") == 6
      assert numbers(figure, "foreignObject", "width") |> Enum.uniq() == [220]
      assert numbers(figure, "foreignObject", "height") |> Enum.uniq() == [96]
    end

    test "the svg has the viewBox of the layout and is hidden from a screen reader" do
      root = Hierarchy.check(plant()) |> elem(1) |> Map.fetch!(:elements) |> hd()
      layout = Layout.top_down(root, [%{width: 220, height: 96}])
      [svg] = figure(plant()) |> LazyHTML.query("svg") |> Enum.to_list()

      assert LazyHTML.attribute(svg, "viewBox") == ["0 0 #{layout.width} #{layout.height}"]
      assert LazyHTML.attribute(svg, "aria-hidden") == ["true"]
    end

    test "a nested list with the title holds the tree for a screen reader" do
      figure = figure(plant())
      [list] = figure |> LazyHTML.query("figure > ul.tree-list") |> Enum.to_list()

      assert LazyHTML.attribute(list, "aria-label") == ["The plant"]
      assert count(figure, "ul.tree-list > li") == 1
      assert count(figure, "ul.tree-list > li > ul > li") == 3
      assert count(figure, "ul.tree-list > li > ul > li > ul > li") == 3

      assert figure |> LazyHTML.query("ul.tree-list li") |> Enum.map(&own_text/1) ==
               ["Ana, Plant manager", "Ben, Production", "Cy", "Di", "Eve L.", "Hal", "Gus"]
    end

    test "the width option sets the width of the tree, and a percentage is of the slide" do
      assert figure(plant(width: "70%")) |> LazyHTML.attribute("style") == [
               "--tree-width: 70vw"
             ]

      assert figure(plant(width: "900px")) |> LazyHTML.attribute("style") == [
               "--tree-width: 900px"
             ]

      assert figure(plant()) |> LazyHTML.attribute("style") == []
    end

    test "the overlay options and the class apply to the figure" do
      figure = plant(class: "wide", at: [from: 2]) |> one_slide(steps: 2) |> document()
      figure = figure |> screen("figure.tree") |> only!()

      assert LazyHTML.attribute(figure, "class") == ["tree wide"]
      assert LazyHTML.attribute(figure, "data-on") == ["2"]
    end
  end

  # The text of an item without the text of its nested list.
  defp own_text(item) do
    item
    |> LazyHTML.to_tree()
    |> then(fn [{"li", _attributes, children}] -> children end)
    |> Enum.filter(&is_binary/1)
    |> Enum.join()
    |> String.trim()
  end

  describe "the errors" do
    test "a tree holds one root" do
      assert_raise ArgumentError, ~r/this tree holds none/, fn -> Builder.tree(title: "T") end

      assert_raise ArgumentError, ~r/this tree holds 2. Put the nodes under one root node/, fn ->
        Builder.tree(title: "T", elements: [Builder.node("A"), Builder.node("B")])
      end
    end

    test "two nodes of a tree cannot have the same name" do
      assert_raise ArgumentError,
                   ~r/two nodes with the name "docs".*node "docs-2", label: "docs"/,
                   fn ->
                     Builder.tree(
                       title: "T",
                       elements: [
                         Builder.node("/",
                           elements: [
                             Builder.node("home", elements: [Builder.node("docs")]),
                             Builder.node("docs")
                           ]
                         )
                       ]
                     )
                   end
    end

    test "a node of a tree takes no option of a chart of flows" do
      for option <- [column: 2, order: 1] do
        assert_raise ArgumentError,
                     ~r/the node "B" gives the #{elem(option, 0)} option, and only a node of a chart of flows/,
                     fn ->
                       Builder.tree(
                         title: "T",
                         elements: [Builder.node("A", elements: [Builder.node("B", [option])])]
                       )
                     end
      end
    end

    test "a node of a chart takes no option of a tree" do
      flows = [Builder.flow("A", "B", 1)]

      assert_raise ArgumentError, ~r/the node entity "A" gives the detail option/, fn ->
        Builder.chart(:sankey,
          title: "T",
          flows: flows ++ [Builder.node("A", detail: "x")]
        )
      end

      assert_raise ArgumentError, ~r/the node entity "A" gives the nested node entity/, fn ->
        Builder.chart(:sankey,
          title: "T",
          flows: flows ++ [Builder.node("A", elements: [Builder.node("C")])]
        )
      end
    end

    test "a box option with a wrong value" do
      assert_raise ArgumentError, ~r/a box option takes the width and the height/, fn ->
        plant(box: [width: 0, height: 1])
      end
    end

    test "a tree takes the title" do
      assert_raise ArgumentError, ~r/title/, fn ->
        Builder.tree(elements: [Builder.node("A")])
      end
    end
  end

  describe "the DSL" do
    test "nests nodes to each depth, with the options in the block or after the name" do
      defmodule Deck do
        use Expresso

        slide "s" do
          tree do
            title "The plant"
            box(width: 200, height: 80)

            node "Ana" do
              detail("Plant manager")

              node "Ben" do
                label "Ben B."
                node "Cy", detail: "Press"
              end

              node "Eve"
            end
          end
        end
      end

      assert {:ok, %Expresso.Deck{slides: [%{elements: [tree]}]}} = Expresso.to_deck(Deck)
      assert %Hierarchy{title: "The plant", box: [%{width: 200, height: 80}]} = tree

      assert [
               %Node{
                 name: "Ana",
                 detail: "Plant manager",
                 elements: [
                   %Node{
                     name: "Ben",
                     label: "Ben B.",
                     elements: [%Node{name: "Cy", detail: "Press", elements: []}]
                   },
                   %Node{name: "Eve", elements: []}
                 ]
               }
             ] = tree.elements
    end

    test "gives the error of the check at the compile" do
      assert_raise Spark.Error.DslError, ~r/this tree holds 2/, fn ->
        defmodule TwoRoots do
          use Expresso

          slide "s" do
            tree do
              title "T"
              node "A"
              node "B"
            end
          end
        end
      end
    end

    test "Kernel.node/0 stays in scope in a deck" do
      defmodule KernelNode do
        use Expresso

        def here, do: node()

        slide "s" do
          text_box do
            text_area(text: "x")
          end
        end
      end

      assert KernelNode.here() == Kernel.node()
    end
  end
end
