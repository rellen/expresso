defmodule Expresso.Lexers.Kdl do
  @moduledoc """
  The Makeup lexer of KDL, versions 1 and 2

  The name of a node at the start of a line is a tag, a property before `=`
  is an attribute, and a type annotation such as `(date)` is a type. `/-`
  comments out the next node, value or block, and the lexer shows the rest
  of its line as a comment.
  """

  use Expresso.Lexer, language: :kdl

  first = [
    ?a..?z,
    ?A..?Z,
    ?_,
    ?-,
    ?.,
    ?$,
    ?@,
    ?:,
    ?!,
    ?^,
    ?~,
    ?|,
    ?<,
    ?>,
    ?*,
    ?&,
    ?%,
    ?+,
    ?\\,
    ?`,
    ?',
    ?,
  ]

  rest = first ++ [?0..?9, ?#, ??]

  name = ascii_string(first, 1) |> optional(ascii_string(rest, min: 1)) |> lexeme()

  annotation =
    string("(")
    |> utf8_string([not: ?), not: ?\n], min: 1)
    |> string(")")
    |> lexeme()
    |> token(:keyword_type)

  constant =
    string("#")
    |> choice([
      string("true"),
      string("false"),
      string("null"),
      string("inf"),
      string("-inf"),
      string("nan")
    ])
    |> lexeme()
    |> token(:keyword_constant)

  raw_string =
    optional(string("r"))
    |> ascii_string([?#], min: 1)
    |> string(~s("))
    |> repeat(lookahead_not(string(~s("#))) |> utf8_string([], 1))
    |> optional(string(~s("#)))
    |> optional(ascii_string([?#], min: 1))
    |> lexeme()
    |> token(:string_other)

  deflexer(
    [
      line_start(optional(annotation) |> concat(name |> token(:name_tag))),
      whitespace(),
      line_comment("//"),
      delimited("/*", "*/", :comment_multiline),
      line_comment("/-", :comment),
      constant,
      raw_string,
      delimited(~s("""), ~s("""), :string_heredoc, escape: "\\"),
      delimited(~s("), ~s("), :string_double, escape: "\\"),
      annotation,
      key(first, rest, ["="], :name_attribute),
      number(),
      word(first, rest),
      operators(["="]),
      punctuation(~c"{};")
    ],
    words(["true", "false", "null"], :keyword_constant)
  )
end
