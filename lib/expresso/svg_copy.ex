defmodule Expresso.SvgCopy do
  @moduledoc """
  Makes each copy of an SVG in a document independent of the other copies

  The document holds each slide three or more times: in the present view, on
  each page of the handout view and in the menu. A copy of an SVG then needs
  its own ids and its own style rules, for two causes:

    * A browser resolves a reference such as `url(#fill)` to the first element
      of the document with that `id`. That element can be in a view that the
      browser does not show, and a gradient, a clip or a mask in a hidden view
      does not paint.
    * A `<style>` element in an inline SVG applies to the whole document. Two
      files with the same class names then change the colors of each other.

  `number/2` puts the number of the copy after each `id` of the SVG, and it
  puts the same number into each `url(#id)`, each `href="#id"` and each `#id`
  selector of a `<style>`. It makes a map from each old id to its new id, and
  it changes the text in one pass, so an id such as `g1-2` does not change
  two times. Then it limits each rule of each `<style>` to the copy: the root
  `svg` element gets `data-svg-copy` with the number, and the subject of each
  selector gets `:where([data-svg-copy="N"], [data-svg-copy="N"] *)`. The
  `:where` adds no specificity, so the rules of the file keep their order
  against the rules of the theme.

  A rule in `@media`, `@supports`, `@container` or `@layer` gets the same
  change. Other at-rules, such as `@keyframes` and `@font-face`, stay as they
  are.

  `Expresso.Element.Diagram`, `Expresso.Element.Icon`,
  `Expresso.Element.TextArea` and `Expresso.Element.Item` use this module, and
  `Expresso.Copies.next/0` gives the number.
  """

  # An attribute with an id, a reference, or a `<style>` element. The `\s`
  # before a name keeps `data-id` and `data-href` out.
  @token ~r/<style\b[^>]*>.*?<\/style>|\sid=(?:"[^"]*"|'[^']*')|\s(?:xlink:)?href=(?:"#[^"]*"|'#[^']*')|url\(\s*["']?#[^)"'\s]+/s

  @id ~r/\sid=(?:"([^"]*)"|'([^']*)')/

  @doc """
  Number the copy of an SVG with the next number of `Expresso.Copies`

  An SVG with no `id` and no `<style>` stays as it is, and it takes no number.

      iex> Expresso.SvgCopy.copy(~s(<svg viewBox="0 0 1 1"><path d="M0 0h1"/></svg>))
      ~s(<svg viewBox="0 0 1 1"><path d="M0 0h1"/></svg>)
  """
  @spec copy(String.t()) :: String.t()
  def copy(svg) do
    if needs_number?(svg), do: number(svg, Expresso.Copies.next()), else: svg
  end

  @doc """
  Number each SVG of an HTML text with its own number

  A text area and an item can hold more than one inline icon, and two icons
  with the same file must have different ids.
  """
  @spec copy_each(String.t()) :: String.t()
  def copy_each(html) do
    if String.contains?(html, "<svg"),
      do: Regex.replace(~r/<svg\b.*?<\/svg>/s, html, &copy/1),
      else: html
  end

  defp needs_number?(svg), do: Regex.match?(~r/\sid=|<style\b/, svg)

  @doc """
  Put a number into each id, each reference and each style rule of an SVG

      iex> Expresso.SvgCopy.number(~s|<svg><linearGradient id="g1"/><linearGradient id="g1-2"/><rect fill="url(#g1-2)"/></svg>|, 2)
      ~s|<svg><linearGradient id="g1-2"/><linearGradient id="g1-2-2"/><rect fill="url(#g1-2-2)"/></svg>|

      iex> Expresso.SvgCopy.number(~s(<svg id="s"><style>#s .a, b::before{fill:red}</style></svg>), 3)
      ~s|<svg data-svg-copy="3" id="s-3"><style>#s-3 .a:where([data-svg-copy="3"], [data-svg-copy="3"] *), b:where([data-svg-copy="3"], [data-svg-copy="3"] *)::before{fill:red}</style></svg>|
  """
  @spec number(String.t(), pos_integer()) :: String.t()
  def number(svg, number) do
    ids =
      @id
      |> Regex.scan(svg, capture: :all_but_first)
      |> Map.new(fn captures ->
        id = Enum.find(captures, "", &(&1 != ""))
        {id, "#{id}-#{number}"}
      end)

    scope = ~s([data-svg-copy="#{number}"])
    numbered = Regex.replace(@token, svg, &token(&1, ids, scope))

    if String.contains?(svg, "<style"),
      do: String.replace(numbered, "<svg", ~s(<svg data-svg-copy="#{number}"), global: false),
      else: numbered
  end

  defp token("<style" <> _rest = style, ids, scope) do
    [open, css, close] =
      Regex.run(~r/\A(<style\b[^>]*>)(.*)(<\/style>)\z/s, style, capture: :all_but_first)

    open <> css(css, ids, scope) <> close
  end

  defp token(text, ids, _scope) do
    case Regex.run(~r/\A(\sid=)(["'])(.*)\2\z/s, text, capture: :all_but_first) do
      [name, quote, id] -> name <> quote <> Map.get(ids, id, id) <> quote
      nil -> Regex.replace(~r/#([^"']+)/, text, &reference(&1, &2, ids), global: false)
    end
  end

  defp reference(whole, id, ids) do
    case Map.fetch(ids, id) do
      {:ok, new} -> "#" <> new
      :error -> whole
    end
  end

  # The rules of a style sheet, one at a time. A group rule, such as `@media`,
  # holds more rules. A statement, such as `@import`, ends with `;`.
  defp css(css, ids, scope) do
    css |> statements("", []) |> Enum.map_join(&statement(&1, ids, scope))
  end

  defp statement({:text, text}, _ids, _scope), do: text

  defp statement({:block, prelude, body}, ids, scope) do
    trimmed = String.trim_leading(prelude)

    cond do
      Regex.match?(~r/\A@(media|supports|container|layer|document)\b/i, trimmed) ->
        prelude <> "{" <> css(body, ids, scope) <> "}"

      String.starts_with?(trimmed, "@") ->
        prelude <> "{" <> body <> "}"

      true ->
        selectors(prelude, ids, scope) <> "{" <> references(body, ids) <> "}"
    end
  end

  # Split a style sheet into statements: text, such as `@import ...;`, and
  # blocks with a prelude and a body. A comment and a string stay whole.
  defp statements("", "", acc), do: Enum.reverse(acc)
  defp statements("", text, acc), do: Enum.reverse([{:text, text} | acc])

  defp statements(";" <> rest, text, acc), do: statements(rest, "", [{:text, text <> ";"} | acc])

  defp statements("{" <> rest, prelude, acc) do
    {body, rest} = body(rest, 0, "")
    statements(rest, "", [{:block, prelude, body} | acc])
  end

  defp statements(css, text, acc) do
    {part, rest} = part(css)
    statements(rest, text <> part, acc)
  end

  # The body of a block up to its `}`, and the text after it.
  defp body("", _depth, body), do: {body, ""}
  defp body("}" <> rest, 0, body), do: {body, rest}
  defp body("}" <> rest, depth, body), do: body(rest, depth - 1, body <> "}")
  defp body("{" <> rest, depth, body), do: body(rest, depth + 1, body <> "{")

  defp body(css, depth, body) do
    {part, rest} = part(css)
    body(rest, depth, body <> part)
  end

  # The next part of a style sheet: a comment, a string or one character.
  defp part("/*" <> rest) do
    case String.split(rest, "*/", parts: 2) do
      [comment, rest] -> {"/*" <> comment <> "*/", rest}
      [comment] -> {"/*" <> comment, ""}
    end
  end

  defp part(<<quote, rest::binary>>) when quote in [?", ?'] do
    case :binary.split(rest, <<quote>>) do
      [string, rest] -> {<<quote>> <> string <> <<quote>>, rest}
      [string] -> {<<quote>> <> string, ""}
    end
  end

  defp part(<<char::utf8, rest::binary>>), do: {<<char::utf8>>, rest}

  # Number the ids of a selector list, and limit each selector to the copy.
  defp selectors(prelude, ids, scope) do
    prelude
    |> split_list(0, "", [])
    |> Enum.map_join(",", fn selector ->
      selector
      |> then(
        &Regex.replace(~r/#(-?[_a-zA-Z][\w-]*)/, &1, fn whole, id -> reference(whole, id, ids) end)
      )
      |> limit(scope)
    end)
  end

  # Put the limit on the subject of a selector, before its pseudo-element.
  defp limit(selector, scope) do
    trimmed = String.trim(selector)

    if trimmed == "" do
      selector
    else
      [leading, trailing] = String.split(selector, trimmed, parts: 2)

      {subject, pseudo} =
        case Regex.run(~r/::|:(?=(?:before|after|first-line|first-letter)\b)/i, trimmed,
               return: :index
             ) do
          [{index, _length}] -> String.split_at(trimmed, index)
          nil -> {trimmed, ""}
        end

      leading <> subject <> ":where(#{scope}, #{scope} *)" <> pseudo <> trailing
    end
  end

  # Split a selector list at each comma that is not in parentheses, in
  # brackets or in a string.
  defp split_list("", _depth, selector, acc), do: Enum.reverse([selector | acc])
  defp split_list("," <> rest, 0, selector, acc), do: split_list(rest, 0, "", [selector | acc])

  defp split_list(<<open, rest::binary>>, depth, selector, acc) when open in [?(, ?[],
    do: split_list(rest, depth + 1, selector <> <<open>>, acc)

  defp split_list(<<close, rest::binary>>, depth, selector, acc) when close in [?), ?]],
    do: split_list(rest, max(depth - 1, 0), selector <> <<close>>, acc)

  defp split_list(text, depth, selector, acc) do
    {part, rest} = part(text)
    split_list(rest, depth, selector <> part, acc)
  end

  # Number each `url(#id)` of the declarations of a rule.
  defp references(body, ids) do
    Regex.replace(~r/(url\(\s*["']?)#([^)"'\s]+)/, body, fn whole, prefix, id ->
      case Map.fetch(ids, id) do
        {:ok, new} -> prefix <> "#" <> new
        :error -> whole
      end
    end)
  end
end
