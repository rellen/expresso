defmodule Expresso.Element.Code do
  @moduledoc """
  An element that shows source code

  The `code` entity takes the name of the language as its optional first
  argument. The `text` option holds the source, or the `src` option gives the
  path of a file that holds it. `Expresso.Highlight` makes the markup of each
  line at render time, and it names the languages.

  The `src` option takes a path that is relative to the working directory of
  the command, as for an image. The `lines` option takes a range of the lines
  of the file, such as `3086..3095`, and the element then shows only those
  lines. `build/1` reads the file through `Expresso.DeckFile`, so the watch
  mode renders the deck again after a change to the file. The element takes
  `text` or `src`, and not both.

  Each line has a number. The first line of the text is line 1. With `src`,
  the number of a line is its number in the file, so the first line of
  `lines: 3086..3095` is line 3086. The `line_numbers` option shows the
  number in front of each line.

  The `reveal` option shows the lines in groups, one group at each step. It
  takes a list of line numbers and of ranges, such as `[1..3, 4..8, 10]`.
  `build/1` makes one `Expresso.Element.Lines` child for each item, with the
  specification `[from: :next]`, and the transformer then gives each group
  its steps as it does for the items of a list. A line that is in no group
  shows at each step. A hidden line keeps its space, so the block does not
  move when a group shows. A line number that the element does not show gives
  an error, because such a group shows nothing.

  The `dim` option gives each group the state `dim` from the first step of a
  later group. A line that is in no group does not dim. `docs/overlays.md`
  gives the rules.

  The `highlight` option takes groups of lines in the same form as `reveal`.
  Each line shows at each step, and each group is in focus at its own step:
  the lines of the group get the state `highlight`, and each other line gets
  the state `dim`. `build/1` gives each group an `on` entity with `:next`, so
  the transformer gives the groups one step each from the counter of the
  slide. Each line in no group goes into one more group with no `on` entity.
  `spotlight/1` then gives each group the state `dim` at the steps of the
  other groups, before the render.
  """

  use Expresso.Element

  alias Expresso.Element.{Lines, On}
  alias Expresso.Overlay

  @typedoc "The struct of a code element"
  @type t :: %__MODULE__{}

  defstruct [
    :class,
    :lang,
    :text,
    :src,
    :lines,
    :reveal,
    :highlight,
    :at,
    :steps,
    :el,
    :effect,
    :speed,
    :easing,
    dim: false,
    line_numbers: false,
    first: 1,
    on: [],
    elements: [],
    __spark_metadata__: nil
  ]

  @doc """
  Read the source, and make the groups of lines from the `reveal` option

  The transform of the `code` entity calls this function after it makes the
  struct, in the DSL and in `Expresso.Builder`. With `src`, the function reads
  the file, puts the lines of the `lines` option into `text`, and puts the
  number of the first line into `first`. Then it puts one
  `Expresso.Element.Lines` child into `elements` for each item of the
  `reveal` option, in order.

  The function gives an error for:

    * an element with both `text` and `src`, or with neither,
    * a `lines` option without `src`,
    * a file that it cannot read, or a range that goes past the end of the
      file,
    * a line number of `reveal` that the element does not show. Such a group
      shows nothing, and it takes one step of the slide, so the deck gets a
      step at which nothing changes,
    * an element with both `reveal` and `highlight`, a `highlight` with `dim`,
      a line number of `highlight` that the element does not show, and a line
      that is in two groups of `highlight`.
  """
  @spec build(t()) :: {:ok, t()} | {:error, String.t()}
  def build(%__MODULE__{} = code) do
    with {:ok, code} <- source(code), do: groups(code)
  end

  defp source(%__MODULE__{text: text, src: src}) when is_binary(text) and is_binary(src),
    do: {:error, "a code element takes the text option or the src option, and not both"}

  defp source(%__MODULE__{text: nil, src: nil}),
    do: {:error, "a code element needs the text option or the src option"}

  defp source(%__MODULE__{src: nil, lines: lines}) when lines != nil,
    do: {:error, "the lines option of a code element needs the src option"}

  defp source(%__MODULE__{src: nil} = code), do: {:ok, code}

  defp source(%__MODULE__{src: src, lines: lines} = code) do
    case Expresso.DeckFile.read(src) do
      {:ok, bytes} -> excerpt(code, split(bytes), lines)
      {:error, reason} -> {:error, "cannot read the code file \"#{src}\": #{reason}"}
    end
  end

  defp excerpt(%__MODULE__{} = code, all, nil),
    do: {:ok, %__MODULE__{code | text: Enum.join(all, "\n")}}

  defp excerpt(%__MODULE__{} = code, all, first..last//1) do
    if last <= length(all) do
      text = all |> Enum.slice((first - 1)..(last - 1)//1) |> Enum.join("\n")
      {:ok, %__MODULE__{code | text: text, first: first}}
    else
      {:error,
       "the lines option ends at the line #{last}, and the file \"#{code.src}\" has #{count(length(all))}"}
    end
  end

  defp groups(%__MODULE__{reveal: reveal, highlight: highlight})
       when reveal != nil and highlight != nil,
       do:
         {:error, "a code element takes the reveal option or the highlight option, and not both"}

  defp groups(%__MODULE__{highlight: highlight, dim: true}) when highlight != nil,
    do:
      {:error,
       "the highlight option dims the other lines itself, so the code element takes no dim option"}

  defp groups(%__MODULE__{reveal: nil, highlight: nil} = code), do: {:ok, code}

  defp groups(%__MODULE__{reveal: reveal, highlight: nil} = code) do
    with :ok <- shows(code, :reveal, reveal) do
      groups = Enum.map(reveal, &%Lines{numbers: numbers(&1), at: Overlay.from_next()})
      {:ok, %__MODULE__{code | elements: groups}}
    end
  end

  defp groups(%__MODULE__{highlight: highlight, text: text, first: first} = code) do
    with :ok <- shows(code, :highlight, highlight),
         :ok <- apart(highlight) do
      {:ok, next} = Overlay.new(:next)

      groups =
        Enum.map(highlight, fn item ->
          %Lines{numbers: numbers(item), on: [%On{at: next, state: :highlight}]}
        end)

      grouped = Enum.flat_map(highlight, &numbers/1)
      rest = Enum.to_list(first..(first + line_count(text) - 1)//1) -- grouped
      rest = if rest == [], do: [], else: [%Lines{numbers: rest}]

      {:ok, %__MODULE__{code | elements: groups ++ rest}}
    end
  end

  defp shows(%__MODULE__{text: text, first: first} = code, option, items) do
    last = first + line_count(text) - 1

    case items |> Enum.flat_map(&numbers/1) |> Enum.find(&(&1 < first or &1 > last)) do
      nil ->
        :ok

      line ->
        {:error, "the #{option} option has the line #{line}, and " <> shown(code, first, last)}
    end
  end

  # A line can have the attributes of one group only.
  defp apart(highlight) do
    numbers = Enum.flat_map(highlight, &numbers/1)

    case numbers -- Enum.uniq(numbers) do
      [] -> :ok
      [line | _] -> {:error, "the line #{line} is in two groups of the highlight option"}
    end
  end

  defp shown(%__MODULE__{src: nil}, 1, last), do: "the code element has #{count(last)}"
  defp shown(_code, first, last), do: "the code element shows the lines #{first} to #{last}"

  defp count(1), do: "1 line"
  defp count(lines), do: "#{lines} lines"

  # The render function removes one line break at the end of the text, so the
  # last line is the text after the last line break. These functions count the
  # lines the same way.
  defp line_count(nil), do: 0
  defp line_count(text), do: text |> split() |> length()

  defp split(text), do: text |> String.replace_suffix("\n", "") |> String.split("\n")

  @doc """
  Make sure that a `lines` option is a range of line numbers

  This function is the custom type of the option. The range starts at 1 or
  more, and it has a step of 1.
  """
  @spec lines(term()) :: {:ok, Range.t()} | {:error, String.t()}
  def lines(first..last//1 = range) when is_integer(first) and first >= 1 and first <= last,
    do: {:ok, range}

  def lines(_term),
    do: {:error, "a lines option takes a range of line numbers, such as 10..24"}

  defp numbers(line) when is_integer(line), do: [line]
  defp numbers(_first.._last//1 = range), do: Enum.to_list(range)

  @doc """
  Dim the lines of each code element that are not in focus

  A code element with the `highlight` option has one group of lines for each
  item of the option, and one more group for the lines in no item. The
  transformer gives each group of an item its step, in the `on` entity with
  the state `highlight`. This function gives each other group of the element
  an `on` entity with the state `dim` at that step. The other lines then dim,
  and the group in focus shows in full.

  `Expresso.Renderer` calls this function before `Expresso.Overlay.Render.identify/1`,
  because a group needs an identity for its `on` entities.
  """
  @spec spotlight(Expresso.Deck.t()) :: Expresso.Deck.t()
  def spotlight(%Expresso.Deck{slides: slides} = deck) do
    %Expresso.Deck{deck | slides: Enum.map(slides, &%{&1 | elements: walk(&1.elements || [])})}
  end

  defp walk(elements) do
    Enum.map(elements, fn
      %__MODULE__{highlight: highlight} = code when highlight != nil ->
        %__MODULE__{code | elements: dim_others(code.elements)}

      %{elements: children} = element when is_list(children) ->
        %{element | elements: walk(children)}

      element ->
        element
    end)
  end

  defp dim_others(groups) do
    focus = Enum.map(groups, &focus_steps/1)

    groups
    |> Enum.with_index()
    |> Enum.map(fn {%Lines{} = group, index} ->
      others = focus |> List.delete_at(index) |> List.flatten() |> Enum.sort()
      dims = if others == [], do: [], else: [%On{state: :dim, steps: others}]
      %Lines{group | on: group.on ++ dims}
    end)
  end

  defp focus_steps(%Lines{on: on}),
    do: for(%On{state: :highlight, steps: steps} <- on, step <- steps || [], do: step)

  @doc """
  Make sure that a `reveal` option is a list of line numbers and of ranges

  This function is the custom type of the option. Each item is a positive
  integer or a range with a step of 1.
  """
  @spec reveal(term()) :: {:ok, [pos_integer() | Range.t()]} | {:error, String.t()}
  def reveal([_ | _] = items) do
    if Enum.all?(items, &line_item?/1) do
      {:ok, items}
    else
      {:error, "a reveal option takes line numbers and ranges, such as [1..3, 4..8, 10]"}
    end
  end

  def reveal(_term) do
    {:error, "a reveal option takes line numbers and ranges, such as [1..3, 4..8, 10]"}
  end

  defp line_item?(line) when is_integer(line), do: line >= 1
  defp line_item?(first..last//1), do: first >= 1 and first <= last
  defp line_item?(_item), do: false

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`. The key `lines` holds one triple
  for each line: the number of the line, the HTML of the line and the overlay
  attributes of its group. The key `numbers` holds the width of the widest
  number in characters, or `nil` for an element without the `line_numbers`
  option.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(code) do
    %__MODULE__{text: text, lang: lang, elements: groups, first: first} = code

    lines =
      text
      |> String.replace_suffix("\n", "")
      |> Expresso.Highlight.lines(lang)
      |> Enum.with_index(first)
      |> Enum.map(fn {html, number} -> {number, html, attributes(groups, number)} end)

    %{
      lines: lines,
      numbers: width(code.line_numbers, lines),
      overlay: Expresso.Overlay.Render.attributes(code)
    }
  end

  defp width(false, _lines), do: nil
  defp width(true, lines), do: lines |> List.last() |> elem(0) |> Integer.digits() |> length()

  defp attributes(groups, number) do
    case Enum.find(groups, &(number in &1.numbers)) do
      nil -> []
      group -> Expresso.Overlay.Render.attributes(group)
    end
  end

  @doc """
  Make the HTML of a code element

  Each line goes into a `span` element with the class `line`, and the line
  break is inside the fragment of the line. With the `line_numbers` option,
  the number of the line goes into a `span` element with the class
  `line-number` at the start of the line. A screen reader does not read the
  number, and a copy of the text does not take it. The `code` element sets
  `--line-number-width`, so each number takes the width of the widest one.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  # `Expresso.Highlight` escapes each line, with Makeup or with
  # `Phoenix.HTML.html_escape/1`.
  # sobelow_skip ["XSS.Raw"]
  def render(assigns) do
    temple do
      div class: Expresso.Element.classes("code", assigns[:class]), rest!: @overlay do
        pre do
          code class: "highlight", style: @numbers && "--line-number-width: #{@numbers}ch" do
            for {number, html, attributes} <- @lines do
              span class: "line", rest!: attributes do
                if @numbers do
                  span class: "line-number", aria_hidden: "true" do
                    number
                  end
                end

                Phoenix.HTML.raw(html)
              end
            end
          end
        end
      end
    end
  end
end
