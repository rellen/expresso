defmodule Expresso.Lexers.Yaml do
  @moduledoc """
  The Makeup lexer of YAML

  A key before `: ` is a tag, an anchor such as `&base` and an alias such as
  `*base` are a label, and a tag such as `!!str` is a type. A marker of a
  document, `---` or `...`, is a keyword. A comment starts at `#` only at the
  start of a line or after white space, so the `#` of `C#` or of a URL is
  text. The lines of a block scalar after `|` or `>` are plain text.

  The lexer keeps the indentation of the line in the context of the parser.
  A block scalar holds each next line that has more indentation than the
  line of its `|` or `>`, and each blank line between them.
  """

  use Expresso.Lexer, language: :yaml

  key_chars = [?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?., ?/, ?\s]
  word_chars = [?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?., ?/]

  marker = choice([string("---"), string("...")]) |> token(:keyword)

  comment = line_comment("#")
  break = choice([string("\r\n"), string("\n")]) |> token(:whitespace)
  indentation = ascii_string([?\s], min: 1) |> token(:whitespace)
  spaces = ascii_string([?\s, ?\t, ?\f], min: 1) |> token(:whitespace)

  # A line break, the indentation, and a marker or a comment at the start of
  # the line. The rule keeps the indentation in the context.
  line =
    break
    |> concat(optional(indentation) |> post_traverse(:indent))
    |> optional(choice([marker, comment]))

  # White space, and a comment after it.
  space = spaces |> optional(comment)

  blank_line =
    break
    |> optional(spaces)
    |> lookahead(choice([string("\r\n"), string("\n"), eos()]))

  content_line =
    break
    |> concat(indentation)
    |> concat(utf8_string([not: ?\n, not: ?\r], min: 1) |> token(:text))

  anchor =
    ascii_string([?&, ?*], 1)
    |> ascii_string(word_chars, min: 1)
    |> lexeme()
    |> token(:name_label)

  tag =
    string("!")
    |> optional(ascii_string([?!, ?a..?z, ?A..?Z, ?0..?9, ?-, ?:, ?/, ?.], min: 1))
    |> lexeme()
    |> token(:keyword_type)

  block =
    ascii_string([?|, ?>], 1)
    |> optional(ascii_string([?-, ?+, ?0..?9], min: 1))
    |> lexeme()
    |> token(:operator)
    |> optional(space)
    |> repeat_while(choice([blank_line, content_line]), :block_line?)

  constants =
    for word <- ~w(true false yes no on off null),
        form <- [word, String.capitalize(word), String.upcase(word)],
        into: %{"~" => :keyword_constant},
        do: {form, :keyword_constant}

  deflexer(
    [
      line,
      space,
      delimited(~s("), ~s("), :string_double, escape: "\\"),
      delimited("'", "'", :string_single),
      key([?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?., ?/, ?<], key_chars ++ [?<], [":"], :name_tag,
        then: [?\s, ?\t, ?\r, ?\n]
      ),
      anchor,
      tag,
      block,
      number(),
      word([?a..?z, ?A..?Z, ?_, ?~], word_chars),
      punctuation(~c"-:,?[]{}")
    ],
    constants
  )

  defp indent(rest, args, context, _line, _offset),
    do: {rest, args, Map.put(context, :indent, width(args))}

  # The next line is a line of the block scalar when it is blank, or when it
  # has more indentation than the line of the `|` or `>`.
  defp block_line?(rest, context, _line, _offset) do
    deeper? = fn indentation -> byte_size(indentation) > Map.get(context, :indent, 0) end

    case Regex.run(~r/\A\r?\n( *)([\t\f ]*(?:\r?\n|\z))?/, rest) do
      [_match, _indentation, _blank] ->
        {:cont, context}

      [_match, indentation] ->
        if deeper?.(indentation), do: {:cont, context}, else: {:halt, context}

      nil ->
        {:halt, context}
    end
  end

  defp width(tokens),
    do: tokens |> Enum.map(fn {_type, _meta, value} -> IO.iodata_length(value) end) |> Enum.sum()
end
