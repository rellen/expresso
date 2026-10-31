defmodule Expresso.Element.Math.RuleTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.{MathLine, MathRewrite}
  alias Expresso.Element.Math.{Latex, Rewrite, Rule}

  doctest Rule

  defp match(tex, left, right, vars, scope \\ nil) do
    {:ok, atoms} = Latex.parse(tex)

    case Rule.match(atoms, left, right, vars, scope, 2) do
      {:ok, old, template} -> {Latex.write(old), template}
      {:error, message} -> {:error, message}
    end
  end

  test "a variable binds a group in parentheses, and the match skips spaces" do
    assert match("k (x + h)", ~S"a\,b", "b a", ~w(a b)) ==
             {~S"\part{rule-2}{\part{var-2-a}{k} \part{var-2-b}{(x + h)}}",
              ~S"\use{var-2-b} \use{var-2-a}"}
  end

  test "a variable that occurs two times binds equal LaTeX" do
    assert {old, ~S"2\,\use{var-2-a}"} = match("y + x + x", "a + a", ~S"2\,a", ~w(a))
    assert old == ~S"y + \part{rule-2}{\part{var-2-a}{x} + x}"

    assert {:error, message} = match("x + y", "a + a", ~S"2\,a", ~w(a))
    assert message =~ "matches nothing in its old line"
  end

  test "a variable takes its scripts, unless the pattern puts a script after it" do
    assert {~S"\part{rule-2}{\part{var-2-a}{x^2}}", _template} = match("x^2", "a", "a", ~w(a))

    assert {~S"\part{rule-2}{\part{var-2-a}{x}^2}", ~S"\use{var-2-a}\cdot \use{var-2-a}"} =
             match("x^2", "a^2", ~S"a\cdot a", ~w(a))
  end

  test "a command of the pattern matches its groups in full" do
    assert {~S"\part{rule-2}{\frac{\part{var-2-a}{1}}{\part{var-2-b}{x}}}", _template} =
             match(~S"\frac{1}{x}", ~S"\frac{a}{b}", ~S"a \cdot b^{-1}", ~w(a b))
  end

  test "the scope limits the match to a part, and the match looks inside a part" do
    tex = ~S"a + b = \part{p}{a + b}"

    assert {~S"a + b = \part{p}{\part{rule-2}{\part{var-2-x}{a} + \part{var-2-y}{b}}}", _template} =
             match(tex, "x + y", "y + x", ~w(x y), "p")

    assert {~S"\part{rule-2}{\part{var-2-x}{a} + \part{var-2-y}{b}} = \part{p}{a + b}", _template} =
             match(tex, "x + y", "y + x", ~w(x y))
  end

  test "a variable of the right side must be in the left side" do
    assert {:error, message} = match("x", "a", "a + b", ~w(a b))
    assert message =~ ~s(the variable "b" of a rule is in its right side)
  end

  test "a rewrite with a rule makes the new line, with a copy of each bound part" do
    {:ok, [old, new]} =
      Rewrite.expand([
        %MathLine{tex: ~S"y = k\,(x + h)"},
        %MathRewrite{rule: {~S"a\,(b + c)", ~S"a\,b + a\,c"}, vars: ~w(a b c)}
      ])

    assert old.tex =~ ~S"\class{hit-2}{\part{rule-2}{\part{var-2-a}{k}"

    assert new.tex ==
             ~S"\from{keep-2-1}{y} \mathrel{\from{keep-2-2}{=}} \from{var-2-a}{k}\,\from{var-2-b}{x} + \from{var-2-a}{k}\,\from{var-2-c}{h}"

    assert new.why_tex == ~S"k\,(x + h) := k\,x + k\,h"
  end

  test "a rule gives an error for no match, and rule is one of the options of the content" do
    line = %MathLine{tex: "x"}

    assert {:error, message} =
             Rewrite.expand([line, %MathRewrite{rule: {"a + b", "b + a"}, vars: ~w(a b)}])

    assert message =~ "the rule of the rewrite of the line 2 of a math element matches nothing"

    assert {:error, message} =
             Rewrite.expand([line, %MathRewrite{rule: {"a", "a"}, by_tex: "y", vars: ~w(a)}])

    assert message =~ "takes one of the options by, by_tex, to and rule"
  end

  test "the DSL takes a rule with its variables" do
    defmodule RuleDeck do
      use Expresso

      slide "rule" do
        math do
          reveal true
          line tex: ~S"y = k\,(x + h)"
          rewrite rule: {~S"a\,(b + c)", ~S"a\,b + a\,c"}, vars: ~w(a b c), why: "distribute"
        end
      end
    end

    assert {:ok, deck} = Expresso.to_deck(RuleDeck)
    [math] = hd(deck.slides).elements
    assert math.tex =~ ~S"\from{var-2-b}{x}"
  end
end
