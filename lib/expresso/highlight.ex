defmodule Expresso.Highlight do
  @moduledoc """
  The highlighting of a code element

  `lines/2` makes one HTML fragment for each line of a source text. Makeup
  lexes the text when a lexer package registers the language, and it escapes
  each token. Without a lexer for the language, or without a language, the
  function escapes each line and adds no markup.

  `stylesheet/0` gives the rules of the token classes, and the renderer writes
  them into the document.

  Each fragment holds its line break, and no text node of a fragment is only
  white space. `Expresso.Deck.render/1` writes the document with Floki, and
  Floki drops a text node that is only white space. Therefore the function
  puts each white space token into the span of the token before it, and it
  puts a zero width space into a line that has no other character.
  """

  alias Makeup.Formatters.HTML.HTMLFormatter

  # The style of the tokens. Each style of Makeup is a function of
  # `Makeup.Styles.HTML.StyleMap`, and this one gives dark text on a light
  # background, as the theme does.
  @style :tango_style

  @stylesheet Makeup.stylesheet(@style, "highlight")

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

  The language is a name that a lexer package registers, such as `"elixir"`,
  `"erlang"`, `"gleam"`, `"heex"`, `"html"`, `"css"`, `"js"`, `"ts"`,
  `"json"`, `"sql"`, `"c"`, `"rust"` or `"diff"`. A fragment holds no line
  break.
  """
  @spec lines(String.t(), String.t() | nil) :: [String.t()]
  def lines(text, nil), do: text |> String.split("\n") |> Enum.map(&plain/1)

  def lines(text, language) do
    Enum.each(@lexers, &Application.ensure_all_started/1)

    case Makeup.Registry.fetch_lexer_by_name(language) do
      # `Makeup.Lexer.split_into_lines/1` gives the tokens of a last line with
      # no line break in reverse order. The text therefore gets a line break
      # at its end, and the function drops the empty line after that break.
      {:ok, {lexer, options}} ->
        (text <> "\n")
        |> lexer.lex(options)
        |> Makeup.Lexer.split_into_lines()
        |> Enum.drop(-1)
        |> Enum.map(&line/1)

      :error ->
        lines(text, nil)
    end
  end

  # A character that keeps a line box, and that Floki does not drop
  @zero_width_space "\u200B"

  defp plain(text), do: text |> visible() |> Kernel.<>("\n") |> escape()

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
  """
  @spec stylesheet() :: String.t()
  def stylesheet, do: @stylesheet
end
