defmodule Expresso.Lexers.Typst do
  @moduledoc """
  The Makeup lexer of Typst

  A heading, such as `== Results`, is a heading, and markup on a line,
  such as `*strong*` and `_emphasis_`, gets its style. An expression after
  `#`, such as `#set` or `#figure`, is a keyword or a function. Raw text in
  backticks is a string, math between `$` is a string, and a label such as
  `<intro>` or a reference such as `@intro` is a label. A number can have a
  unit, such as `12pt` or `1fr`.
  """

  use Expresso.Lexer, language: :typst

  ident = [?a..?z, ?A..?Z, ?0..?9, ?_, ?-]

  heading =
    ascii_string([?=], min: 1)
    |> string(" ")
    |> concat(rest_of_line())
    |> lexeme()
    |> token(:generic_heading)

  expression =
    string("#")
    |> ascii_string([?a..?z, ?A..?Z, ?_], 1)
    |> optional(ascii_string(ident, min: 1))
    |> lexeme()
    |> token(:name_function)

  label =
    string("<")
    |> ascii_string(ident ++ [?:, ?.], min: 1)
    |> string(">")
    |> lexeme()
    |> token(:name_label)

  reference =
    string("@") |> ascii_string(ident ++ [?:, ?.], min: 1) |> lexeme() |> token(:name_label)

  units = ~w(pt mm cm in em fr deg rad %)

  dimension =
    ascii_string([?0..?9], min: 1)
    |> optional(string(".") |> ascii_string([?0..?9], min: 1))
    |> optional(units |> Enum.map(&string/1) |> choice())
    |> lookahead_not(ascii_char([?a..?z, ?A..?Z]))
    |> lexeme()
    |> token(:number)

  bullet = choice([string("- "), string("+ ")]) |> token(:keyword)

  # A word with no `#` is most often a word of the text, so only the
  # keywords after `#` are keywords.
  keywords =
    ~w(#let #set #show #import #include #if #else #for #while #return #break #continue #context)

  deflexer(
    [
      line_start(heading),
      line_start(bullet),
      whitespace(),
      line_comment("//"),
      delimited("/*", "*/", :comment_multiline),
      delimited("```", "```", :string_heredoc),
      inline("`", "`", :string_backtick),
      delimited("$", "$", :string, escape: "\\"),
      delimited(~s("), ~s("), :string_double, escape: "\\"),
      expression,
      label,
      reference,
      inline("*", "*", :generic_strong),
      inline("_", "_", :generic_emph),
      dimension,
      word([?a..?z, ?A..?Z], ident),
      operators(["=>", "==", "!=", "<=", ">=", "+=", "=", ":", "..", "+", "*", "/"]),
      punctuation(~c"()[]{},;")
    ],
    words(keywords, :keyword),
    [:name_function]
  )
end
