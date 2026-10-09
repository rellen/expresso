defmodule Expresso.Highlight do
  @moduledoc """
  The highlighting of a code element

  `lines/2` makes one HTML fragment for each line of a source text. Makeup
  lexes the text when a lexer package or a lexer of `Expresso.Lexers`
  registers the language, and it escapes each token. Without a lexer for the language, or without a language, the
  function escapes each line and puts it in one `span`, with no class.
  `Expresso.CodeVerifier` gives a warning for a language with no lexer.

  `stylesheet/0` gives the rules of the token classes, and the renderer writes
  them into the document.

  Each fragment holds its line break, and no text node of a fragment is only
  white space. `Expresso.Deck.render/1` writes the document with Floki, and
  Floki drops a text node that is only white space. Therefore the function
  puts each white space token into the span of the token before it, and it
  puts a zero width space into a line that has no other character.
  """

  alias Makeup.Formatters.HTML.HTMLFormatter

  # The role of the theme for each token type, and the style of its font. The
  # roles are custom properties of `Expresso.Palette`, so the colors of a code
  # block come from the theme of the deck. A type that is not here, such as an
  # operator, a variable or punctuation, keeps `--code-text`. The map follows
  # the styling guide of base16, and a variable keeps the color of the text.
  @roles [
    {~w(comment comment_single comment_multiline comment_special comment_hashbang string_doc generic_prompt)a,
     :code_comment, "font-style: italic;"},
    {~w(comment_preproc comment_preproc_file keyword keyword_declaration keyword_namespace keyword_pseudo keyword_reserved operator_word)a,
     :code_keyword, ""},
    {~w(keyword_type name_class name_exception name_namespace)a, :code_type, ""},
    {~w(keyword_constant name_constant name_attribute name_label literal literal_date number number_bin number_float number_hex number_integer number_integer_long number_oct)a,
     :code_number, ""},
    {~w(name_function name_function_magic name_decorator generic_heading generic_subheading)a,
     :code_function, ""},
    {~w(name_builtin name_builtin_pseudo name_entity string_escape string_regex string_interpol string_symbol)a,
     :code_support, ""},
    {~w(string string_affix string_backtick string_char string_delimiter string_double string_heredoc string_other string_sigil string_single generic_inserted)a,
     :code_string, ""},
    {~w(name_tag generic_deleted generic_error generic_traceback error)a, :code_tag, ""}
  ]

  # Each color of a token moves to the dimmed color of its role, by the amount
  # in `--dimmed`. `--dim-color` gives a dimmed line the dimmed color of the
  # code text.
  @stylesheet [
                ".highlight {color: color-mix(in srgb, var(--code-text-dim) calc(var(--dimmed) * 100%), var(--code-text)); background-color: var(--code-background); --dim-color: var(--code-text-dim);}\n",
                ".highlight .unselectable {user-select: none;}\n",
                ".highlight .ge {font-style: italic;}\n",
                ".highlight .gs {font-weight: bold;}\n"
                | for {types, role, font} <- @roles,
                      type <- types,
                      class = Makeup.Token.Utils.css_class_for_token_type(type),
                      class != nil do
                    property = role |> Atom.to_string() |> String.replace("_", "-")

                    ".highlight .#{class} {color: color-mix(in srgb, var(--#{property}-dim) calc(var(--dimmed) * 100%), var(--#{property})); #{font}}\n"
                  end
              ]
              |> IO.iodata_to_binary()

  # Each lexer package registers its languages when its application starts.
  # A release starts each application, and `lines/2` starts them for a
  # command that does not, such as a mix task or a script.
  @lexers [
    :makeup_elixir,
    :makeup_erlang,
    :makeup_gleam,
    :makeup_eex,
    :makeup_html,
    :makeup_css,
    :makeup_ts,
    :makeup_json,
    :makeup_sql,
    :makeup_c,
    :makeup_rust,
    :makeup_diff
  ]

  @doc """
  Make one HTML fragment for each line of the text

  The language is a name that a lexer package or `Expresso.Lexers`
  registers, such as `"elixir"`, `"js"`, `"rust"` or `"toml"`.
  `languages/0` returns each name. A language with no lexer, or no language, gives plain lines.

  Each fragment starts with a `span` element and ends with one, and the last
  `span` holds the line break. Floki removes a text node of white space only,
  so the white space of a template around a fragment does not join the text
  of the line.

      iex> Expresso.Highlight.lines("a < 1", nil)
      ["<span>a &lt; 1\n</span>"]
  """
  @spec lines(String.t(), String.t() | nil) :: [String.t()]
  def lines(text, nil), do: text |> String.split("\n") |> Enum.map(&plain/1)

  def lines(text, language) do
    start_lexers()

    case Makeup.Registry.fetch_lexer_by_name(language) do
      # `Makeup.Lexer.split_into_lines/1` gives the tokens of a last line with
      # no line break in reverse order. The text therefore gets a line break
      # at its end, and the function drops the empty line after that break.
      {:ok, {lexer, options}} ->
        (text <> "\n")
        |> lexer.lex(Keyword.put(options, :group_prefix, group_prefix(text, language)))
        |> Enum.map(&flatten_value/1)
        |> Makeup.Lexer.split_into_lines()
        |> Enum.drop(-1)
        |> Enum.map(&line/1)

      :error ->
        lines(text, nil)
    end
  end

  @doc """
  Return the name of each language that a lexer registers, in alphabetical order

      iex> "elixir" in Expresso.Highlight.languages()
      true

      iex> "toml" in Expresso.Highlight.languages()
      true

      iex> "cobol" in Expresso.Highlight.languages()
      false
  """
  @spec languages() :: [String.t()]
  def languages do
    start_lexers()
    Enum.sort(Makeup.Registry.supported_language_names())
  end

  # The lexers of `Expresso.Lexers`, with their names and the extensions of
  # their files. Each one is a module of this project, and no application
  # registers it, so `start_lexers/0` registers it.
  @own_lexers [
    {Expresso.Lexers.Cabal, ["cabal"], ["cabal"]},
    {Expresso.Lexers.D2, ["d2"], ["d2"]},
    {Expresso.Lexers.Dhall, ["dhall"], ["dhall"]},
    {Expresso.Lexers.Elisp, ["elisp", "emacs-lisp"], ["el"]},
    {Expresso.Lexers.Fennel, ["fennel", "fnl"], ["fnl"]},
    {Expresso.Lexers.Haskell, ["haskell", "hs"], ["hs"]},
    {Expresso.Lexers.Kdl, ["kdl"], ["kdl"]},
    {Expresso.Lexers.Latex, ["latex", "tex"], ["tex"]},
    {Expresso.Lexers.Nix, ["nix"], ["nix"]},
    {Expresso.Lexers.Org, ["org", "orgmode"], ["org"]},
    {Expresso.Lexers.Rst, ["rst", "restructuredtext"], ["rst"]},
    {Expresso.Lexers.Toml, ["toml"], ["toml"]},
    {Expresso.Lexers.Typst, ["typst", "typ"], ["typ"]},
    {Expresso.Lexers.Yaml, ["yaml", "yml"], ["yaml", "yml"]}
  ]

  # The first name of the last lexer of the list. The function registers the
  # lexers in the order of the list, so this name is present only when each
  # lexer is.
  @last_name @own_lexers |> List.last() |> elem(1) |> hd()

  defp start_lexers do
    Enum.each(@lexers, &Application.ensure_all_started/1)

    # The registry is in the environment of the `makeup` application, so a
    # new start of that application empties it. A registration reads the
    # registry and writes it again, so two processes that register at the same
    # time can lose a name. The lock lets one process at a time register, and
    # the second check inside the lock skips the work that a process before
    # did.
    if registered?() == false do
      :global.trans({{__MODULE__, :lexers}, self()}, &register_own_lexers/0)
    end
  end

  defp register_own_lexers do
    if registered?() == false do
      for {lexer, names, extensions} <- @own_lexers,
          do: Makeup.Registry.register_lexer(lexer, names: names, extensions: extensions)
    end
  end

  defp registered?, do: Makeup.Registry.fetch_lexer_by_name(@last_name) != :error

  # A lexer gives each pair of delimiters, such as `(` and `)`, a group id in
  # `data-group-id`. The id starts with a prefix, and without the option the
  # lexer makes a random prefix. Then two renders of the same deck are not
  # equal. The hash of the text and the language gives the same prefix on each
  # computer and each ERTS version, and a different prefix for a different text.
  defp group_prefix(text, language), do: Integer.to_string(:erlang.phash2({text, language}))

  # A character that keeps a line box, and that Floki does not drop
  @zero_width_space "\u200B"

  defp flatten_value({type, meta, value}), do: {type, meta, text_of(value)}

  defp text_of(value) when is_binary(value), do: value
  defp text_of(char) when is_integer(char), do: <<char::utf8>>
  defp text_of({_type, _meta, value}), do: text_of(value)
  defp text_of(values) when is_list(values), do: Enum.map_join(values, &text_of/1)

  # A plain line is one `span`, as a line of a lexer is a sequence of them.
  defp plain(text),
    do: "<span>" <> (text |> visible() |> Kernel.<>("\n") |> escape()) <> "</span>"

  defp visible(text), do: if(String.trim(text) == "", do: @zero_width_space <> text, else: text)

  defp escape(line), do: line |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  defp line([]), do: plain("")

  defp line(tokens) do
    tokens
    |> Enum.map(&Makeup.Lexer.Postprocess.token_value_to_binary/1)
    |> merge_white_space()
    |> append_line_break()
    |> HTMLFormatter.format_inner_as_binary([])
  end

  # Put each white space token into the token before it, or into the token
  # after it at the start of the line.
  defp merge_white_space(tokens) do
    tokens
    |> Enum.reduce([], fn {tag, meta, value}, acc ->
      case {String.trim(value), acc} do
        {"", []} ->
          [{tag, meta, value}]

        {"", [{last_tag, last_meta, last} | rest]} ->
          [{last_tag, last_meta, last <> value} | rest]

        {_text, [{_tag, _meta, last} | rest]} when last != "" ->
          merge_leading(tag, meta, value, last, rest, acc)

        {_text, _acc} ->
          [{tag, meta, value} | acc]
      end
    end)
    |> Enum.reverse()
    |> visible_tokens()
  end

  defp merge_leading(tag, meta, value, last, rest, acc) do
    if String.trim(last) == "",
      do: [{tag, meta, last <> value} | rest],
      else: [{tag, meta, value} | acc]
  end

  # A line of white space only keeps its first token, and that token gets the
  # zero width space.
  defp visible_tokens([{tag, meta, value}]) do
    [{tag, meta, visible(value)}]
  end

  defp visible_tokens(tokens), do: tokens

  defp append_line_break(tokens) do
    {last_tag, last_meta, last} = List.last(tokens)
    List.replace_at(tokens, -1, {last_tag, last_meta, last <> "\n"})
  end

  @doc """
  Give the CSS of the token classes, for the class `highlight`

  Each color is a custom property of `Expresso.Palette`, such as
  `--code-keyword`, so the theme of the deck gives the colors.
  """
  @spec stylesheet() :: String.t()
  def stylesheet, do: @stylesheet
end
