defmodule Expresso.LexersTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Expresso.Lexers

  @lexers [
    Lexers.Cabal,
    Lexers.D2,
    Lexers.Dhall,
    Lexers.Elisp,
    Lexers.Fennel,
    Lexers.Haskell,
    Lexers.Kdl,
    Lexers.Latex,
    Lexers.Nix,
    Lexers.Org,
    Lexers.Rst,
    Lexers.Toml,
    Lexers.Typst,
    Lexers.Yaml
  ]

  doctest Expresso.Lexer

  # The type of each token, with its text, and with no white space.
  defp tokens(lexer, text) do
    for {type, _meta, value} <- lexer.lex(text), type != :whitespace, do: {type, value}
  end

  # The text of the tokens joined together.
  defp joined(lexer, text), do: Enum.map_join(lexer.lex(text), fn {_, _, value} -> value end)

  # Pieces of the syntax of the languages, so that a random text holds the
  # marks of comments, strings, markup and escapes, and characters of more
  # than one byte.
  @pieces [
    "\n",
    "\r\n",
    "\t",
    " ",
    "*",
    "/",
    "=",
    "`",
    "``",
    "$",
    "\\",
    "#",
    "#+",
    "..",
    "::",
    ":",
    "-",
    "--",
    "{-",
    "-}",
    "\"",
    "'",
    "''",
    "[",
    "]",
    "[[",
    "<",
    ">",
    "@",
    "_",
    "~",
    "|",
    "a",
    "Ab",
    "1",
    "0x",
    "{",
    "}",
    "(",
    ")",
    "%",
    ";",
    ",",
    "λ",
    "é"
  ]

  property "each lexer reads each text, and its tokens give the text back" do
    check all text <-
                one_of([
                  string(:printable, max_length: 80),
                  map(list_of(member_of(@pieces), max_length: 40), &Enum.join/1)
                ]),
              max_runs: 300 do
      for lexer <- @lexers do
        assert joined(lexer, text) == text, inspect(lexer)
      end
    end
  end

  test "Haskell: an escape before a character of more than one byte" do
    assert joined(Lexers.Haskell, "'\\é") == "'\\é"
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

  test "Emacs Lisp: a definition, a keyword, a built-in, a character and a quotation" do
    tokens =
      tokens(
        Lexers.Elisp,
        "; c\n(defun f (x)\n  (let ((y ?a)) (message \"%s\" :k 'x #'f nil (+ 1 x))))"
      )

    assert {:comment_single, "; c"} in tokens
    assert {:keyword, "defun"} in tokens
    assert {:name_function, "f"} in tokens
    assert {:keyword, "let"} in tokens
    assert {:string_char, "?a"} in tokens
    assert {:name_builtin, "message"} in tokens
    assert {:string_symbol, ":k"} in tokens
    assert {:operator, "'"} in tokens
    assert {:operator, "#'"} in tokens
    assert {:keyword_constant, "nil"} in tokens
    assert {:operator, "+"} in tokens
    assert {:number, "1"} in tokens
  end

  test "Fennel: a definition, a local, a built-in, a keyword string and an argument" do
    tokens =
      tokens(
        Lexers.Fennel,
        "(fn greet [n] (print (.. \"hi \" n)))\n(local x :a)\n(hashfn (* $1 2))"
      )

    assert {:keyword, "fn"} in tokens
    assert {:name_function, "greet"} in tokens
    assert {:name_builtin, "print"} in tokens
    assert {:operator, ".."} in tokens
    assert {:keyword, "local"} in tokens
    assert {:name_function, "x"} in tokens
    assert {:string_symbol, ":a"} in tokens
    assert {:name_variable, "$1"} in tokens
  end

  test "Haskell: a pragma, a definition, a type, a keyword, a character and an operator" do
    tokens =
      tokens(
        Lexers.Haskell,
        "{-# LANGUAGE GADTs #-}\nimport Data.Map\nf :: Int -> Int\nf x = x `div` 2 -- c\n  where y' = 'a'\n"
      )

    assert {:comment_preproc, "{-# LANGUAGE GADTs #-}"} in tokens
    assert {:keyword, "import"} in tokens
    assert {:keyword_type, "Data"} in tokens
    assert {:name_function, "f"} in tokens
    assert {:operator, "::"} in tokens
    assert {:keyword_type, "Int"} in tokens
    assert {:operator, "->"} in tokens
    assert {:operator, "`div`"} in tokens
    assert {:comment_single, "-- c"} in tokens
    assert {:keyword, "where"} in tokens
    assert {:name, "y'"} in tokens
    assert {:string_char, "'a'"} in tokens
  end

  test "Haskell: an operator that starts with two dashes is not a comment" do
    assert {:operator, "-->"} in tokens(Lexers.Haskell, "a --> b")
    assert {:comment_single, "--- c"} in tokens(Lexers.Haskell, "a --- c")
  end

  test "Org: a heading with a state, a keyword line, a drawer, markup, a link and a date" do
    tokens =
      tokens(
        Lexers.Org,
        "#+TITLE: T\n* TODO Write\n  :END:\n  - a *b* /c/ =d= ~e~ [[x][y]] <2026-10-08 Thu>\n"
      )

    assert {:comment_preproc, "#+TITLE: T"} in tokens
    assert {:generic_heading, "* "} in tokens
    assert {:keyword, "TODO"} in tokens
    assert {:generic_heading, " Write"} in tokens
    assert {:name_attribute, ":END:"} in tokens
    assert {:keyword, "- "} in tokens
    assert {:generic_strong, "*b*"} in tokens
    assert {:generic_emph, "/c/"} in tokens
    assert {:string_backtick, "=d="} in tokens
    assert {:string_backtick, "~e~"} in tokens
    assert {:string_other, "[[x][y]]"} in tokens
    assert {:literal_date, "<2026-10-08 Thu>"} in tokens
  end

  test "Org: a star with no closing star is text" do
    refute Enum.any?(tokens(Lexers.Org, "a * b"), &match?({:generic_strong, _}, &1))
  end

  test "rst: a title, a field, a directive, a comment, markup, a role and a link" do
    tokens =
      tokens(
        Lexers.Rst,
        "Title\n=====\n\n:author: R\n\n**a** *b* ``c`` :ref:`d` `e <f>`_\n\n.. note::\n\n.. c\n"
      )

    assert {:generic_heading, "Title"} in tokens
    assert {:generic_heading, "====="} in tokens
    assert {:name_attribute, ":author:"} in tokens
    assert {:generic_strong, "**a**"} in tokens
    assert {:generic_emph, "*b*"} in tokens
    assert {:string_backtick, "``c``"} in tokens
    assert {:name_builtin, ":ref:"} in tokens
    assert {:string_other, "`d`"} in tokens
    assert {:string_other, "`e <f>`_"} in tokens
    assert {:keyword, ".. note::"} in tokens
    assert {:comment_single, ".. c"} in tokens
  end

  test "LaTeX: a command, a structure command, an environment, math, an escape and a comment" do
    tokens =
      tokens(
        Lexers.Latex,
        "\\section{A}\n\\begin{itemize} \\textbf{b} $x^2$ 50\\% % c\n\\end{itemize}"
      )

    assert {:keyword, "\\section"} in tokens
    assert {:keyword, "\\begin"} in tokens
    assert {:name_tag, "{itemize}"} in tokens
    assert {:name_function, "\\textbf"} in tokens
    assert {:string, "$x^2$"} in tokens
    assert {:string_escape, "\\%"} in tokens
    assert {:comment_single, "% c"} in tokens
    assert {:keyword, "\\end"} in tokens
  end

  test "Typst: a heading, markup, a keyword, a function, a label, a reference and a unit" do
    tokens =
      tokens(
        Lexers.Typst,
        "= Title\n*a* and _b_ `c` $x$ <l> @l\n#set text(size: 12pt)\n#figure()\n// c\n"
      )

    assert {:generic_heading, "= Title"} in tokens
    assert {:generic_strong, "*a*"} in tokens
    assert {:name, "and"} in tokens
    assert {:generic_emph, "_b_"} in tokens
    assert {:string_backtick, "`c`"} in tokens
    assert {:string, "$x$"} in tokens
    assert {:name_label, "<l>"} in tokens
    assert {:name_label, "@l"} in tokens
    assert {:keyword, "#set"} in tokens
    assert {:number, "12pt"} in tokens
    assert {:name_function, "#figure"} in tokens
    assert {:comment_single, "// c"} in tokens
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
          {"d2", "a -> b"},
          {"elisp", "(defun a ())"},
          {"emacs-lisp", "(setq a 1)"},
          {"fennel", "(fn a [])"},
          {"fnl", "(local a 1)"},
          {"haskell", "main = print 1"},
          {"hs", "data A = A"},
          {"org", "* A"},
          {"orgmode", "* A"},
          {"rst", ".. note::"},
          {"restructuredtext", ".. note::"},
          {"latex", "\\section{A}"},
          {"tex", "\\section{A}"},
          {"typst", "= A"},
          {"typ", "#set a()"}
        ] do
      assert language in Expresso.Highlight.languages()
      assert [line] = Expresso.Highlight.lines(text, language)
      assert line =~ ~s(class="), language
    end
  end
end
