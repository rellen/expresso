defmodule Expresso.Lexers.Latex do
  @moduledoc """
  The Makeup lexer of LaTeX

  A command, such as `\\section` or `\\textbf`, is a function, and
  `\\begin`, `\\end` and the commands of a document's structure are
  keywords. The name of an environment, such as `{itemize}` after
  `\\begin`, is a tag. Math between `$`, `$$`, `\\(` and `\\)`, or `\\[` and
  `\\]` is a string, and a comment starts with `%`.
  """

  use Expresso.Lexer, language: :latex

  command =
    string("\\")
    |> ascii_string([?a..?z, ?A..?Z, ?@], min: 1)
    |> optional(string("*"))
    |> lexeme()
    |> token(:name_function)

  environment =
    choice([string("\\begin"), string("\\end")])
    |> token(:keyword)
    |> concat(
      string("{")
      |> ascii_string([?a..?z, ?A..?Z, ?*], min: 1)
      |> string("}")
      |> lexeme()
      |> token(:name_tag)
    )

  escape = string("\\") |> utf8_string([not: ?\n], 1) |> lexeme() |> token(:string_escape)

  structure =
    ~w(\\documentclass \\usepackage \\part \\chapter \\section \\subsection \\subsubsection
       \\paragraph \\title \\author \\date \\maketitle \\label \\ref \\cite \\newcommand
       \\renewcommand \\input \\include \\item \\caption)

  deflexer(
    [
      whitespace(),
      line_comment("%"),
      delimited("$$", "$$", :string),
      delimited("$", "$", :string, escape: "\\"),
      delimited("\\(", "\\)", :string),
      delimited("\\[", "\\]", :string),
      environment,
      command,
      escape,
      number(),
      word([?a..?z, ?A..?Z], [?a..?z, ?A..?Z, ?0..?9, ?-, ?']),
      operators(["&", "~", "^", "_"]),
      punctuation(~c"{}[]")
    ],
    words(structure, :keyword),
    [:name_function]
  )
end
