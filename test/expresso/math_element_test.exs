defmodule Expresso.Element.MathTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Diagram.Cache
  alias Expresso.Element.Math

  doctest Math

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

  defmodule PartDeck do
    use Expresso

    name "part deck"

    slide "parts" do
      math ~S(<math><mrow data-part="redex"><mi data-part="bind">f</mi><mi class="arg x">g</mi></mrow></math>) do
        part "bind" do
          on 2, set: [color: "red"]
        end

        part "arg", at: [from: 3]
      end
    end
  end

  defmodule LinesDeck do
    use Expresso

    name "lines deck"

    slide "proof" do
      math do
        reveal true
        line tex: ~S"Y\,g"
        line "=", tex: ~S"(\lambda f.\,f)\,g", why: "the definition of Y"
        line ~S"\to_\beta", tex: "g", why: "f := g & 50% {x}", name: "reduce"

        part "line2" do
          on 3, state: :alert
        end
      end
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

  describe "the names of the parts" do
    test "a part name starts with a letter, and holds letters, digits, - and _" do
      assert %Math{} = Builder.math(tex: ~S"\part{redex}{x} + \part{line-1_b}{y}")

      assert_raise ArgumentError, ~r/the part name "a,b"/, fn ->
        Builder.math(tex: ~S"\id{a,b}{x}")
      end

      for name <- ["a,b", "1st", "a=b", ""] do
        assert_raise ArgumentError,
                     ~r/the part name "#{Regex.escape(name)}" of a math element/,
                     fn ->
                       Builder.math(tex: "\\part{#{name}}{x}")
                     end
      end
    end

    test "parts/1 gives the data-part and the classes of the MathML, in order, without a repeat" do
      mathml =
        ~s(<math><mrow data-part="redex"><mi data-part="bind">f</mi><mi class="f bound">f</mi>) <>
          ~s(<mi class="f">f</mi></mrow></math>)

      assert Math.parts(mathml) == ["redex", "bind", "f", "bound"]
    end

    @tag :temml
    test "\\part gives each sub-term its data-part, and \\class its class" do
      tex = ~S"\part{redex}{(\lambda \part{bind}{f}.\,f)\,\part{arg}{g}} + \class{rest}{h}"
      [{:ok, mathml}] = Math.Tex.render!([tex])

      assert Math.parts(mathml) -- ["tml-display"] == ["redex", "bind", "arg", "rest"]

      tree = Floki.parse_fragment!(mathml)
      assert Floki.text(Floki.find(tree, ~s([data-part="arg"]))) == "g"
      assert Floki.text(Floki.find(tree, ~s([data-part="bind"]))) == "f"
    end
  end

  describe "the part entity" do
    test "a math element holds parts, and a part gets its steps" do
      [slide] = Expresso.parse(PartDeck).slides
      assert [%Math{elements: [bind, arg]}] = slide.elements
      assert %Expresso.Element.Part{id: "bind", on: [%{steps: [2]}]} = bind
      assert %Expresso.Element.Part{id: "arg", steps: [3]} = arg
    end

    test "the render puts the overlay attributes and the class math-part on each element of a part" do
      document = document(PartDeck)

      bind = LazyHTML.query(document, ~s(#slide-1 .math mi[data-part="bind"]))
      arg = LazyHTML.query(document, "#slide-1 .math mi.arg")

      assert LazyHTML.attribute(bind, "class") == ["math-part"]
      assert [_el] = LazyHTML.attribute(bind, "data-el")
      assert LazyHTML.attribute(arg, "class") == ["math-part arg x"]
      assert LazyHTML.attribute(arg, "data-on") == ["3"]

      redex = LazyHTML.query(document, ~s(#slide-1 .math mrow[data-part="redex"]))
      assert LazyHTML.attribute(redex, "class") == []
    end

    test "a part with a name that the formula does not have stops the render" do
      math = Builder.math(@formula, elements: [Builder.part("redex")])
      deck = Builder.deck([Builder.slide("a", elements: [math])])

      assert_raise ArgumentError, ~r/the math element has no part with the name "redex"/, fn ->
        Expresso.Deck.render(deck)
      end
    end

    test "a part of a math element takes no move_to" do
      part = Builder.part("bind", on: [Builder.on(2, move_to: "arg")])

      assert_raise ArgumentError, ~r/a part of a math element takes no move_to/, fn ->
        Builder.math(@formula, elements: [part])
      end
    end
  end

  describe "the line entity" do
    test "the lines become one aligned formula, a row and a part for each line" do
      [slide] = Expresso.parse(LinesDeck).slides
      [%Math{tex: tex, lines: [], reveal: false, elements: parts}] = slide.elements

      assert tex ==
               Enum.join(
                 [
                   "\\begin{aligned}",
                   ~S" & \part{line1}{Y\,g} \\",
                   ~S"\part{line2}{=} & \part{line2}{(\lambda f.\,f)\,g} && \part{line2}{\text{the definition of Y}} \\",
                   ~S"\part{reduce}{\to_\beta} & \part{reduce}{g} && \part{reduce}{\text{f := g \& 50\% \{x\}}}",
                   "\\end{aligned}"
                 ],
                 "\n"
               )

      assert Enum.map(parts, & &1.id) == ["line1", "line2", "reduce"]
    end

    test "with reveal, each line shows at its own step, and a part of the deck with the name of a line adds to it" do
      [slide] = Expresso.parse(LinesDeck).slides
      [%Math{elements: [line1, line2, reduce]}] = slide.elements

      assert {line1.steps, line2.steps, reduce.steps} == {[1, 2, 3], [2, 3], [3]}
      assert [%{state: :alert, steps: [3]}] = line2.on
    end

    test "without reveal, each line shows at each step" do
      math = Builder.math(lines: [Builder.line(tex: "x"), Builder.line("=", tex: "y")])
      assert Enum.map(math.elements, & &1.at) == [nil, nil]
    end

    test "a math element takes lines, or the MathML, or the tex option, and one only" do
      assert_raise ArgumentError,
                   ~r/takes the MathML, the tex option or line entities, and one only/,
                   fn ->
                     Builder.math(tex: "x", lines: [Builder.line(tex: "y")])
                   end
    end

    @tag :temml
    test "Temml aligns the lines, and each line is a part" do
      document = document(LinesDeck)

      assert count(document, "#slide-1 .math mtable") == 1
      assert count(document, ~s(#slide-1 .math [data-part="line2"].math-part)) == 3

      # Temml writes each space of a text as a space that does not break.
      reasons =
        document |> texts("#slide-1 .math mtext") |> Enum.map(&String.replace(&1, "\u00A0", " "))

      assert reasons == ["the definition of Y", "f := g & 50% {x}"]
    end
  end
end
