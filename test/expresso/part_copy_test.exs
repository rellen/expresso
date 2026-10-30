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

      copies = [Builder.copy("target", at: 2), Builder.copy("station", at: 2, as: "x")]

      assert_raise ArgumentError, ~r/two parts or copies have the name "x"/, fn ->
        diagram([Builder.part("token", copies: copies), Builder.part("x")])
      end
    end

    test "a copy needs the at option" do
      assert_raise ArgumentError, ~r/required :at option not found/, fn ->
        Builder.copy("target")
      end
    end

    test "a part of a math element takes no copy yet" do
      part = Builder.part("bind", copies: [Builder.copy("arg", at: 2)])

      assert_raise ArgumentError, ~r/a part of a math element takes no copy entity yet/, fn ->
        Builder.math(~S(<math><mi data-part="bind">f</mi><mi data-part="arg">g</mi></math>),
          elements: [part]
        )
      end
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
