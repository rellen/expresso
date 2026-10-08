defmodule Expresso.Lexers.Lisp do
  @moduledoc """
  The rules that the lexers of Emacs Lisp and Fennel share

  A comment starts with `;`, a keyword such as `:name` is a symbol, and
  the word after a definer, such as the name after `defun`, is a function.
  `Expresso.Lexers.Elisp` and `Expresso.Lexers.Fennel` call `rules/1` with
  their own characters and definers.
  """

  import NimbleParsec
  import Makeup.Lexer.Combinators, only: [token: 2, lexeme: 1]
  import Expresso.Lexer

  @doc """
  The rules of a Lisp

  The options:

    * `:symbol` - the characters of a symbol.
    * `:definers` - the words, such as `"defun"`, that name a function or a
      variable with the word after them.
    * `:quotes` - the operators of quotation, such as `"'"` and `",@"`.
    * `:extra` - more rules, which come before the rule of a symbol.
  """
  @spec rules(keyword()) :: [Expresso.Lexer.combinator()]
  def rules(opts) do
    symbol_chars = Keyword.fetch!(opts, :symbol)
    symbol = ascii_string(symbol_chars, min: 1) |> lexeme()

    definition =
      string("(")
      |> token(:punctuation)
      |> concat(
        Keyword.fetch!(opts, :definers)
        |> Enum.sort_by(&byte_size/1, :desc)
        |> Enum.map(&string/1)
        |> choice()
        |> token(:keyword)
      )
      |> concat(ascii_string([?\s, ?\t], min: 1) |> token(:whitespace))
      |> concat(symbol |> token(:name_function))

    keyword =
      string(":") |> ascii_string(symbol_chars, min: 1) |> lexeme() |> token(:string_symbol)

    [
      whitespace(),
      line_comment(";"),
      delimited(~s("), ~s("), :string_double, escape: "\\"),
      definition,
      keyword
    ] ++
      Keyword.get(opts, :extra, []) ++
      [
        number() |> lookahead_not(ascii_char(symbol_chars)),
        symbol |> token(:name),
        operators(Keyword.fetch!(opts, :quotes)),
        punctuation(~c"()[]{}")
      ]
  end
end
