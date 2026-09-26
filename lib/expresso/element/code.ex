defmodule Expresso.Element.Code do
  @moduledoc """
  An element that shows source code

  The `code` entity takes the name of the language as its optional first
  argument, and the `text` option holds the source. `Expresso.Highlight` makes
  the markup of each line at render time, and it names the languages.

  The `reveal` option shows the lines in groups, one group at each step. It
  takes a list of line numbers and of ranges, such as `[1..3, 4..8, 10]`.
  `build/1` makes one `Expresso.Element.Lines` child for each item, with the
  specification `[from: :next]`, and the transformer then gives each group
  its steps as it does for the items of a list. A line that is in no group
  shows at each step. A hidden line keeps its space, so the block does not
  move when a group shows. A line number that is more than the number of
  lines of the text gives an error, because such a group shows nothing.

  The `dim` option gives each group the state `dim` from the first step of a
  later group. A line that is in no group does not dim. `docs/overlays.md`
  gives the rules.
  """

  use Expresso.Element

  alias Expresso.Element.Lines
  alias Expresso.Overlay

  @typedoc "The struct of a code element"
  @type t :: %__MODULE__{}

  defstruct [
    :lang,
    :text,
    :reveal,
    :at,
    :steps,
    :el,
    dim: false,
    on: [],
    elements: [],
    __spark_metadata__: nil
  ]

  @doc """
  Make a code element with text

  The options are `lang`, the name of the language, `reveal`, a list of line
  numbers and of ranges, and `dim`, a boolean. The function raises for a
  `reveal` option with a line number that the text does not have.
  """
  @spec new(String.t(), keyword()) :: t()
  def new(text, opts \\ []) do
    code = %__MODULE__{
      text: text,
      lang: Keyword.get(opts, :lang),
      reveal: Keyword.get(opts, :reveal),
      dim: Keyword.get(opts, :dim, false)
    }

    case build(code) do
      {:ok, code} -> code
      {:error, message} -> raise ArgumentError, message
    end
  end

  @doc """
  Make the groups of lines from the `reveal` option

  The DSL calls this function after it makes the struct, and `new/2` calls
  it too. It puts one `Expresso.Element.Lines` child into `elements` for each
  item of the option, in order.

  The function gives an error for a line number that is more than the number
  of lines of the text. Such a group shows nothing, and it takes one step of
  the slide, so the deck gets a step at which nothing changes.
  """
  @spec build(t()) :: {:ok, t()} | {:error, String.t()}
  def build(%__MODULE__{reveal: nil} = code), do: {:ok, code}

  def build(%__MODULE__{reveal: reveal, text: text} = code) do
    count = line_count(text)

    case reveal |> Enum.flat_map(&numbers/1) |> Enum.find(&(&1 > count)) do
      nil ->
        groups = Enum.map(reveal, &%Lines{numbers: numbers(&1), at: Overlay.from_next()})
        {:ok, %__MODULE__{code | elements: groups}}

      line ->
        {:error,
         "the reveal option has the line #{line}, and the code element has #{count(count)}"}
    end
  end

  defp count(1), do: "1 line"
  defp count(lines), do: "#{lines} lines"

  # The render function removes one line break at the end of the text, so the
  # last line is the text after the last line break. This function counts the
  # lines the same way.
  defp line_count(nil), do: 0

  defp line_count(text) do
    text |> String.replace_suffix("\n", "") |> String.split("\n") |> length()
  end

  defp numbers(line) when is_integer(line), do: [line]
  defp numbers(_first.._last//1 = range), do: Enum.to_list(range)

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
  `Expresso.Overlay.Render.attributes/1`. The key `lines` holds one pair for
  each line: the HTML of the line and the overlay attributes of its group.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(code) do
    %__MODULE__{text: text, lang: lang, elements: groups} = code

    lines =
      text
      |> String.replace_suffix("\n", "")
      |> Expresso.Highlight.lines(lang)
      |> Enum.with_index(1)
      |> Enum.map(fn {html, number} -> {html, attributes(groups, number)} end)

    %{lines: lines, overlay: Expresso.Overlay.Render.attributes(code)}
  end

  defp attributes(groups, number) do
    case Enum.find(groups, &(number in &1.numbers)) do
      nil -> []
      group -> Expresso.Overlay.Render.attributes(group)
    end
  end

  @doc """
  Make the HTML of a code element

  Each line goes into a `span` element with the class `line`, and the line
  break is inside the fragment of the line.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  # `Expresso.Highlight` escapes each line, with Makeup or with
  # `Phoenix.HTML.html_escape/1`.
  # sobelow_skip ["XSS.Raw"]
  def render(assigns) do
    temple do
      div class: "code", rest!: @overlay do
        pre do
          code class: "highlight" do
            for {html, attributes} <- @lines do
              span class: "line", rest!: attributes do
                Phoenix.HTML.raw(html)
              end
            end
          end
        end
      end
    end
  end
end
