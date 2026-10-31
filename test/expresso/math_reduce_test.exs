defmodule Expresso.Element.Math.ReduceTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.{MathLine, MathReduce}
  alias Expresso.Element.Math.Rewrite

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
end
