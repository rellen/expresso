defmodule Expresso.Element.CopyTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Element.{Copy, Part}

  doctest Copy

  @svg "test/fixtures/move.svg"

  defmodule CopyDeck do
    use Expresso

    slide "copy" do
      diagram "test/fixtures/move.svg" do
        part "token" do
          on 2, state: :alert
          copy("target", at: [from: 2])

          copy "station" do
            at from: 3
            as("token-station")
            on [from: 4], state: :dim
          end
        end
      end
    end
  end

  defp diagram(parts), do: Builder.diagram(@svg, elements: parts)

  defp html(parts),
    do: Builder.deck([Builder.slide("a", elements: [diagram(parts)])]) |> Expresso.Deck.render()

  describe "the copy entity" do
    test "each copy becomes a part after its source, with its name, its source and its target" do
      [slide] = Expresso.parse(CopyDeck).slides
      [%{elements: parts}] = slide.elements

      assert Enum.map(parts, &{&1.id, &1.copy_of, &1.copy_to, &1.steps}) == [
               {"token", nil, nil, nil},
               {"token@target", "token", "target", [2, 3, 4]},
               {"token-station", "token", "station", [3, 4]}
             ]

      assert [%Part{copies: []} | _parts] = parts
      assert [%{state: :dim, steps: [4]}] = List.last(parts).on
    end

    test "a copy takes the effect of its part, and its own effect first" do
      part = Builder.part("token", effect: :grow, copies: [Builder.copy("target", at: 2)])
      [_part, copy] = diagram([part]).elements
      assert copy.effect == :grow

      part =
        Builder.part("token",
          effect: :grow,
          copies: [Builder.copy("target", at: 2, effect: :fly_up)]
        )

      [_part, copy] = diagram([part]).elements
      assert copy.effect == :fly_up
    end

    test "a copy to its own part, and two copies with one name, stop the compile" do
      assert_raise ArgumentError, ~r/the part "token" has a copy to itself/, fn ->
        diagram([Builder.part("token", copies: [Builder.copy("token", at: 2)])])
      end

      copies = [Builder.copy("target", at: 2, as: "x"), Builder.copy("station", at: 2, as: "x")]

      assert_raise ArgumentError, ~r/two parts or copies have the name "x"/, fn ->
        diagram([Builder.part("token", copies: copies)])
      end
    end

    test "a copy needs the at option" do
      assert_raise ArgumentError, ~r/required :at option not found/, fn ->
        Builder.copy("target")
      end
    end

    test "a copy of a part of a formula is its own math element after the formula" do
      part = Builder.part("bind", copies: [Builder.copy("arg", at: 2)])

      math =
        Builder.math(
          ~S(<math display="block"><mrow><mi data-part="bind">f</mi><mi data-part="arg">g</mi></mrow></math>),
          elements: [part]
        )

      document =
        Builder.deck([Builder.slide("a", elements: [math])])
        |> Expresso.Deck.render()
        |> LazyHTML.from_document()

      [copy] = LazyHTML.query(document, ".screen .math math.math-copy") |> Enum.to_list()

      assert LazyHTML.attribute(copy, "data-part") == ["bind@arg"]
      assert LazyHTML.attribute(copy, "data-copy-of") == ["bind"]
      assert LazyHTML.attribute(copy, "data-move-to") == ["arg"]
      assert LazyHTML.attribute(copy, "aria-hidden") == ["true"]
      assert LazyHTML.attribute(copy, "display") == ["block"]

      # The copy holds a copy of the source with no name of a part, and the
      # formula keeps one element with the name.
      assert LazyHTML.query(copy, "mi") |> LazyHTML.text() == "f"
      assert LazyHTML.query(copy, "[data-part]:not(math)") |> Enum.count() == 0
      assert LazyHTML.query(document, ~s(.screen .math mi[data-part="bind"])) |> Enum.count() == 1
    end
  end

  describe "the copy_to option" do
    test "copy_to gives a copy for each target, from the first step of the on entity" do
      part = Builder.part("token", on: [Builder.on([3, 5..6], copy_to: ["target", "station"])])
      [_part, first, second] = diagram([part]).elements

      assert {first.id, first.copy_to, first.at} ==
               {"token@target", "target", %Expresso.Overlay{pairs: [{3, :max}]}}

      assert {second.id, second.copy_to} == {"token@station", "station"}
    end

    test "an on entity with copy_to keeps its other options, and goes away without them" do
      part =
        Builder.part("token",
          on: [
            Builder.on(2, copy_to: ["target"], state: :alert),
            Builder.on(3, copy_to: ["station"])
          ]
        )

      [token | _copies] = diagram([part]).elements
      assert [%{state: :alert, copy_to: nil}] = token.on
    end

    test "copy_to with :next stops the compile" do
      part = Builder.part("token", on: [Builder.on(:next, copy_to: ["target"])])

      assert_raise ArgumentError, ~r/has copy_to and :next. Give the step as a number/, fn ->
        diagram([part])
      end
    end

    test "copy_to in an element that is not a part stops the compile" do
      text = Builder.text_area(text: "a", on: [Builder.on(2, copy_to: ["x"])])

      assert_raise Spark.Error.DslError,
                   ~r/has copy_to, and only an on entity of a part takes it/,
                   fn ->
                     Builder.deck([Builder.slide("a", elements: [text])])
                   end
    end
  end

  describe "a copy of a copy" do
    test "a part with the name of a copy adds its entities and its copies to that copy" do
      parts = [
        Builder.part("token", copies: [Builder.copy("target", at: [from: 2])]),
        Builder.part("token@target",
          on: [Builder.on(4, state: :dim)],
          copies: [Builder.copy("station", at: [from: 3])]
        )
      ]

      assert [token, copy, second] = diagram(parts).elements
      assert token.id == "token"
      assert {copy.id, copy.copy_of, copy.copy_start} == {"token@target", "token", nil}
      assert [%{state: :dim}] = copy.on

      assert {second.id, second.copy_of, second.copy_to, second.copy_start} ==
               {"token@target@station", "token@target", "station", "target"}
    end

    test "a part with the name of a copy takes no at, and a loop of copies stops the compile" do
      parts = [
        Builder.part("token", copies: [Builder.copy("target", at: 2)]),
        Builder.part("token@target", at: 3)
      ]

      assert_raise ArgumentError, ~r/has the name of a copy, so it takes no at option/, fn ->
        diagram(parts)
      end

      parts = [
        Builder.part("token", copies: [Builder.copy("target", at: 2, as: "a")]),
        Builder.part("a", copies: [Builder.copy("station", at: 3, as: "token")])
      ]

      assert_raise ArgumentError, ~r/make a loop/, fn -> diagram(parts) end
    end

    test "a copy of a copy waits at the target of its source before its first step" do
      parts = [
        Builder.part("token", copies: [Builder.copy("target", at: [from: 2])]),
        Builder.part("token@target", copies: [Builder.copy("station", at: [from: 3])])
      ]

      deck = Builder.deck([Builder.slide("a", elements: [diagram(parts)]), Builder.slide("b")])
      html = Expresso.Deck.render(deck)

      # The second copy is a copy of the first copy, and it moves to the
      # circle at steps 1 and 2.
      assert html =~ ~s(id="token@target@station-)

      assert html =~
               ~r/section\[data-step="1"\] \[data-el="s1-e\d+"\], section\[data-step="2"\] \[data-el="s1-e\d+"\] \{ --x: 300px; --y: 100px; \}/
    end
  end

  describe "the render" do
    test "the copy of the element follows its source, with new ids and no screen reader" do
      document =
        [Builder.part("station", copies: [Builder.copy("target", at: 2)])]
        |> html()
        |> LazyHTML.from_document()

      [copy] =
        LazyHTML.query(document, ~s(.screen .part-copy > g[id^="station@target"]))
        |> Enum.to_list()

      assert LazyHTML.attribute(copy, "aria-hidden") == ["true"]

      [wrapper] = LazyHTML.query(document, ".screen .part-copy") |> Enum.to_list()
      assert LazyHTML.attribute(wrapper, "data-on") == ["2"]

      # The station keeps its id, and the copy holds no element with an id
      # of the file.
      assert Enum.count(LazyHTML.query(document, ~s(.screen [id^="station-"]))) == 1
      assert LazyHTML.query(document, ~s(.part-copy [id="station"])) |> Enum.count() == 0
    end

    test "the copy moves to its target at each of its steps, and waits for the fade at its first step" do
      html = html([Builder.part("token", copies: [Builder.copy("target", at: 2)])])

      assert html =~
               ~r/section\[data-step="2"\] \[data-el="s1-e\d+"\] \{ --x: 300px; --y: 100px; \}/

      assert html =~
               ~r/section\[data-step="2"\] \[data-el="s1-e\d+"\] \{ --move-delay: var\(--dur\); \}/
    end

    test "a target that the file does not have stops the render" do
      assert_raise ArgumentError, ~r/has no element with the id "nothing"/, fn ->
        html([Builder.part("token", copies: [Builder.copy("nothing", at: 2)])])
      end
    end
  end
end
