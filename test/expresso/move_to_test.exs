defmodule Expresso.MoveToTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Element.Diagram.{Geometry, Path}

  doctest Geometry
  doctest Path

  @svg "test/fixtures/move.svg"

  defp tree, do: @svg |> File.read!() |> Floki.parse_fragment!()

  describe "Geometry.distance/3" do
    test "goes from the center of a rect to the center of a circle" do
      # The token has the center (20, 20), and the target (320, 120).
      assert Geometry.distance(tree(), "token", "target") == {:ok, {300.0, 100.0}}
    end

    test "reads the transform of each parent of the target" do
      # The station is a box from (200, 50) to (240, 70), with its center at (220, 60).
      assert Geometry.distance(tree(), "token", "station") == {:ok, {200.0, 40.0}}
    end

    test "gives the distance in the coordinates of the parent of the moved element" do
      # The small rect has the center (15, 65) in its group, and (30, 130) in the
      # file. The group scales by 2, so 300 units of the file are 150 units of
      # the group.
      assert Geometry.distance(tree(), "small", "target") == {:ok, {145.0, -5.0}}
    end

    test "measures a path from each of its points" do
      # The points go from (100, 145) to (140, 155).
      assert Geometry.distance(tree(), "token", "arrow") == {:ok, {100.0, 130.0}}
    end

    test "takes the point of a text" do
      assert Geometry.distance(tree(), "token", "label") == {:ok, {30.0, 170.0}}
    end

    test "gives an error for an id that the file does not have, and for an element with no shape" do
      assert Geometry.distance(tree(), "token", "nothing") ==
               {:error, ~s(has no element with the id "nothing")}

      assert Geometry.distance(tree(), "token", "name") ==
               {:error, ~s(has no shape to measure in the element with the id "name")}
    end
  end

  describe "Path.points/1" do
    test "reads the absolute and the relative form of each command" do
      assert Path.points(
               "M0,0 C 10 0 20 10 20 20 S 30 40 40 40 Q 50 40 50 50 T 60 60 A 5 5 0 0 1 70 70"
             ) ==
               [
                 {0.0, 0.0},
                 {10.0, 0.0},
                 {20.0, 10.0},
                 {20.0, 20.0},
                 {30.0, 40.0},
                 {40.0, 40.0},
                 {50.0, 40.0},
                 {50.0, 50.0},
                 {60.0, 60.0},
                 {70.0, 70.0}
               ]

      assert Path.points("m 10 10 20 0 v 10 H 0 Z l 5 5") ==
               [{10.0, 10.0}, {30.0, 10.0}, {30.0, 20.0}, {0.0, 20.0}, {15.0, 15.0}]
    end

    test "reads numbers with no space between them" do
      assert Path.points("M.5-.5L1e1,2") == [{0.5, -0.5}, {10.0, 2.0}]
    end
  end

  describe "the render" do
    defp deck(on) do
      part = Builder.part("token", on: on)

      [Builder.slide("one", steps: 2, elements: [Builder.diagram(@svg, elements: [part])])]
      |> Builder.deck()
    end

    test "writes the distance as x and y at the steps of the on entity" do
      html = deck([Builder.on(2, move_to: "target")]) |> Expresso.Deck.render()

      assert html =~ ~s(section[data-step="2"] [data-el="s1-e2"] { --x: 300px; --y: 100px; })
    end

    test "keeps the other keys of set" do
      html =
        deck([Builder.on(2, move_to: "station", set: [scale: 1.5])]) |> Expresso.Deck.render()

      assert html =~ "{ --x: 200px; --y: 40px; --scale: 1.5; }"
    end

    test "raises for a target that the file does not have" do
      assert_raise ArgumentError,
                   ~s(the diagram "#{@svg}" has no element with the id "nowhere"),
                   fn ->
                     [Builder.on(2, move_to: "nowhere")] |> deck() |> Expresso.Deck.render()
                   end
    end
  end

  describe "the verifier" do
    test "refuses move_to outside a part" do
      assert_raise Spark.Error.DslError, ~r/only an on entity of a part takes it/, fn ->
        Builder.deck([
          Builder.slide("one",
            steps: 2,
            elements: [Builder.text_area(text: "a", on: [Builder.on(2, move_to: "x")])]
          )
        ])
      end
    end

    test "refuses x or y in the set of an on entity with move_to" do
      assert_raise Spark.Error.DslError, ~r/its set has no x and no y/, fn ->
        deck([Builder.on(2, move_to: "target", set: [x: "10px"])])
      end
    end

    test "accepts move_to in the DSL" do
      source = """
      defmodule Expresso.MoveToTest.DslDeck do
        use Expresso

        slide "one" do
          diagram "test/fixtures/move.svg" do
            part "token" do
              on 2, move_to: "target"
            end
          end
        end
      end
      """

      [{module, _bytecode}] = Code.compile_string(source)
      html = module |> Expresso.parse() |> Expresso.Deck.render()

      assert html =~ "--x: 300px; --y: 100px;"
    end
  end
end
