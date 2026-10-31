defmodule Expresso.Element.Math.LatexTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Expresso.Element.Math.Latex

  doctest Latex

  test "a command takes the brace groups after it, and a part has a name and a body" do
    {:ok, atoms} = Latex.parse(~S"\part{lam}{(\lambda f.}\,\part{body}{f\,(f\,x)}")

    assert [{:command, "\\part", [{:group, _}, {:group, _}]} = lam, {:space, "\\,"}, body] =
             atoms

    assert Latex.name_of(lam) == "lam"
    assert Latex.name_of(body) == "body"
    assert Latex.write(Latex.part(atoms, "body")) == ~S"f\,(f\,x)"
    assert Latex.part(atoms, "nothing") == nil
  end

  test "a command that gives a name takes two groups, so a group after it is its own atom" do
    {:ok, atoms} = Latex.parse(~S"\part{g}{g}{}\frac{a}{b}{c}")

    assert atoms == [
             {:command, "\\part", [{:group, [{:symbol, "g"}]}, {:group, [{:symbol, "g"}]}]},
             {:group, []},
             {:command, "\\frac",
              [{:group, [{:symbol, "a"}]}, {:group, [{:symbol, "b"}]}, {:group, [{:symbol, "c"}]}]}
           ]

    assert Latex.write(atoms) == ~S"\part{g}{g}{}\frac{a}{b}{c}"
  end

  test "a part inside a group or inside a command is found" do
    {:ok, atoms} = Latex.parse(~S"\frac{\part{num}{a + 1}}{2}")
    assert Latex.write(Latex.part(atoms, "num")) == "a + 1"
  end

  test "a number is one symbol, and an operator is one symbol" do
    assert Latex.parse("12.5+x") ==
             {:ok, [{:symbol, "12.5"}, {:symbol, "+"}, {:symbol, "x"}]}
  end

  test "the spaces of LaTeX are spaces" do
    assert {:ok, [{:symbol, "a"}, {:space, "\\quad"}, {:space, "~"}, {:symbol, "b"}]} =
             Latex.parse(~S"a\quad~b")
  end

  test "a brace with no partner gives an error" do
    assert {:error, message} = Latex.parse("{a")
    assert message =~ "has a { with no }"
    assert {:error, message} = Latex.parse("a}")
    assert message =~ "has a } with no {"
  end

  test "write puts a space between a command of letters and a letter" do
    assert Latex.write([{:command, "\\lambda", []}, {:symbol, "x"}]) == ~S"\lambda x"
    assert Latex.write([{:command, "\\lambda", []}, {:symbol, "."}]) == ~S"\lambda."
    assert Latex.write([{:space, "\\,"}, {:symbol, "x"}]) == ~S"\,x"
  end

  # LaTeX from parts that a formula of a talk uses. A command of letters right
  # before a letter is one longer command, so write returns each text as it is.
  defp latex do
    leaf =
      StreamData.member_of(
        ~w[x y f g 2 10 + - = ( ) . \\lambda \\alpha \\to _ ^ \\quad ~] ++ ["\\,", " "]
      )

    StreamData.tree(leaf, fn inner ->
      StreamData.one_of([
        StreamData.map(inner, &"{#{&1}}"),
        StreamData.map(StreamData.tuple({inner, inner}), fn {a, b} -> a <> b end),
        StreamData.map(StreamData.tuple({inner, inner}), fn {a, b} ->
          "\\frac{#{a}}{#{b}}"
        end),
        StreamData.map(inner, &"\\part{p}{#{&1}}")
      ])
    end)
  end

  property "write returns the LaTeX that parse reads" do
    check all(tex <- latex()) do
      {:ok, atoms} = Latex.parse(tex)

      assert Latex.write(atoms) == tex
    end
  end
end
