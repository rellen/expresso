defmodule Expresso.LexersTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Expresso.Lexers

  @lexers [
    Lexers.Cabal,
    Lexers.D2,
    Lexers.Dhall,
    Lexers.Kdl,
    Lexers.Nix,
    Lexers.Toml,
    Lexers.Yaml
  ]

  doctest Expresso.Lexer

  # The type of each token, with its text, and with no white space.
  defp tokens(lexer, text) do
    for {type, _meta, value} <- lexer.lex(text), type != :whitespace, do: {type, value}
  end

  # The text of the tokens joined together.
  defp joined(lexer, text), do: Enum.map_join(lexer.lex(text), fn {_, _, value} -> value end)

  property "each lexer reads each text, and its tokens give the text back" do
    check all text <- string(:printable, max_length: 80),
              lines <- list_of(member_of(["", "\n", "\n  ", "[a]\n", "# x\n"]), max_length: 3) do
      text = Enum.join(lines) <> text

      for lexer <- @lexers do
        assert joined(lexer, text) == text, inspect(lexer)
      end
    end
  end

  test "each lexer reads an empty text" do
    for lexer <- @lexers, do: assert(lexer.lex("") == [])
  end

  test "TOML: a key, a table header, a date and a header that is an array" do
    tokens =
      tokens(Lexers.Toml, ~s([server]\nwhen = 1979-05-27T07:32:00Z\nports = [ 1, 2 ] # x\n))

    assert {:keyword_namespace, "[server]"} in tokens
    assert {:name_attribute, "when"} in tokens
    assert {:literal_date, "1979-05-27T07:32:00Z"} in tokens
    assert {:comment_single, "# x"} in tokens
    refute {:keyword_namespace, "[ 1, 2 ]"} in tokens
  end

  test "TOML: a string of several lines is one token" do
    assert {:string_heredoc, ~s("""\na\nb""")} in tokens(Lexers.Toml, ~s(s = """\na\nb"""))
  end

  test "YAML: a key, a document marker, an anchor, an alias, a tag and a constant" do
    tokens =
      tokens(Lexers.Yaml, "---\non: push\nbase: &b\n  x: !!str 1\nother: *b\nok: true\n")

    assert {:keyword, "---"} in tokens
    assert {:name_tag, "on"} in tokens
    assert {:name_label, "&b"} in tokens
    assert {:name_label, "*b"} in tokens
    assert {:keyword_type, "!!str"} in tokens
    assert {:keyword_constant, "true"} in tokens
  end

  test "KDL: a node name, a property, a type annotation, a constant and a slashdash" do
    tokens = tokens(Lexers.Kdl, "package {\n  (date)made \"2024\" draft=#false\n  /- old 1\n}\n")

    assert {:name_tag, "package"} in tokens
    assert {:keyword_type, "(date)"} in tokens
    assert {:name_tag, "made"} in tokens
    assert {:name_attribute, "draft"} in tokens
    assert {:keyword_constant, "#false"} in tokens
    assert {:comment, "/- old 1"} in tokens
  end

  test "Nix: a keyword, an attribute, a path, a built-in and an indented string" do
    tokens =
      tokens(
        Lexers.Nix,
        "let\n  src = ./src;\n  a = x == 1;\n  s = ''\n    hi\n  '';\nin import <nixpkgs>"
      )

    assert {:keyword, "let"} in tokens
    assert {:name_attribute, "src"} in tokens
    assert {:string_other, "./src"} in tokens
    assert {:name_attribute, "a"} in tokens
    assert {:name, "x"} in tokens
    assert {:operator, "=="} in tokens
    assert {:string_heredoc, "''\n    hi\n  ''"} in tokens
    assert {:name_builtin, "import"} in tokens
    assert {:string_other, "<nixpkgs>"} in tokens
  end

  test "Dhall: a type, a built-in, an import, a field and the operators of Unicode" do
    tokens =
      tokens(
        Lexers.Dhall,
        "let T : Type = { n : Natural }\nin λ(x : T) → List/length env:HOME -- c"
      )

    assert {:keyword_type, "Type"} in tokens
    assert {:keyword_type, "Natural"} in tokens
    assert {:name_attribute, "n"} in tokens
    assert {:operator, "λ"} in tokens
    assert {:operator, "→"} in tokens
    assert {:name_builtin, "List/length"} in tokens
    assert {:string_other, "env:HOME"} in tokens
    assert {:comment_single, "-- c"} in tokens
  end

  test "Cabal: a field, a section, a version, a condition and a comment" do
    tokens =
      tokens(Lexers.Cabal, "-- c\nlibrary\n  build-depends: base >=4.18 && <5\n  if os(linux)\n")

    assert {:comment_single, "-- c"} in tokens
    assert {:keyword, "library"} in tokens
    assert {:name_attribute, "build-depends"} in tokens
    assert {:number, "4.18"} in tokens
    assert {:operator, ">="} in tokens
    assert {:name_builtin, "os"} in tokens
  end

  test "D2: a reserved key, a key, a connection and a block string" do
    tokens = tokens(Lexers.D2, "a -> b: hi\nb: {\n  style.fill: \"#fff\"\n}\nn: |md # T|\n")

    assert {:operator, "->"} in tokens
    assert {:name_tag, "b"} in tokens
    assert {:keyword, "style"} in tokens
    assert {:keyword, "fill"} in tokens
    assert {:string_double, ~s("#fff")} in tokens
    assert {:string_heredoc, "|md # T|"} in tokens
  end

  test "Expresso.Highlight colors each new language" do
    for {language, text} <- [
          {"toml", "a = 1"},
          {"yaml", "a: 1"},
          {"yml", "a: 1"},
          {"kdl", "a 1"},
          {"nix", "a = 1;"},
          {"dhall", "let a = 1 in a"},
          {"cabal", "name: a"},
          {"d2", "a -> b"}
        ] do
      assert language in Expresso.Highlight.languages()
      assert [line] = Expresso.Highlight.lines(text, language)
      assert line =~ ~s(class="), language
    end
  end
end
