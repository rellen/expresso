defmodule Expresso.Element.Math.RewriteTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.{MathLine, MathRewrite}
  alias Expresso.Element.Math.Rewrite

  @redex ~S"\part{lam}{(\lambda f.}\,\part{body}{f\,(f\,x)}\part{close}{)}\,\part{arg}{g}"

  defp beta(opts \\ []) do
    struct!(
      MathRewrite,
      [
        relation: ~S"\to_\beta",
        replace: "f",
        within: "body",
        by: "arg",
        drop: ["lam", "close", "arg"]
      ] ++ opts
    )
  end

  test "a substitution with two occurrences writes the new line, its links and its copies" do
    {:ok, [old, new]} = Rewrite.expand([%MathLine{tex: @redex}, beta()])

    # Each run of kept symbols gets a part in the old line, and each
    # occurrence the class of the rewrite.
    assert old.tex ==
             ~S"\part{lam}{(\lambda f.}\,\part{body}{\class{hit-2}{f}\,\part{keep-2-1}{(}\class{hit-2}{f}\,\part{keep-2-2}{x)}}\part{close}{)}\,\part{arg}{g}"

    # Each occurrence becomes a copy of the argument, and each kept run a link.
    assert new.tex ==
             ~S"\part{body}{\from{arg}{g}\,\from{keep-2-1}{(}\from{arg}{g}\,\from{keep-2-2}{x)}}"

    assert new.relation == ~S"\to_\beta"

    # The new line takes three steps, and its default reason is in LaTeX.
    assert new.steps == 3
    assert new.rewrite == %{hit: "hit-2", by: "arg"}
    assert new.why_tex == "f := g"
  end

  test "the reason of a rewrite is its why, or the replaced part and the new content" do
    line = %MathLine{tex: ~S"\part{n}{a + b} \cdot 2"}

    {:ok, [_old, new]} = Rewrite.expand([line, %MathRewrite{replace: "n", by_tex: "c"}])
    assert {new.why, new.why_tex} == {nil, "a + b := c"}

    {:ok, [_old, new]} =
      Rewrite.expand([line, %MathRewrite{replace: "n", by_tex: "c", why: "sum"}])

    assert {new.why, new.why_tex} == {"sum", nil}
  end

  test "without within, each occurrence of the line is replaced, and by_tex gives new LaTeX" do
    {:ok, [old, new]} =
      Rewrite.expand([
        %MathLine{tex: ~S"A = \pi r^2 + r"},
        %MathRewrite{replace: "r", by_tex: "3"}
      ])

    assert old.tex ==
             ~S"\part{keep-2-1}{A = \pi} \class{hit-2}{r}^2 \part{keep-2-2}{+} \class{hit-2}{r}"

    assert new.tex == ~S"\from{keep-2-1}{A = \pi} 3^2 \from{keep-2-2}{+} 3"
    assert new.relation == "="
  end

  test "a base of more than one atom goes into a group, so its index stays on the whole base" do
    {:ok, [_old, new]} =
      Rewrite.expand([%MathLine{tex: "x^2"}, %MathRewrite{replace: "x", by_tex: "a + b"}])

    assert new.tex == "{a + b}^2"
  end

  test "replace can name a part, and a text command is not a symbol" do
    {:ok, [_old, new]} =
      Rewrite.expand([
        %MathLine{tex: ~S"\part{n}{x} + x\,\text{if x}"},
        %MathRewrite{replace: "n", by_tex: "y"}
      ])

    assert new.tex == ~S"y \from{keep-2-1}{+ x\,\text{if x}}"
  end

  test "a rewrite of a rewrite reads the links of the old line as their bodies" do
    {:ok, [_l1, _l2, l3]} =
      Rewrite.expand([
        %MathLine{tex: ~S"\part{a}{x} + y"},
        %MathRewrite{replace: "y", by_tex: "z"},
        %MathRewrite{replace: "z", by: "a"}
      ])

    assert l3.tex == ~S"\from{keep-3-1}{\part{a}{x} +} \from{a}{x}"
  end

  test "from reads a line with a name, and the lines keep their names" do
    {:ok, lines} =
      Rewrite.expand([
        %MathLine{tex: "x", name: "first"},
        %MathLine{tex: "y"},
        %MathRewrite{replace: "x", by_tex: "1", from: "first", name: "last"}
      ])

    assert Enum.map(lines, &{&1.name, &1.tex}) == [
             {"first", ~S"\class{hit-3}{x}"},
             {nil, "y"},
             {"last", "1"}
           ]
  end

  test "a rewrite gives an error for each missing name" do
    line = %MathLine{tex: @redex}

    assert Rewrite.expand([beta()]) ==
             {:error, "a rewrite of a math element needs a line before it"}

    assert {:error, message} = Rewrite.expand([line, beta(by: "nothing")])
    assert message =~ ~s(takes the part "nothing", and no line before it)

    assert {:error, message} = Rewrite.expand([line, beta(within: "nothing")])
    assert message =~ ~s(names the part "nothing", and its old line has no part)

    assert {:error, message} = Rewrite.expand([line, beta(drop: ["nothing"])])
    assert message =~ ~s(names the part "nothing")

    assert {:error, message} = Rewrite.expand([line, beta(replace: "y")])
    assert message =~ ~s(finds no "y" to replace)

    assert {:error, message} = Rewrite.expand([line, beta(from: "nothing")])
    assert message =~ ~s(reads the line "nothing")

    assert {:error, message} = Rewrite.expand([line, beta(by: nil)])
    assert message =~ "takes the by option or the by_tex option"

    assert {:error, message} = Rewrite.expand([line, beta(by_tex: "1")])
    assert message =~ "and not both"
  end

  test "the DSL takes a rewrite after a line, and the math element gets two lines" do
    defmodule RewriteDeck do
      use Expresso

      slide "rewrite" do
        math do
          reveal true

          line tex:
                 ~S"\part{lam}{(\lambda f.}\,\part{body}{f\,(f\,x)}\part{close}{)}\,\part{arg}{g}"

          rewrite ~S"\to_\beta",
            replace: "f",
            within: "body",
            by: "arg",
            drop: ["lam", "close", "arg"],
            why: "f := g"
        end
      end
    end

    assert {:ok, deck} = Expresso.to_deck(RewriteDeck)
    [math] = hd(deck.slides).elements
    assert math.line_names == ["line1", "line2"]
    assert math.tex =~ ~S"\from{arg}{g}"
    assert math.tex =~ ~S"\text{f := g}"
  end
end
