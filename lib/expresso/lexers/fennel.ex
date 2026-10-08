defmodule Expresso.Lexers.Fennel do
  @moduledoc """
  The Makeup lexer of Fennel

  A special form or a macro, such as `fn` or `local`, is a keyword, and a
  common function of Lua, such as `print`, is a built-in. A multiple value
  of a hash function, such as `$1`, is a variable. See
  `Expresso.Lexers.Lisp` for the rules that the Lisps share.
  """

  use Expresso.Lexer, language: :fennel

  symbol = [
    ?a..?z,
    ?A..?Z,
    ?0..?9,
    ?-,
    ?_,
    ?+,
    ?*,
    ?/,
    ?<,
    ?>,
    ?=,
    ?!,
    ??,
    ?%,
    ?&,
    ?~,
    ?^,
    ?.,
    ?:
  ]

  argument =
    string("$")
    |> optional(ascii_string([?1..?9, ?.], min: 1))
    |> lexeme()
    |> token(:name_variable)

  definers = ~w(fn λ lambda local var global macro defn)

  keywords =
    definers ++
      ~w(let set tset if when do each for while match case case-try match-try macros
         import-macros require-macros quote values doto -> ->> -?> -?>> hashfn partial
         pick-values accumulate collect icollect fcollect faccumulate with-open)

  builtins =
    ~w(print require table string math pairs ipairs tostring tonumber type select error assert
       setmetatable getmetatable unpack os io coroutine next rawget rawset pcall xpcall)

  deflexer(
    Expresso.Lexers.Lisp.rules(
      symbol: symbol,
      definers: definers,
      quotes: ["'", "`", ",", "#", "&"],
      extra: [argument]
    ),
    Map.merge(
      Map.merge(
        words(keywords, :keyword),
        words(~w(.. + - * / // % ^ < > = <= >= not= ?. : and or not), :operator)
      ),
      Map.merge(words(builtins, :name_builtin), words(~w(nil true false), :keyword_constant))
    )
  )
end
