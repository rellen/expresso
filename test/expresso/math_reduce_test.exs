defmodule Expresso.Element.Math.ReduceTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.{Math, MathLine, MathReduce, MathRewrite, On, Part}
  alias Expresso.Element.Math.{Links, Rewrite}

  defp reduce(tex, redex \\ "r") do
    case Rewrite.expand([%MathLine{tex: tex}, %MathReduce{redex: redex}]) do
      {:ok, [old, new]} -> {old, new}
      {:error, message} -> {:error, message}
    end
  end

  test "a reduction with two bound variables writes the new line, its links and its copies" do
    {old, new} = reduce(~S"\part{r}{(\lambda f.\,f\,(f\,x))\,g}")

    # The old line gets the parts of the redex.
    assert old.tex =~ ~S"\part{lam-2}{(\lambda f.}"
    assert old.tex =~ ~S"\part{close-2}{)}"
    assert old.tex =~ ~S"\part{arg-2}{g}"
    assert old.tex |> String.split(~S"\part{bound-2}{f}") |> length() == 3

    # Each bound variable becomes a copy of the argument, and the rest moves.
    assert new.tex ==
             ~S"\part{r}{\from{arg-2}{g}\,\from{keep-2-1}{(}\from{arg-2}{g}\,\from{keep-2-2}{x)}}"

    assert {new.relation, new.why_tex} == {~S"\to_\beta", "f := g"}
  end

  test "an inner λ with the same variable keeps its own variable" do
    {_old, new} = reduce(~S"\part{r}{(\lambda f.\,f\,(\lambda f.\,f))\,g}")
    assert new.tex =~ ~S"\from{arg-2}{g}"
    assert new.tex =~ ~S"\lambda f.\,f"
  end

  test "an argument of more than one variable gets parentheses in each place" do
    {_old, new} = reduce(~S"\part{r}{(\lambda f.\,f\,x)\,(a\,b)}")
    assert new.tex == ~S"\part{r}{\from{arg-2}{(a\,b)}\,\from{keep-2-1}{x}}"

    {_old, new} = reduce(~S"\part{r}{(\lambda f.\,x\,f)\,(\lambda y.\,y)}")
    assert new.tex =~ ~S"\from{arg-2}{(\lambda y.\,y)}"
  end

  test "a redex with no bound variable becomes its body, with the reason of the variable" do
    {_old, new} = reduce(~S"\part{r}{(\lambda f.\,y)\,a}")
    assert new.tex == ~S"\part{r}{\from{body-2}{y}}"
    assert new.why_tex == "f := a"
  end

  test "a reduction gives an error for a missing part, a part with no redex, a capture and a line that is not a λ-term" do
    assert {:error, message} = reduce(~S"(\lambda f.\,f)\,g")
    assert message =~ ~s(the reduce of the line 2 of a math element: the line has no part "r")

    assert {:error, message} = reduce(~S"\part{r}{f\,g}")
    assert message =~ ~s(the part "r" holds no redex)

    assert {:error, message} = reduce(~S"\part{r}{(\lambda f.\,\lambda x.\,f\,x)\,x}")
    assert message =~ "captures the free variable x of the argument"

    assert {:error, message} = reduce(~S"\part{r}{x + y}")
    assert message =~ "is not a λ-term"

    assert Rewrite.expand([%MathReduce{redex: "r"}]) ==
             {:error, "a reduce of a math element needs a line before it"}
  end

  test ":leftmost takes the redex of normal order, and needs no part" do
    {_old, new} = reduce(~S"x\,((\lambda f.\,f)\,y)\,((\lambda g.\,g)\,z)", :leftmost)

    assert new.tex ==
             ~S"\from{keep-2-1}{x\,(}\from{arg-2}{y}\from{keep-2-2}{)\,((\lambda g.\,g)\,z)}"

    assert {:error, message} = reduce("x\\,y", :leftmost)
    assert message =~ "the line has no redex"
  end

  test "a redex that crosses a part of the line gives an error" do
    assert {:error, message} = reduce(~S"\part{r}{(\lambda \part{p}{f.\,f})\,g}")
    assert message =~ "the redex crosses a part or a link of the line"
  end

  test "the DSL takes a reduce with the name of a part" do
    defmodule ReduceDeck do
      use Expresso

      slide "reduce" do
        math do
          reveal true
          line tex: ~S"\part{r}{(\lambda f.\,f\,(f\,x))\,g}"
          reduce "r"
        end
      end
    end

    assert {:ok, deck} = Expresso.to_deck(ReduceDeck)
    [math] = hd(deck.slides).elements
    assert math.line_names == ["line1", "line2"]
    assert math.tex =~ ~S"\from{arg-2}{g}"
    assert math.tex =~ "f := g"
  end

  test "a reduction takes four steps, with the colors of the binder and of the argument" do
    {_old, new} = reduce(~S"\part{r}{(\lambda f.\,f\,(f\,x))\,g}")

    assert new.steps == 4

    assert new.rewrite == %{
             steps: 4,
             colors: [
               {"lam-2", "var(--binder)", 1},
               {"arg-2", "var(--argument)", 1},
               {"hit-2", "var(--binder)", 2}
             ],
             keep: 3,
             rest: 4
           }
  end

  test "steps puts the phases of a reduction or of a rewrite together in groups" do
    lines = [
      %MathLine{tex: ~S"\part{r}{(\lambda f.\,f)\,g}"},
      %MathReduce{redex: "r", steps: [[:redex, :bound], :body, :argument]}
    ]

    assert {:ok, [_old, new]} = Rewrite.expand(lines)
    assert new.steps == 3
    assert Enum.map(new.rewrite.colors, &elem(&1, 2)) == [1, 1, 1]
    assert {new.rewrite.keep, new.rewrite.rest} == {2, 3}

    lines = [
      %MathLine{tex: "x + 1"},
      %MathRewrite{replace: "1", by_tex: "2", steps: [[:occurrences, :kept], :copies]}
    ]

    assert {:ok, [_old, new]} = Rewrite.expand(lines)
    assert {new.steps, new.rewrite.keep, new.rewrite.rest} == {2, 1, 2}

    lines = [
      %MathLine{tex: "x + 1"},
      %MathRewrite{replace: "1", by_tex: "2", steps: [[:occurrences, :kept, :copies]]}
    ]

    assert {:ok, [_old, new]} = Rewrite.expand(lines)
    assert {new.steps, new.rewrite.keep, new.rewrite.rest} == {1, 1, 1}
  end

  test "steps must hold each phase once, in its order" do
    lines = [
      %MathLine{tex: ~S"\part{r}{(\lambda f.\,f)\,g}"},
      %MathReduce{redex: "r", steps: [:bound, :redex, :body, :argument]}
    ]

    assert {:error, message} = Rewrite.expand(lines)

    assert message =~
             "the steps of the line 2 of a math element must hold :redex, :bound, :body, " <>
               ":argument once each, in this order"

    lines = [
      %MathLine{tex: "x + 1"},
      %MathRewrite{replace: "1", by_tex: "2", steps: [:occurrences]}
    ]

    assert {:error, message} = Rewrite.expand(lines)
    assert message =~ "must hold :occurrences, :kept, :copies once each"
  end

  test "at render, each part gets its color and each copy moves at the step of its phase" do
    # The MathML of a reduction as Temml writes it, with the parts of the old
    # line and the links of the new line.
    mathml =
      ~S(<math><mrow data-line="line1"><mi data-part="lam-2">λf.</mi><mi class="hit-2">f</mi><mi data-part="keep-2-1">x</mi><mi data-part="arg-2">g</mi></mrow><mrow data-line="line2"><mi data-from="arg-2">g</mi><mi data-from="keep-2-1">x</mi></mrow></math>)

    next = fn step -> %On{steps: Enum.to_list(step..5)} end

    math = %Math{
      text: mathml,
      line_names: ["line1", "line2"],
      rewrite_lines: %{
        "line2" => %{
          steps: 4,
          colors: [
            {"lam-2", "var(--binder)", 1},
            {"arg-2", "var(--argument)", 1},
            {"hit-2", "var(--binder)", 2}
          ],
          keep: 3,
          rest: 4
        }
      },
      elements: [
        %Part{id: "line1", steps: [1, 2, 3, 4, 5]},
        %Part{id: "line2", steps: [2, 3, 4, 5], on: [next.(3), next.(4), next.(5)]}
      ]
    }

    %Math{elements: parts} = Links.place(math)
    by_id = Map.new(parts, &{&1.id, &1})

    assert by_id["line2"].steps == [5]
    assert by_id["line2"].on == []

    assert Enum.map(by_id["lam-2"].on, &{&1.steps, &1.set}) == [
             {[2, 3, 4, 5], [color: "var(--binder)"]}
           ]

    assert Enum.map(by_id["arg-2"].on, &{&1.steps, &1.set}) == [
             {[2, 3, 4, 5], [color: "var(--argument)"]}
           ]

    assert Enum.map(by_id["hit-2"].on, &{&1.steps, &1.set}) == [
             {[3, 4, 5], [color: "var(--binder)"]}
           ]

    assert by_id["arg-2@link-1"].steps == [5]
    assert by_id["keep-2-1@link-2"].steps == [4, 5]
  end

  @tag :temml
  test "the theme gives the colors of the binder and of the argument to a rendered reduction" do
    defmodule ReduceColorDeck do
      use Expresso

      slide "reduce colors" do
        math do
          reveal true
          line tex: ~S"(\lambda f.\,f\,x)\,g"
          reduce :leftmost
        end
      end
    end

    document = ReduceColorDeck |> Expresso.to_deck() |> elem(1) |> Expresso.Deck.render()

    for property <- ["--binder:", "--binder-dim:", "--argument:", "--argument-dim:"],
        do: assert(document =~ property)

    assert document =~ "var(--binder)"
    assert document =~ "var(--argument)"
  end
end
