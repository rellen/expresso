defmodule Expresso.Overlay.Typewriter do
  @moduledoc """
  The characters of an element with `effect :type`

  An element with steps and with `effect :type` shows its text one character
  at a time. `wrap/1` takes the HTML of the body of a slide, and it puts each
  character of such an element into its own `span`:

      <p data-on="2" data-effect="type" style="--type-n: 2">
        <span class="type-text">Hi</span>
        <span class="type-chars" aria-hidden="true">
          <span class="type-char" style="--i:0">H</span>
          <span class="type-char" style="--i:1">i</span>
        </span>
      </p>

  | Part | Purpose |
  | --- | --- |
  | `--type-n` | The number of characters of the element. The theme makes the time of the effect from it. |
  | `type-text` | The whole text. It has no size, and only a screen reader reads it. |
  | `type-chars` | The characters that the eye sees. A screen reader does not read them. |
  | `--i` | The position of the character in the element, from 0. |

  The rules of the theme for `[data-effect="type"]` move the registered
  property `--type` from 0 to 1, and each character shows when the property
  passes its position. `docs/typewriter-effect.md` gives the design.

  The function obeys these rules:

  - White space takes no position, so it takes no time. It is in the `span`
    of the character before it.
  - A character reference such as `&amp;` is one character.
  - An element inside with its own steps is not part of the text. It shows
    at its own steps, with its own effect.
  - Elements with the same parent and the same steps, such as the lines of
    one group of a code element, make one sequence. The positions of the
    second element start after the last position of the first one.
  - A picture, a formula, a script and an element with `aria-hidden` keep
    their content. They show with the element, at once.
  - An element with no character loses `data-effect`, so it fades.
  """

  # A comment, an end tag or a start tag. The value of an attribute can hold
  # `>`, so the pattern reads each value in quotation marks as a whole.
  @token ~r/<!--.*?-->|<\/?[a-zA-Z][^<>"']*(?:(?:"[^"]*"|'[^']*')[^<>"']*)*>/s

  @name ~r/\A<\/?([a-zA-Z][a-zA-Z0-9:-]*)/

  # A character reference, a run of white space, or one grapheme.
  @unit ~r/&(?:#\d+|#[xX][0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);|\s+|\X/u

  @on ~r/\sdata-on="([^"]*)"/
  @effect ~s( data-effect="type")

  # An element with no end tag.
  @void ~w(area base br col embed hr img input link meta source track wbr)

  # An element whose content is not text of the slide.
  @graphic ~w(svg math script style template textarea)

  @doc """
  Tell if the HTML holds an element with `effect :type`

      iex> Expresso.Overlay.Typewriter.typed?(~s(<p data-on="2" data-effect="type">Hi</p>))
      true

      iex> Expresso.Overlay.Typewriter.typed?(~s(<p data-on="2">Hi</p>))
      false
  """
  @spec typed?(String.t()) :: boolean()
  def typed?(html), do: String.contains?(html, @effect)

  @doc """
  Put each character of each element with `effect :type` into its own `span`

  The function returns HTML with no such element as it is.

      iex> Expresso.Overlay.Typewriter.wrap(~s(<p data-on="2" data-effect="type">Hi</p>))
      ~s(<p data-on="2" data-effect="type" style="--type-n: 2">) <>
        ~s(<span class="type-text">Hi</span><span class="type-chars" aria-hidden="true">) <>
        ~s(<span class="type-char" style="--i:0">H</span>) <>
        ~s(<span class="type-char" style="--i:1">i</span></span></p>)

      iex> Expresso.Overlay.Typewriter.wrap(~s(<p data-on="2">Hi</p>))
      ~s(<p data-on="2">Hi</p>)

      iex> Expresso.Overlay.Typewriter.wrap(~s(<div data-on="2" data-effect="type"><img src="a.png"></div>))
      ~s(<div data-on="2"><img src="a.png"></div>)
  """
  @spec wrap(String.t()) :: String.t()
  def wrap(html) do
    if typed?(html) do
      start = %{out: [], stack: [{nil, nil, 0}], skip: nil, chains: %{}, counts: %{}, frames: 0}

      state =
        @token
        |> Regex.split(html, include_captures: true)
        |> Enum.reduce(start, &piece/2)

      state.out
      |> Enum.reverse()
      |> Enum.map(&root(&1, state.counts))
      |> IO.iodata_to_binary()
    else
      html
    end
  end

  # The start tag of an element with the effect gets the number of the
  # characters of its sequence. An element with no character loses the effect.
  defp root({:root, chain, tag}, counts) do
    case Map.get(counts, chain, 0) do
      0 -> String.replace(tag, @effect, "", global: false)
      count -> count(tag, count)
    end
  end

  defp root(piece, _counts), do: piece

  defp count(tag, count) do
    if Regex.match?(~r/\sstyle="/, tag) do
      Regex.replace(~r/(\sstyle=")/, tag, "\\1--type-n: #{count}; ", global: false)
    else
      String.replace_suffix(tag, ">", ~s( style="--type-n: #{count}">))
    end
  end

  # One piece of the HTML: a tag, a comment or a text.
  defp piece("", state), do: state

  defp piece(piece, %{skip: {name, depth}} = state) do
    depth =
      case kind(piece) do
        {:open, ^name, false} -> depth + 1
        {:close, ^name} -> depth - 1
        _other -> depth
      end

    %{state | out: [piece | state.out], skip: if(depth > 0, do: {name, depth})}
  end

  defp piece(piece, state) do
    case kind(piece) do
      {:open, _name, true} -> emit(state, piece)
      {:open, name, false} -> open(state, name, piece)
      {:close, name} -> state |> close(name) |> emit(piece)
      :comment -> emit(state, piece)
      :text -> text(state, piece)
    end
  end

  defp emit(state, piece), do: %{state | out: [piece | state.out]}

  # The kind of a piece. The third value of `:open` tells that the element
  # has no content: a void element, or a tag that ends with `/>`.
  defp kind("<!--" <> _rest), do: :comment
  defp kind("</" <> _rest = tag), do: {:close, name(tag)}

  defp kind("<" <> _rest = tag) do
    case name(tag) do
      nil -> :text
      name -> {:open, name, name in @void or String.ends_with?(tag, "/>")}
    end
  end

  defp kind(_text), do: :text

  defp name(tag) do
    case Regex.run(@name, tag) do
      [_all, name] -> String.downcase(name)
      nil -> nil
    end
  end

  # A start tag. An element with steps starts its own text: with the effect,
  # it starts or continues a sequence, and with a different effect it has no
  # sequence. Each other element continues the sequence of its parent.
  defp open(state, name, tag) do
    [{_parent, chain, parent} | _rest] = state.stack
    id = state.frames + 1
    on = Regex.run(@on, tag, capture: :all_but_first)

    cond do
      name in @graphic or String.contains?(tag, ~s(aria-hidden="true")) ->
        %{state | out: [tag | state.out], skip: {name, 1}}

      on != nil and String.contains?(tag, @effect) ->
        key = {parent, on}
        chain = Map.get(state.chains, key, id)

        %{
          state
          | out: [{:root, chain, tag} | state.out],
            stack: [{name, chain, id} | state.stack],
            chains: Map.put(state.chains, key, chain),
            frames: id
        }

      on != nil ->
        %{state | out: [tag | state.out], stack: [{name, nil, id} | state.stack], frames: id}

      true ->
        %{state | out: [tag | state.out], stack: [{name, chain, id} | state.stack], frames: id}
    end
  end

  # An end tag closes the nearest open element with its name, and each
  # element inside that element. An end tag with no open element changes
  # nothing, so a text with a wrong tag keeps the base of the stack.
  defp close(state, name) do
    case Enum.split_while(state.stack, fn {open, _chain, _id} -> open != name end) do
      {_inside, [_element | rest]} when name != nil -> %{state | stack: rest}
      _no_element -> state
    end
  end

  # A text. A text of white space only keeps its form.
  defp text(%{stack: [{_name, nil, _id} | _rest]} = state, text), do: emit(state, text)

  defp text(%{stack: [{_name, chain, _id} | _rest]} = state, text) do
    if String.trim(text) == "" do
      emit(state, text)
    else
      first = Map.get(state.counts, chain, 0)
      {chars, _lead, last} = @unit |> Regex.scan(text) |> Enum.reduce({[], "", first}, &unit/2)

      wrapped = [
        ~s(<span class="type-text">),
        text,
        ~s(</span><span class="type-chars" aria-hidden="true">),
        chars |> Enum.reverse() |> Enum.map(&char/1),
        "</span>"
      ]

      %{state | out: [wrapped | state.out], counts: Map.put(state.counts, chain, last)}
    end
  end

  # One unit of a text. White space goes into the `span` of the character
  # before it, or of the character after it at the start of the text.
  # `Expresso.Deck.render/1` writes the document with Floki, which drops a
  # text of white space only between two tags.
  defp unit([unit], {chars, lead, position}) do
    cond do
      String.trim(unit) != "" -> {[{position, [lead, unit]} | chars], "", position + 1}
      chars == [] -> {chars, lead <> unit, position}
      true -> {after_last(chars, unit), lead, position}
    end
  end

  defp after_last([{position, content} | rest], space), do: [{position, [content, space]} | rest]

  defp char({position, content}),
    do: [~s(<span class="type-char" style="--i:#{position}">), content, "</span>"]
end
