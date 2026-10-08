defmodule Expresso.Lexers.Rst do
  @moduledoc """
  The Makeup lexer of reStructuredText

  A section title, with the line of `=`, `-` or another mark under it, is a
  heading. A directive, such as `.. code-block:: elixir`, is a keyword, and
  another line that starts with `..` is a comment. A field, such as
  `:author:`, is an attribute. Markup on a line, such as `**strong**`,
  `*emphasis*`, ``` ``code`` ``` and a role such as `` :ref:`intro` ``, gets
  its style.
  """

  use Expresso.Lexer, language: :rst

  marks = [?=, ?-, ?~, ?^, ?", ?', ?`, ?#, ?*, ?+, ?:, ?., ?_]

  underline =
    ascii_string(marks, min: 3)
    |> lookahead(choice([string("\n"), string("\r\n"), eos()]))
    |> token(:generic_heading)

  # A title is a line of text with an underline on the next line.
  title =
    ascii_string([?A..?Z, ?a..?z, ?0..?9], 1)
    |> concat(rest_of_line())
    |> lexeme()
    |> lookahead(choice([string("\n"), string("\r\n")]) |> ascii_string(marks, min: 3))
    |> token(:generic_heading)

  # The name of a directive can hold a colon, such as `py:function`, so the
  # rule stops at the first `::`.
  directive =
    string("..")
    |> string(" ")
    |> times(lookahead_not(string("::")) |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?-, ?_, ?:], 1),
      min: 1
    )
    |> string("::")
    |> lexeme()
    |> token(:keyword)

  comment = string("..") |> concat(rest_of_line()) |> lexeme() |> token(:comment_single)

  field =
    string(":")
    |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?-, ?_, ?\s], min: 1)
    |> string(":")
    |> lexeme()
    |> token(:name_attribute)

  role =
    string(":")
    |> times(lookahead_not(string(":`")) |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?-, ?_, ?:], 1),
      min: 1
    )
    |> string(":")
    |> lexeme()
    |> token(:name_builtin)
    |> concat(
      string("`")
      |> utf8_string([not: ?`, not: ?\n], min: 1)
      |> string("`")
      |> lexeme()
      |> token(:string_other)
    )

  bullet = choice([string("- "), string("* "), string("+ "), string("#. ")]) |> token(:keyword)

  link =
    string("`")
    |> utf8_string([not: ?`, not: ?\n], min: 1)
    |> string("`_")
    |> optional(string("_"))
    |> lexeme()
    |> token(:string_other)

  deflexer(
    [
      line_start(underline, indent: false),
      line_start(title, indent: false),
      line_start(directive),
      line_start(comment),
      line_start(field),
      line_start(bullet),
      whitespace(),
      inline("``", "``", :string_backtick),
      inline("**", "**", :generic_strong),
      inline("*", "*", :generic_emph),
      role,
      link,
      inline("`", "`", :string_other),
      operators(["::"]),
      word([?a..?z, ?A..?Z, ?0..?9], [?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?'])
    ],
    %{}
  )
end
