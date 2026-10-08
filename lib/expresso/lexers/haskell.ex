defmodule Expresso.Lexers.Haskell do
  @moduledoc """
  The Makeup lexer of Haskell

  A name at the first column of a line, such as the name of a type
  signature or of an equation, is a function. A name that starts with a
  capital letter, such as a type, a constructor or a module, is a type. A
  pragma, such as `{-# LANGUAGE GADTs #-}`, is a preprocessor comment, and a
  function in backticks, such as `` `elem` ``, is an operator.
  """

  use Expresso.Lexer, language: :haskell

  lower = [?a..?z, ?_]
  upper = [?A..?Z]
  rest = [?a..?z, ?A..?Z, ?0..?9, ?_, ?']
  symbols = [?!, ?#, ?$, ?%, ?&, ?*, ?+, ?., ?/, ?<, ?=, ?>, ??, ?@, ?\\, ?^, ?|, ?~, ?:, ?-]

  # A line comment starts with two dashes or more, and no other symbol may
  # follow them, so `-->` is an operator.
  comment =
    string("--")
    |> optional(ascii_string([?-], min: 1))
    |> lookahead_not(ascii_char(symbols -- [?-]))
    |> concat(rest_of_line())
    |> lexeme()
    |> token(:comment_single)

  character =
    string("'")
    |> choice([
      string("\\") |> utf8_string([not: ?', not: ?\n], min: 1),
      utf8_string([not: ?', not: ?\n], 1)
    ])
    |> string("'")
    |> lexeme()
    |> token(:string_char)

  backtick =
    string("`")
    |> ascii_string(rest ++ [?A..?Z, ?.], min: 1)
    |> string("`")
    |> lexeme()
    |> token(:operator)

  keywords =
    ~w(module where import qualified as hiding data type newtype class instance deriving family
       let in case of if then else do mdo infix infixl infixr forall default foreign pattern
       proc rec stock anyclass via)

  builtins =
    ~w(map filter foldr foldl foldl' print putStrLn putStr getLine show read return pure fmap
       mapM mapM_ traverse sequence concat concatMap zip zipWith lookup length head tail null
       error undefined fst snd id const flip not otherwise maybe either)

  deflexer(
    [
      line_start(word(lower, rest, :name_function), indent: false),
      whitespace(),
      delimited("{-#", "#-}", :comment_preproc),
      delimited("{-", "-}", :comment_multiline),
      comment,
      delimited(~s("), ~s("), :string_double, escape: "\\"),
      character,
      backtick,
      number() |> lookahead_not(ascii_char(rest)),
      word(upper, rest, :keyword_type),
      word(lower, rest),
      ascii_string(symbols, min: 1) |> token(:operator),
      punctuation(~c"()[],;{}")
    ],
    Map.merge(words(keywords, :keyword), words(builtins, :name_builtin)),
    [:name, :name_function]
  )
end
