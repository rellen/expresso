defmodule Expresso.Overlay.Inline do
  @moduledoc """
  The steps of a part of a text: a tag with the attribute `at`

  The text of a text area and of an item is HTML. A tag of that text takes
  the attribute `at` with the steps of the part, and the attribute `state`
  with a state for those steps:

      The answer is <span at="2-">42</span>.
      It is <em at="3" state="alert">not</em> 41.

  | Attribute | Effect |
  | --- | --- |
  | `at="2-"` | The part shows at step 2 and at each step after it. |
  | `at="3" state="alert"` | The part shows at each step, and it has the state `alert` at step 3. |

  The value of `at` is a step specification in text. `spec/1` gives its forms.

  `extract/1` runs before the expansion of the overlays. It makes an
  `Expresso.Element.TextPart` for each such tag, in the `elements` of the text
  element, and it changes the attributes of the tag into `data-text-part`
  with the number of the part. `render/2` writes the attributes of the
  overlay contract into the tag. `docs/inline-steps.md` gives the design.
  """

  alias Expresso.Element.{Item, On, TextArea, TextPart, Tree}
  alias Expresso.Overlay
  alias Shoddy.Result

  # An opening tag with one attribute or more.
  @tag ~r/<[a-zA-Z][a-zA-Z0-9-]*\s[^<>]*>/

  # An attribute with its value in double or single quotation marks. Each
  # pattern starts with white space, so `data-at` is not the attribute `at`.
  @at ~r/\sat=(?:"([^"]*)"|'([^']*)')/
  @state ~r/\sstate=(?:"([^"]*)"|'([^']*)')/

  @placeholder ~r/ data-text-part="(\d+)"/

  @states %{"alert" => :alert, "dim" => :dim}

  @doc """
  Make the parts of each text of a list of elements

  The function changes each text area and each item whose text holds a tag
  with `at`. An element with parts from an earlier call stays as it is.
  """
  @spec extract([struct()]) :: {:ok, [struct()]} | {:error, String.t()}
  def extract(elements), do: Tree.map_ok(elements, &own/1)

  defp own(%kind{text: text, elements: elements} = element)
       when kind in [TextArea, Item] and is_binary(text) do
    with {:ok, {text, parts}} <- parse(text) do
      {:ok, %{element | text: text, elements: parts ++ (elements || [])}}
    end
  end

  defp own(element), do: {:ok, element}

  @doc """
  Find each tag with the attribute `at` in a text

  The function returns the text with `data-text-part` in each such tag, and
  the parts in the order of the text.

      iex> {:ok, {text, [part]}} = Expresso.Overlay.Inline.parse(~s(The <b at="2-">answer</b>.))
      iex> text
      ~s(The <b data-text-part="1">answer</b>.)
      iex> {part.index, part.at.pairs, part.on}
      {1, [{2, :max}], []}

      iex> {:ok, {_text, [part]}} = Expresso.Overlay.Inline.parse(~s(<em at="3" state="alert">not</em>))
      iex> {part.at, Enum.map(part.on, &{&1.at.pairs, &1.state})}
      {nil, [{[{3, 3}], :alert}]}

      iex> Expresso.Overlay.Inline.parse("A text with <em>no</em> part.")
      {:ok, {"A text with <em>no</em> part.", []}}

      iex> Expresso.Overlay.Inline.parse(~s(<em state="alert">not</em>))
      {:error, "the tag <em state=\\"alert\\"> of a text has the attribute state and no attribute at. Give the steps of the state in at, such as at=\\"2\\""}
  """
  @spec parse(String.t()) :: {:ok, {String.t(), [TextPart.t()]}} | {:error, String.t()}
  def parse(text) do
    @tag
    |> Regex.split(text, include_captures: true)
    |> Enum.reduce_while({:ok, {[], []}}, fn piece, {:ok, {pieces, parts}} ->
      case tag(piece, length(parts) + 1) do
        :text -> {:cont, {:ok, {[piece | pieces], parts}}}
        {:ok, {tag, part}} -> {:cont, {:ok, {[tag | pieces], [part | parts]}}}
        {:error, message} -> {:halt, {:error, message}}
      end
    end)
    |> Result.map_ok(fn {pieces, parts} ->
      {pieces |> Enum.reverse() |> IO.iodata_to_binary(), Enum.reverse(parts)}
    end)
  end

  # A piece of the split text: a tag with `at`, or any other text.
  defp tag(piece, index) do
    at = value(@at, piece)
    state = value(@state, piece)

    cond do
      not Regex.match?(~r/\A#{@tag.source}\z/, piece) ->
        :text

      at == nil and state == nil ->
        :text

      at == nil ->
        {:error,
         "the tag #{piece} of a text has the attribute state and no attribute at. " <>
           "Give the steps of the state in at, such as at=\"2\""}

      true ->
        part(piece, index, at, state)
    end
  end

  # The tag with the number of its part, and the part. A part with a state
  # holds its steps in an `on` entity.
  defp part(piece, index, at, state) do
    with {:ok, spec} <- spec(at),
         {:ok, state} <- state(state, piece) do
      part =
        if state,
          do: %TextPart{index: index, on: [%On{at: spec, state: state}]},
          else: %TextPart{index: index, at: spec}

      {:ok, {mark(piece, index), part}}
    end
  end

  defp value(pattern, piece) do
    case Regex.run(pattern, piece, capture: :all_but_first) do
      nil -> nil
      values -> Enum.find(values, &(&1 != "")) || ""
    end
  end

  defp state(nil, _piece), do: {:ok, nil}

  defp state(name, piece) do
    case Map.fetch(@states, name) do
      {:ok, state} ->
        {:ok, state}

      :error ->
        {:error,
         "the state #{inspect(name)} of the tag #{piece} of a text is not a state of a part. " <>
           "The states are \"alert\" and \"dim\""}
    end
  end

  # The tag with the number of its part in place of the two attributes.
  defp mark(piece, index) do
    piece
    |> String.replace(@state, "")
    |> String.replace(@at, " data-text-part=\"#{index}\"")
  end

  @doc """
  Make a step specification from its text

  | Text | Steps |
  | --- | --- |
  | `2` | Step 2 only. |
  | `2-4` | Step 2 to step 4. |
  | `2-` | Step 2 and each step after it. |
  | `+` | The current value of the counter of the slide. |
  | `+-` | The current value of the counter, and each step after it. |
  | `2,5-` | Step 2, and step 5 and each step after it. |

  The forms are the forms of the `at` option of an element, in text.

      iex> {:ok, spec} = Expresso.Overlay.Inline.spec("2, 5-7, 9-")
      iex> spec.pairs
      [{2, 2}, {5, 7}, {9, :max}]

      iex> {:ok, spec} = Expresso.Overlay.Inline.spec("+-")
      iex> spec.pairs
      [{:next, :max}]

      iex> Expresso.Overlay.Inline.spec("two")
      {:error, "\\"two\\" is not the steps of a part of a text. Give a step, such as \\"2\\", \\"2-4\\", \\"2-\\", \\"+\\" or \\"+-\\", or a list of them with commas"}
  """
  @spec spec(String.t()) :: {:ok, Overlay.t()} | {:error, String.t()}
  def spec(text) do
    items = text |> String.split(",") |> Enum.map(&item(String.trim(&1)))

    if items == [] or :error in items do
      {:error,
       "#{inspect(text)} is not the steps of a part of a text. Give a step, such as " <>
         "\"2\", \"2-4\", \"2-\", \"+\" or \"+-\", or a list of them with commas"}
    else
      Overlay.new(items)
    end
  end

  defp item("+"), do: :next
  defp item("+-"), do: {:from, :next}

  defp item(text) do
    case Regex.run(~r/\A([1-9]\d*)(?:(-)([1-9]\d*)?)?\z/, text, capture: :all_but_first) do
      [first] -> String.to_integer(first)
      [first, "-"] -> {:from, String.to_integer(first)}
      [first, "-", last] -> String.to_integer(first)..String.to_integer(last)//1
      nil -> :error
    end
  end

  @doc """
  Write the attributes of the overlay contract into each tag of a part

  `elements` holds the parts of the text, from `extract/1`, after the
  expansion of the overlays. A tag keeps `data-text-part`, which the style
  sheet reads.

      iex> part = %Expresso.Element.TextPart{index: 1, steps: [2, 3]}
      iex> Expresso.Overlay.Inline.render(~s(The <b data-text-part="1">answer</b>.), [part])
      ~s(The <b data-text-part="1" data-on="2 3">answer</b>.)
  """
  @spec render(String.t(), [struct()] | nil) :: String.t()
  def render(text, elements) do
    parts = for %TextPart{index: index} = part <- elements || [], into: %{}, do: {index, part}

    if parts == %{},
      do: text,
      else: Regex.replace(@placeholder, text, &(&1 <> attributes(parts[String.to_integer(&2)])))
  end

  defp attributes(nil), do: ""

  defp attributes(part) do
    part
    |> Overlay.Render.attributes()
    |> Enum.map_join(fn {name, value} ->
      ~s( #{name}="#{value |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()}")
    end)
  end

  @doc """
  Return the elements of a list that are not parts of a text

  An item holds its parts and its nested lists in `elements`, and it renders
  only the lists.
  """
  @spec without_parts([struct()] | nil) :: [struct()]
  def without_parts(elements), do: Enum.reject(elements || [], &is_struct(&1, TextPart))
end
