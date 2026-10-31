defmodule Expresso.Element.Math.LambdaTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Expresso.Element.Math.{Lambda, Latex}

  doctest Lambda

  defp show(tex) do
    {:ok, atoms} = Latex.parse(tex)

    case Lambda.parse(atoms) do
      {:ok, term} -> Lambda.show(term)
      {:error, message} -> {:error, message}
    end
  end

  test "an application groups from the left, and a body goes as far right as it can" do
    assert show("f\\,x\\,y") == "((f x) y)"
    assert show(~S"\lambda x.\,f\,x\,y") == "(λx. ((f x) y))"
    assert show(~S"f\,\lambda x.\,x\,y") == "(f (λx. (x y)))"
    assert show(~S"(\lambda x.\,x)\,y") == "((λx. x) y)"
  end

  test "the Y combinator applied to g" do
    assert show(~S"(\lambda f.\,(\lambda x.\,f\,(x\,x))\,(\lambda x.\,f\,(x\,x)))\,g") ==
             "((λf. ((λx. (f (x x))) (λx. (f (x x))))) g)"
  end

  test "a part, a link, a class and a brace group are transparent, and a variable keeps its scripts" do
    assert show(~S"\part{r}{(\lambda f.\,\from{a}{f}\,x)}\,\class{c}{g}") == "((λf. (f x)) g)"
    assert show("{f}\\,x_1\\,\\alpha") == "((f x_1) \\alpha)"
  end

  test "each term has the indices of its first and last tokens" do
    {:ok, atoms} = Latex.parse(~S"(\lambda f.\,f)\,g")
    {:ok, %{kind: :app, fun: fun, arg: arg} = term} = Lambda.parse(atoms)

    tokens = Lambda.tokens(atoms)
    assert Enum.map(tokens, & &1.text) == ["(", "\\lambda", "f", ".", "f", ")", "g"]
    assert {term.first, term.last} == {0, 6}
    assert {fun.first, fun.last} == {0, 5}
    assert %{kind: :paren, term: %{kind: :abs, var: "f", binder: 2}} = fun
    assert {arg.first, arg.last} == {6, 6}
  end

  test "LaTeX that is not a λ-term gives an error" do
    assert {:error, message} = show("x + y")
    assert message =~ ~s(is not a λ-term at "+")

    assert {:error, message} = show(~S"(\lambda x.\,x")
    assert message =~ "is not a λ-term"

    assert {:error, message} = show(~S"\lambda.\,x")
    assert message =~ "is not a λ-term"

    assert {:error, message} = show("x)")
    assert message =~ ~s|has ")" where it ends|
  end

  # A random term, as a tuple, from the variables f, g, x and y.
  defp terms do
    var = StreamData.map(StreamData.member_of(~w(f g x y)), &{:var, &1})

    StreamData.tree(var, fn inner ->
      StreamData.one_of([
        StreamData.map(StreamData.tuple({StreamData.member_of(~w(f x)), inner}), fn {v, b} ->
          {:abs, v, b}
        end),
        StreamData.map(StreamData.tuple({inner, inner}), fn {a, b} -> {:app, a, b} end)
      ])
    end)
  end

  # The LaTeX of a term, with parentheses where the grammar needs them.
  defp latex({:var, v}), do: v
  defp latex({:abs, v, body}), do: "\\lambda #{v}.\\,#{latex(body)}"
  defp latex({:app, fun, arg}), do: "#{left(fun)}\\,#{right(arg)}"

  defp left({:abs, _v, _body} = term), do: "(#{latex(term)})"
  defp left(term), do: latex(term)

  defp right({:var, _v} = term), do: latex(term)
  defp right(term), do: "(#{latex(term)})"

  defp expected({:var, v}), do: v
  defp expected({:abs, v, body}), do: "(λ#{v}. #{expected(body)})"
  defp expected({:app, fun, arg}), do: "(#{expected(fun)} #{expected(arg)})"

  property "the parser reads each term that the grammar writes" do
    check all(term <- terms()) do
      assert show(latex(term)) == expected(term)
    end
  end
end
