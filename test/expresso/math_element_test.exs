defmodule Expresso.Element.MathTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Diagram.Cache
  alias Expresso.Element.Math

  @formula ~S(<math display="block"><mfrac><mi>a</mi><mi>b</mi></mfrac></math>)

  defmodule MathDeck do
    use Expresso

    name "math deck"

    slide "formula" do
      math ~S(<math display="block"><mfrac><mi>a</mi><mi>b</mi></mfrac></math>)
    end

    slide "in a box" do
      auto_reveal true

      text_box do
        math ~S(<math><mi>x</mi></math>)
      end

      math ~S(<math><mi>y</mi></math>) do
        on :next, state: :alert
      end
    end
  end

  defmodule TexDeck do
    use Expresso

    name "tex deck"

    slide "formula" do
      math tex: ~S"x^2 + \frac{a}{b}"
    end
  end

  # A function in the place of Temml, so the tests run without Node. It sends
  # the sources of each call, and it gives a fixed MathML for each source.
  defp fake do
    test = self()

    fn sources ->
      send(test, {:typeset, sources})
      Enum.map(sources, &{:ok, "<math><mtext>#{&1}</mtext></math>"})
    end
  end

  defp tex_deck(sources) do
    Builder.deck([Builder.slide("a", elements: Enum.map(sources, &Builder.math(tex: &1)))])
  end

  defp texts(deck), do: for(slide <- deck.slides, math <- slide.elements, do: math.text)

  test "Expresso.Builder.math/1 makes a math element" do
    assert %Math{text: @formula} = Builder.math(@formula)
  end

  test "the DSL entity takes the MathML as its first argument, with the overlays" do
    [formula, box] = Expresso.parse(MathDeck).slides

    assert [%Math{text: @formula, steps: nil}] = formula.elements
    assert [%{elements: [%Math{steps: nil}]}, %Math{steps: [2, 3]} = second] = box.elements
    assert [%{state: :alert, steps: [3]}] = second.on
  end

  describe "render/1" do
    setup do
      {:ok, document: document(MathDeck)}
    end

    test "writes the MathML in one block element inside the root tag", %{document: document} do
      assert count(document, "#slide-1 .math") == 1

      assert [{"div", [], [{"math", [{"display", "block"}], _}]}] =
               document |> LazyHTML.query("#slide-1 .math > div") |> LazyHTML.to_tree()

      assert texts(document, "#slide-1 .math mfrac mi") == ["a", "b"]
    end

    test "writes the overlay attributes on the root tag", %{document: document} do
      [_, second] = document |> LazyHTML.query("#slide-2 .math") |> Enum.to_list()

      assert LazyHTML.attribute(second, "data-on") == ["2 3"]
      assert LazyHTML.attribute(second, "data-el") == ["s2-e3"]
    end
  end

  describe "the tex option" do
    test "the DSL entity takes the LaTeX in the tex option" do
      [formula] = Expresso.parse(TexDeck).slides
      assert [%Math{text: nil, tex: ~S"x^2 + \frac{a}{b}"}] = formula.elements
    end

    test "a math element takes the MathML or the tex option, and not both or neither" do
      assert_raise ArgumentError, ~r/math: a math element takes the MathML as its argument/, fn ->
        Builder.math([])
      end

      assert_raise ArgumentError,
                   ~r/math: a math element takes the MathML or the tex option, and not both/,
                   fn ->
                     Builder.math(@formula, tex: "x")
                   end
    end

    test "typeset/2 makes each source one time, in one call, in the order of the deck" do
      deck = "x" |> List.duplicate(2) |> Kernel.++(["y"]) |> tex_deck()

      assert deck |> Math.typeset(fake()) |> texts() ==
               [
                 "<math><mtext>x</mtext></math>",
                 "<math><mtext>x</mtext></math>",
                 "<math><mtext>y</mtext></math>"
               ]

      assert_received {:typeset, ["x", "y"]}
      refute_received {:typeset, _sources}
    end

    test "typeset/2 keeps the MathML of an element without the tex option, and runs nothing for it" do
      deck = Builder.deck([Builder.slide("a", elements: [Builder.math(@formula)])])

      assert deck |> Math.typeset(fn _sources -> flunk("no source") end) |> texts() == [@formula]
    end

    test "typeset/2 stops the render with the formula and the message of Temml" do
      render = fn _sources -> [{:error, "Unexpected end of input"}] end

      assert_raise ArgumentError,
                   ~r/Temml cannot read the formula "\\\\frac\{a\}\{" of a math element:\n\nUnexpected end of input/,
                   fn -> [~S"\frac{a}{"] |> tex_deck() |> Math.typeset(render) end
    end

    test "the watch mode keeps the MathML of each source from one render to the next" do
      {_deck, cache} = Cache.run(%{}, fn -> ["x", "y"] |> tex_deck() |> Math.typeset(fake()) end)
      assert_received {:typeset, ["x", "y"]}

      {deck, _cache} =
        Cache.run(cache, fn -> ["y", "z"] |> tex_deck() |> Math.typeset(fake()) end)

      assert_received {:typeset, ["z"]}
      assert texts(deck) == ["<math><mtext>y</mtext></math>", "<math><mtext>z</mtext></math>"]
    end

    @tag :temml
    test "the render makes the MathML with Temml" do
      document = document(TexDeck)

      assert count(document, ~s(#slide-1 .math math[display="block"] msup)) == 1
      assert count(document, "#slide-1 .math mfrac") == 1
    end
  end
end
