defmodule Expresso.Element.Chart.Waterfall do
  @moduledoc """
  A waterfall chart: a start value, the changes to it, and the totals between
  them

  `Expresso.Element.Chart` sends each function of a chart of the family
  `:waterfall` to this module: the check, the assigns, the layout, the marks
  and the table. `docs/waterfall-charts.md` gives the design.

  The chart has one series. Its first value is the start, and it draws as a
  total. Each other number is a change, and it draws as a floating column
  from the running total before it. The atom `:total` marks a total column,
  and `{:total, value}` also gives the value that the author expects.
  `columns/1` calculates the base, the end and the running total of each
  column.

  With `reveal true`, the check puts the columns into groups:
  `members/2` gives the group of each column. Group 0 holds the start and the
  totals of `totals :grow`, and the chart draws it outside the groups, so it
  shows with the chart and does not dim. Each change is a group, and a total
  of `totals :complete` goes into the group of the column before it. Each
  group is a copy of the series with the indexes of its columns in `columns`,
  and it is a child of the chart, so it takes its step from `reveal`.

  A state is one set of values of the channels: one state for each group
  that shows, from group 0. A total of `totals :grow` holds in each state
  the running total of the changes that show, so it grows or shrinks at the
  step of each change, and its value counts. A chart with frames has one
  more state for each later frame, after the states of `reveal` in the first
  frame. `rules/1` writes the channels of each state at its steps.

  Each column has its place in the channels of
  `Expresso.Element.Chart.Motion`: `--u<i>` and `--v<i>` for the corner at the
  top left of column `i`, and `--w<i>` and `--h<i>` for its size. The style
  attribute of the column reads the channels with the value of the first
  state as the fallback, so a chart of one state needs no rule.
  """

  import Temple
  use Temple.Component

  alias Expresso.Element.Chart
  alias Expresso.Element.Chart.{Csv, Motion, Plot, Scale}
  alias Expresso.Element.{Frame, Series}

  # The box of the chart in the units of the SVG.
  @width 800
  @height 450

  # The part of the band of a category that its column takes.
  @column 0.7

  # The least height of a vertical column that holds the text of its change.
  # A horizontal bar holds the text when it is as wide as the text.
  @inside 22

  @typedoc """
  A value of the series of a waterfall chart: a change, or the mark of a total
  """
  @type value :: number() | :total | {:total, number()}

  @typedoc """
  One column: its type, its change, the value at its base and at its end, and
  the running total after it
  """
  @type column :: %{
          type: :total | :up | :down,
          change: number() | nil,
          from: number(),
          to: number(),
          total: number()
        }

  @doc """
  Check the options and the series of a waterfall chart

  `Expresso.Element.Chart` calls this function after the check of the
  categories. The chart has one series with one value for each category. The
  first value is a number, and each other value is a number, `:total` or
  `{:total, value}`. The sum before `{:total, value}` agrees with the value,
  and each column is inside `value_range`.
  """
  @spec check(Chart.t()) :: {:ok, Chart.t()} | {:error, String.t()}
  def check(%Chart{} = chart) do
    chart = whole(chart)

    with :ok <- options(chart),
         {:ok, series} <- one_series(chart),
         :ok <- values(series, chart.categories),
         :ok <- totals(series, chart.categories),
         :ok <- range(chart, columns(series.values)),
         :ok <- same_totals(chart, series),
         :ok <- revealed(chart, series) do
      {:ok, %Chart{chart | elements: groups(chart, series)}}
    end
  end

  # A chart that the check put into groups holds the whole series in each
  # group, so a second check starts from the first group.
  defp whole(%Chart{elements: [%Series{columns: [_ | _]} = group | _]} = chart),
    do: %Chart{chart | elements: [%Series{group | columns: nil}]}

  defp whole(chart), do: chart

  # Each frame of a chart with frames has its totals at the places of the
  # totals of the first frame, so each column keeps its type.
  defp same_totals(%Chart{timeline: [%Frame{elements: [first | _]} | _]}, %Series{} = series) do
    if marks(first.values) == marks(series.values),
      do: :ok,
      else:
        {:error,
         "each frame of a waterfall chart has its totals at the places of the totals of " <>
           "the first frame, so the series \"#{series.name}\" of a later frame marks the " <>
           "same categories as totals"}
  end

  defp same_totals(_chart, _series), do: :ok

  defp marks(values) when is_list(values), do: Enum.map(values, &is_number/1)
  defp marks(_values), do: []

  # With `reveal`, each group takes its steps from the chart.
  defp revealed(%Chart{reveal: true}, %Series{} = series)
       when series.at != nil or series.on != [],
       do:
         {:error,
          "the reveal option gives each change of a waterfall chart its own step, so the " <>
            "series takes no at option and no on entity"}

  defp revealed(_chart, _series), do: :ok

  # The groups of `reveal`: one copy of the series for each group after group
  # 0, with the indexes of its columns. A chart without `reveal`, or without
  # a change, keeps its series.
  defp groups(%Chart{reveal: true, totals: totals}, %Series{values: values} = series) do
    members = members(values, totals)

    case Enum.max(members) do
      0 ->
        [series]

      count ->
        indexed = Enum.with_index(members)
        for group <- 1..count, do: %Series{series | columns: for({^group, i} <- indexed, do: i)}
    end
  end

  defp groups(_chart, series), do: [series]

  @doc """
  Return the group of each column of a waterfall chart with `reveal`

  The start is in group 0, and each change starts a new group. A total is in
  group 0 with `totals :grow`, and in the group of the column before it with
  `totals :complete`.

      iex> Expresso.Element.Chart.Waterfall.members([50, 40, 30, :total, 10, :total], :grow)
      [0, 1, 2, 0, 3, 0]
      iex> Expresso.Element.Chart.Waterfall.members([50, 40, 30, :total, 10, :total], :complete)
      [0, 1, 2, 2, 3, 3]
  """
  @spec members([value()], :grow | :complete) :: [non_neg_integer()]
  def members([_start | rest], totals) do
    {groups, _state} =
      Enum.map_reduce(rest, {0, 0}, fn
        value, {count, _last} when is_number(value) ->
          {count + 1, {count + 1, count + 1}}

        _total, {count, last} ->
          {if(totals == :complete, do: last, else: 0), {count, last}}
      end)

    [0 | groups]
  end

  defp options(%Chart{totals: :complete, reveal: false}),
    do:
      {:error,
       "the totals option tells how a total shows at the steps of reveal, so totals " <>
         ":complete needs reveal true"}

  defp options(%Chart{value_range: {low, high}}) when low >= high,
    do:
      {:error,
       "the value_range option gives the low end and then the high end of the axis, " <>
         "such as {0, 200}"}

  defp options(_chart), do: :ok

  defp one_series(%Chart{elements: [%Series{} = series]}), do: {:ok, series}

  defp one_series(%Chart{elements: elements}),
    do:
      {:error,
       "a waterfall chart has one series, and this chart has #{length(elements)}. " <>
         "Put each change into one series, in the order of the categories."}

  defp values(%Series{name: name, values: values}, categories) do
    count = length(categories)

    cond do
      not is_list(values) or length(values) != count ->
        {:error, "the series \"#{name}\" needs #{count} values, one for each category"}

      not is_number(hd(values)) ->
        {:error,
         "the first value of the series \"#{name}\" is the start of the waterfall, " <>
           "so it is a number"}

      bad = Enum.find(values, &(not value?(&1))) ->
        {:error,
         "the series \"#{name}\" has #{inspect(bad)}, and a value of a waterfall chart is " <>
           "a number, :total or {:total, value}"}

      true ->
        :ok
    end
  end

  defp value?(value) when is_number(value), do: true
  defp value?(:total), do: true
  defp value?({:total, value}) when is_number(value), do: true
  defp value?(_value), do: false

  # Each total with a value agrees with the sum before it, at the most
  # decimals of the numbers of the series.
  defp totals(%Series{name: name, values: values}, categories) do
    decimals = values |> Enum.map(&number/1) |> Plot.decimals()
    sums = values |> columns() |> Enum.map(& &1.total)

    Enum.zip([values, sums, categories])
    |> Enum.find_value(:ok, fn
      {{:total, expected}, sum, category} ->
        if round_to(sum, decimals) == round_to(expected, decimals),
          do: nil,
          else:
            {:error,
             "the total \"#{category}\" of the series \"#{name}\" is #{Plot.label(expected)}, " <>
               "and the sum of the values before it is #{Plot.label(sum)}"}

      _other ->
        nil
    end)
  end

  defp number({:total, value}), do: value
  defp number(:total), do: 0
  defp number(value), do: value

  defp round_to(value, decimals), do: Plot.number(Float.round(value / 1, decimals))

  # Each column is inside the range of the axis.
  defp range(%Chart{value_range: nil}, _columns), do: :ok

  defp range(%Chart{value_range: {low, high}, categories: categories}, columns) do
    columns
    |> Enum.zip(categories)
    |> Enum.find_value(:ok, fn {column, category} ->
      outside = Enum.find([column.from, column.to], &(&1 < low or &1 > high))

      if outside && not (column.type == :total and outside == column.from),
        do:
          {:error,
           "the column \"#{category}\" reaches #{Plot.label(outside)}, and the value_range " <>
             "option is {#{Plot.label(low)}, #{Plot.label(high)}}"}
    end)
  end

  @doc """
  Return the columns of the values of a waterfall chart

  A total starts at zero and ends at the running total. A change starts at
  the running total before it and ends at the new running total.

      iex> Expresso.Element.Chart.Waterfall.columns([50, 40, -10, :total])
      [
        %{type: :total, change: nil, from: 0, to: 50, total: 50},
        %{type: :up, change: 40, from: 50, to: 90, total: 90},
        %{type: :down, change: -10, from: 90, to: 80, total: 80},
        %{type: :total, change: nil, from: 0, to: 80, total: 80}
      ]
  """
  @spec columns([value()]) :: [column()]
  def columns([start | changes]) do
    first = %{type: :total, change: nil, from: 0, to: start, total: start}

    {rest, _total} =
      Enum.map_reduce(changes, start, fn
        value, total when is_number(value) ->
          next = Plot.number(total + value)
          type = if value < 0, do: :down, else: :up
          {%{type: type, change: value, from: total, to: next, total: next}, next}

        _total_mark, total ->
          {%{type: :total, change: nil, from: 0, to: total, total: total}, total}
      end)

    [first | rest]
  end

  @doc """
  Read a cell of a value from the CSV file of a waterfall chart

  A cell holds a number, the word `total`, or the word `total` and the value
  that the author expects. The function returns `nil` for another cell.

      iex> Expresso.Element.Chart.Waterfall.cell("40")
      40
      iex> Expresso.Element.Chart.Waterfall.cell("total")
      :total
      iex> Expresso.Element.Chart.Waterfall.cell(" Total 1,250 ")
      {:total, 1250}
      iex> Expresso.Element.Chart.Waterfall.cell("many")
      nil
  """
  @spec cell(String.t()) :: value() | nil
  def cell(text) do
    case String.split(text) do
      [word] -> if total?(word), do: :total, else: Csv.number(text)
      [word, number] -> if total?(word), do: total_cell(Csv.number(number))
      _other -> nil
    end
  end

  defp total?(word), do: String.downcase(word) == "total"

  defp total_cell(nil), do: nil
  defp total_cell(number), do: {:total, number}

  @doc """
  Return the options of `Expresso.Element.Chart.Csv` for the file of a
  waterfall chart: the reader of a cell, and the words of its error
  """
  @spec reader() :: keyword()
  def reader,
    do: [cell: &cell/1, needs: "values, and a value is a number, total, or total and a number"]

  @doc """
  Write a change with its sign

      iex> Expresso.Element.Chart.Waterfall.signed(40)
      "+40"
      iex> Expresso.Element.Chart.Waterfall.signed(-2.5)
      "-2.5"
  """
  @spec signed(number()) :: String.t()
  def signed(value) when value < 0, do: Plot.label(value)
  def signed(value), do: "+" <> Plot.label(value)

  @doc """
  Make the assigns of a waterfall chart that the other kinds do not have

  `Expresso.Element.Chart.get_assigns/1` merges them into the assigns of a
  chart with an axis.
  """
  @spec assigns(Chart.t()) :: map()
  def assigns(%Chart{elements: [%Series{values: values} | _] = groups} = chart) do
    members =
      for i <- 0..(length(values) - 1) do
        case Enum.find_index(groups, &(&1.columns == nil or i in &1.columns)) do
          nil -> 0
          index -> index + 1
        end
      end

    %{
      value_range: chart.value_range,
      totals: chart.totals,
      spans: chart.spans,
      direction: chart.direction,
      members: members,
      revealed: match?([%Series{columns: [_ | _]} | _], groups),
      frames: frames(chart, values),
      frame_thumbnail: chart.thumbnail,
      grow: grow?(chart)
    }
  end

  # The values of each frame. The first frame holds the values of the series
  # of the chart.
  defp frames(%Chart{timeline: [_ | _] = timeline}, values) do
    for {%Frame{label: label, elements: [series | _]}, index} <- Enum.with_index(timeline),
        do: %{label: label, values: [if(index == 0, do: values, else: series.values)]}
  end

  defp frames(_chart, values), do: [%{label: nil, values: [values]}]

  @doc """
  Tell whether the columns of a waterfall chart move: with the steps of
  `reveal`, or with the effect `:grow`
  """
  @spec moves?(Chart.t()) :: boolean()
  def moves?(%Chart{elements: groups, timeline: timeline} = chart),
    do: match?([%Series{columns: [_ | _]} | _], groups) or length(timeline) > 1 or grow?(chart)

  @doc """
  Return the steps that a waterfall chart takes before its first change: 1
  with the groups of `reveal`, so the start and the totals show alone at the
  first step, else 0
  """
  @spec lead(Chart.t()) :: 0 | 1
  def lead(%Chart{elements: [%Series{columns: [_ | _]} | _]}), do: 1
  def lead(%Chart{}), do: 0

  defp grow?(%Chart{effect: effect, elements: groups}),
    do: effect == :grow or Enum.any?(groups, &(&1.effect == :grow))

  @doc """
  Return the CSS rules of the states of a waterfall chart with `reveal` or
  with frames

  The state of group `k` holds at the steps of group `k` at which group
  `k + 1` and the later frames do not show, and the state of a later frame
  holds at the steps of that frame. The first state is the value of each
  channel in the style attribute, so it needs no rule.
  """
  @spec rules(Chart.t()) :: [String.t()]
  def rules(%Chart{el: el} = chart) when is_binary(el) do
    frames = chart.timeline |> Enum.drop(1) |> Enum.map(&(&1.steps || []))

    groups =
      case chart.elements do
        [%Series{columns: [_ | _]} | _] = groups -> Enum.map(groups, &(&1.steps || []))
        _groups -> []
      end

    later = Enum.drop(groups, 1) ++ [List.flatten(frames)]
    steps = Enum.zip_with(groups, later, &(&1 -- &2)) ++ frames

    if steps == [],
      do: [],
      else: Motion.rules(chart |> Chart.get_assigns() |> layout(), el, steps)
  end

  def rules(%Chart{}), do: []

  @doc """
  Add the layout of a waterfall chart to its assigns: the axis, the box of the
  plot, the function `pos` from a value to a coordinate on the value axis,
  and the columns of each state

  A state is one set of values of the channels. A chart without steps has one
  state. The axis holds zero, or it has the ends of `value_range`. The value
  axis goes up the left side of a vertical chart, and along the bottom of a
  horizontal chart.
  """
  @spec layout(map()) :: map()
  def layout(assigns) do
    [first | later] = Enum.map(assigns.frames, fn %{values: [values]} -> columns(values) end)
    revealed = states(assigns, first)
    states = revealed ++ later
    finals = List.duplicate(first, length(revealed)) ++ later
    axis = axis(states, assigns.value_range)
    box = box(assigns, axis, states)
    count = length(assigns.categories)

    {pos, band} =
      case assigns.direction do
        :vertical ->
          {&(box.bottom - Scale.fraction(axis, &1) * (box.bottom - box.top)),
           (box.right - box.left) / count}

        :horizontal ->
          {&(box.left + Scale.fraction(axis, &1) * (box.right - box.left)),
           (box.bottom - box.top) / count}
      end

    Map.merge(assigns, %{
      states: states,
      finals: finals,
      labels: label_states(assigns.frames, length(revealed)),
      thumbnail: thumbnail(assigns[:frame_thumbnail], length(revealed), length(later)),
      axis: axis,
      box: box,
      pos: pos,
      base: axis_base(axis),
      band: band
    })
  end

  # The label of the frame of each state: the first frame for each state of
  # `reveal`, then each later frame.
  defp label_states([first | later], count),
    do: List.duplicate(%{label: first.label}, count) ++ Enum.map(later, &%{label: &1.label})

  # The number of the state that the overview and the menu of the slides
  # show, from 1: the last state of the frame of the `thumbnail` option. The
  # first frame ends at the last state of `reveal`.
  defp thumbnail(:last, revealed, later), do: revealed + later

  defp thumbnail(frame, revealed, _later) when is_integer(frame) and frame > 1,
    do: revealed + frame - 1

  defp thumbnail(_first, revealed, _later), do: revealed

  # The columns of each state: one state for each group of `reveal`, from
  # group 0. A total of `totals :grow` holds the running total of the changes
  # of the groups that show. A change keeps its place, because it shows at
  # its place.
  defp states(%{revealed: true, totals: :grow, members: members}, final) do
    for k <- 0..Enum.max(members), do: partial(final, members, k)
  end

  defp states(%{revealed: true, members: members}, final),
    do: List.duplicate(final, Enum.max(members) + 1)

  defp states(_assigns, final), do: [final]

  defp partial([start | rest], [_group | members], k) do
    {columns, _sum} =
      rest
      |> Enum.zip(members)
      |> Enum.map_reduce(start.total, fn
        {%{type: :total} = column, _group}, sum -> {%{column | to: sum, total: sum}, sum}
        {column, group}, sum when group <= k -> {column, Plot.number(sum + column.change)}
        {column, _group}, sum -> {column, sum}
      end)

    [start | columns]
  end

  # The axis: from the ends of each column and zero, or from `value_range`.
  defp axis(states, nil) do
    ticks = states |> List.flatten() |> Enum.flat_map(&[&1.from, &1.to]) |> Plot.ticks()
    %Scale{type: :linear, low: hd(ticks), high: List.last(ticks), ticks: ticks}
  end

  defp axis(_states, {low, high} = range), do: Scale.new([low, high], range, :linear)

  # The value at the base of a total: zero, or the end of the axis nearest to
  # zero when the axis does not hold zero.
  defp axis_base(%Scale{low: low, high: high}), do: min(max(0, low), high)

  @doc """
  Tell whether the axis of a waterfall chart does not hold zero

  Such an axis has a break mark at its base, and each total column has a
  break mark at its base.
  """
  @spec cut?(map()) :: boolean()
  def cut?(%{axis: %Scale{low: low, high: high}}), do: low > 0 or high < 0

  # The box of the plot inside the SVG. A vertical chart has the ticks of the
  # axis and its title at the left edge, and the categories and their title
  # at the bottom edge. A horizontal chart has the categories and their title
  # at the left edge, the ticks and their title at the bottom edge, and the
  # labels at the ends of the bars at the right edge. The spans take room at
  # the top of a vertical chart and at the right of a horizontal chart.
  defp box(%{direction: :vertical} = assigns, axis, _states) do
    widest = axis.ticks |> Enum.map(&String.length(Plot.label(&1))) |> Enum.max()
    left = 24 + widest * 10 + if(assigns[:value_label], do: 32, else: 0)
    top = if(label?(assigns), do: 64, else: 28) + if(assigns.spans, do: 44, else: 0)
    bottom = @height - 40 - if(assigns[:category_label], do: 30, else: 0)
    %{left: left, top: top, right: @width - 16, bottom: bottom}
  end

  defp box(%{direction: :horizontal} = assigns, _axis, states) do
    widest = assigns.categories |> Enum.map(&String.length/1) |> Enum.max()
    left = min(24 + widest * 10, 280) + if(assigns[:category_label], do: 32, else: 0)

    # The widest labels at the end of a bar: a change and its running total.
    labels =
      states
      |> List.flatten()
      |> Enum.map(&(String.length(Plot.label(&1.total)) + if(&1.change, do: 8, else: 0)))
      |> Enum.max()

    right = @width - 16 - labels * 10 - if(assigns.spans, do: 64, else: 0)
    top = if label?(assigns), do: 64, else: 28
    bottom = @height - 40 - if(assigns[:value_label], do: 30, else: 0)
    %{left: left, top: top, right: right, bottom: bottom}
  end

  defp label?(%{frames: [_, _ | _], frame_label: place}), do: place != :none
  defp label?(_assigns), do: false

  @doc """
  Return the places of the columns, of their labels and of the connectors in
  each state, and the channels that hold them

  A column has the channels `u`, `v`, `w` and `h`, its label of the total or
  of the running total has `l`, its number `n`, the signed change has `m`,
  and the connector at its left has `j`. A label and a connector have their
  place on the value axis in the channel, and their place on the axis of the
  categories in their style. `Expresso.Element.Chart.Motion` leaves out a
  channel that has the same value in each state.
  """
  @spec scene(map()) :: %{
          marks: [map()],
          spans: [map()],
          channels: [{String.t(), [number()]}]
        }
  def scene(assigns) do
    count = length(assigns.categories)

    marks =
      for i <- 0..(count - 1) do
        columns = Enum.map(assigns.states, &Enum.at(&1, i))
        places = Enum.map(columns, &place(assigns, i, &1))
        first = hd(columns)
        inside = assigns.values and first.type != :total and inside?(assigns, places, first)

        %{
          index: i,
          type: first.type,
          group: Enum.at(assigns.members, i),
          join_group: max(Enum.at(assigns.members, i), Enum.at(assigns.members, max(i - 1, 0))),
          columns: columns,
          places: places,
          inside: inside,
          labels: Enum.map(places, &label_at(assigns.direction, &1, first, inside)),
          changes: Enum.map(places, &change_at(assigns.direction, &1, inside)),
          joins: Enum.map(assigns.finals, &join_at(assigns, &1, i))
        }
      end

    channels =
      Enum.flat_map(marks, fn mark ->
        i = mark.index

        [
          {"u#{i}", Enum.map(mark.places, & &1.u)},
          {"v#{i}", Enum.map(mark.places, & &1.v)},
          {"w#{i}", Enum.map(mark.places, & &1.w)},
          {"h#{i}", Enum.map(mark.places, & &1.h)},
          {"l#{i}", mark.labels},
          {"n#{i}", Enum.map(mark.columns, & &1.total)}
        ] ++
          if(mark.type != :total, do: [{"m#{i}", mark.changes}], else: []) ++
          if(i > 0, do: [{"j#{i}", mark.joins}], else: [])
      end) ++ Motion.flags(assigns.states)

    spans = spans(assigns, marks)

    span_channels =
      Enum.flat_map(spans, fn span ->
        [{"sy#{span.number}", span.ys}, {"sn#{span.number}", span.values}]
      end)

    %{marks: marks, spans: spans, channels: channels ++ span_channels}
  end

  # The spans of `spans true`: one from each total to the next total with a
  # change between them. A span has the sum of the changes between its two
  # totals in the frame of each state, and its line goes past the labels of the furthest column between
  # them in each state: over them in a vertical chart, and at their right in
  # a horizontal chart. It shows with the last column before the total at its
  # end, so it shows when that total is complete.
  defp spans(%{spans: false}, _marks), do: []

  defp spans(assigns, marks) do
    marks
    |> Enum.filter(&(&1.type == :total))
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.filter(fn [from, to] -> to.index - from.index > 1 end)
    |> Enum.with_index(1)
    |> Enum.map(fn {[from, to], number} ->
      between = Enum.slice(marks, from.index..to.index)
      line = span_line(assigns, between)

      %{
        number: number,
        from: from,
        to: to,
        group: between |> Enum.drop(1) |> Enum.map(& &1.group) |> Enum.max(),
        values:
          Enum.map(assigns.finals, fn final ->
            Plot.number(Enum.at(final, to.index).total - Enum.at(final, from.index).total)
          end),
        ys: Enum.map(assigns.finals, fn _state -> line end)
      }
    end)
  end

  # The place of the line of a span on the value axis.
  defp span_line(%{direction: :vertical} = assigns, between) do
    top =
      between
      |> Enum.flat_map(fn mark -> Enum.map(mark.places, &min(&1.v, label_top(mark, &1))) end)
      |> Enum.min()

    max(top - 22, assigns.box.top - 36)
  end

  defp span_line(%{direction: :horizontal} = assigns, between) do
    right =
      between
      |> Enum.flat_map(fn mark -> Enum.map(mark.places, &label_right(mark, &1)) end)
      |> Enum.max()

    min(right + 22, assigns.box.right + 40)
  end

  # The top of the labels over a column, and the right end of the labels at
  # the end of a bar.
  defp label_top(%{type: :total}, place), do: place.v - 26
  defp label_top(%{inside: true}, place), do: place.v - 26
  defp label_top(_mark, place), do: place.v - 48

  defp label_right(mark, place) do
    text = mark.columns |> hd() |> label_text(mark.inside)
    place.u + place.w + 8 + String.length(text) * 10
  end

  defp label_text(%{change: nil, total: total}, _inside), do: Plot.label(total)
  defp label_text(%{total: total}, true), do: Plot.label(total)
  defp label_text(%{change: change, total: total}, false), do: "#{signed(change)}  #{total}"

  # The corner at the top left of a column and its size, and `anchor`, the
  # place of its base on the value axis. A column of the change zero is a
  # line of one unit.
  defp place(assigns, i, column) do
    from = if column.type == :total, do: assigns.base, else: column.from
    a = assigns.pos.(from)
    b = assigns.pos.(column.to)
    thickness = assigns.band * @column
    across = assigns.band * i + (assigns.band - thickness) / 2

    case assigns.direction do
      :vertical ->
        %{
          u: assigns.box.left + across,
          v: min(a, b),
          w: thickness,
          h: max(abs(a - b), 1),
          up: column.to >= from,
          anchor: a
        }

      :horizontal ->
        %{
          u: min(a, b),
          v: assigns.box.top + across,
          w: max(abs(a - b), 1),
          h: thickness,
          up: column.to >= from,
          anchor: a
        }
    end
  end

  # A column holds the text of its change when it is long enough: 22 units
  # high, or as wide as the text.
  defp inside?(%{direction: :vertical}, places, _column),
    do: Enum.all?(places, &(&1.h >= @inside))

  defp inside?(%{direction: :horizontal}, places, column) do
    width = String.length(signed(column.change)) * 10 + 12
    Enum.all?(places, &(&1.w >= width))
  end

  # The place on the value axis of the label of the total or of the running
  # total. In a vertical chart, it is the base line of the text over the
  # column, or under a column that goes down from zero. A change with its
  # text outside the column has two lines of text over it. In a horizontal
  # chart, it is the start of the text at the right of the bar, or the end of
  # the text at the left of a bar that goes left from zero.
  defp label_at(:vertical, place, %{type: :total}, _inside) do
    if place.up, do: place.v - 8, else: place.v + place.h + 20
  end

  defp label_at(:vertical, place, _column, true), do: place.v - 8
  defp label_at(:vertical, place, _column, false), do: place.v - 30

  defp label_at(:horizontal, place, %{type: :total}, _inside) do
    if place.up, do: place.u + place.w + 8, else: place.u - 8
  end

  defp label_at(:horizontal, place, _column, true), do: place.u + place.w + 8

  defp label_at(:horizontal, place, column, false),
    do: place.u + place.w + 20 + String.length(signed(column.change)) * 10

  # The place on the value axis of the signed change: at the middle of a
  # column that holds it, else beside the column.
  defp change_at(:vertical, place, true), do: place.v + place.h / 2 + 6
  defp change_at(:vertical, place, false), do: place.v - 8
  defp change_at(:horizontal, place, true), do: place.u + place.w / 2
  defp change_at(:horizontal, place, false), do: place.u + place.w + 8

  # The connector at the left of column `i`: at the running total after the
  # column before it.
  defp join_at(_assigns, _columns, 0), do: 0
  defp join_at(assigns, columns, i), do: assigns.pos.(Enum.at(columns, i - 1).total)

  @doc """
  Draw the content of the SVG of a waterfall chart: the axis, the columns,
  their labels and the connectors
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    assigns = Map.merge(assigns, %{scene: scene(assigns), cut: cut?(assigns)})

    temple do
      c(&frame_label/1, rest!: assigns)
      c(&axis/1, rest!: assigns)
      c(&titles/1, rest!: assigns)

      if Enum.any?(@scene.marks, &(&1.group == 0)) do
        g class: "chart-series" do
          c(&group/1, rest!: Map.put(assigns, :group, 0))
        end
      end

      for {series, k} <- Enum.with_index(@series, 1) do
        g class: Expresso.Element.classes("chart-series", series.class), rest!: series.overlay do
          c(&group/1, rest!: Map.put(assigns, :group, k))
        end
      end
    end
  end

  # The label of the frame of each state, at the top of a chart with frames.
  defp frame_label(%{frames: [_, _ | _]} = assigns),
    do: Motion.frame_label(Map.put(assigns, :frames, assigns.labels))

  defp frame_label(_assigns), do: Phoenix.HTML.raw("")

  # The connectors and the columns of one group. A connector shows with the
  # later of its two columns.
  defp group(assigns) do
    temple do
      for mark <- @scene.marks, mark.index > 0, mark.join_group == @group do
        c(&join/1, rest!: Map.merge(assigns, %{mark: mark, key: Chart.key(assigns, mark.index)}))
      end

      for mark <- @scene.marks, mark.group == @group do
        c(&column/1, rest!: Map.put(assigns, :mark, mark))
      end

      for span <- @scene.spans, span.group == @group do
        c(&span/1, rest!: Map.put(assigns, :span, span))
      end
    end
  end

  # A span: a line with an arrow from the middle of one total to the middle of
  # the next total, with a short tick at each end toward the columns, and the
  # sum of the changes between them beside its middle.
  defp span(assigns) do
    %{span: span} = assigns
    from = hd(span.from.places)
    to = hd(span.to.places)
    n = span.number

    keys =
      case {Chart.key(assigns, span.from.index), Chart.key(assigns, span.to.index)} do
        {nil, nil} -> nil
        {first, last} -> "#{first} #{last}"
      end

    {style, d, value} = span_shape(assigns.direction, span, from, to)

    assigns =
      Map.merge(assigns, %{
        style: style,
        d: d,
        keys: keys,
        value:
          Motion.text_assigns(
            Enum.map(span.values, &signed/1),
            [],
            "sn#{n}",
            [class: "chart-span-value", keys: keys] ++ value
          )
      })

    temple do
      g class: "chart-mark", style: @style, data_keys: @keys do
        path class: "chart-waterfall-span", d: @d, data_keys: @keys
        c(&Motion.changing/1, rest!: @value)
      end
    end
  end

  # The style, the path and the place of the text of a span. A vertical
  # chart has a line from left to right over the columns, and a horizontal
  # chart has a line from top to bottom at the right of the bars.
  defp span_shape(:vertical, span, from, to) do
    x = from.u + from.w / 2
    length = to.u + to.w / 2 - x

    {Motion.style([
       {"--chart-u", Plot.f(x)},
       {"--chart-v", Motion.ref("sy#{span.number}", span.ys)}
     ]),
     "M0 8V0H#{Plot.f(length)}V8M#{Plot.f(length - 6)} -4L#{Plot.f(length)} 0" <>
       "L#{Plot.f(length - 6)} 4", [x: Plot.f(length / 2), y: -8]}
  end

  defp span_shape(:horizontal, span, from, to) do
    y = from.v + from.h / 2
    length = to.v + to.h / 2 - y

    {Motion.style([
       {"--chart-u", Motion.ref("sy#{span.number}", span.ys)},
       {"--chart-v", Plot.f(y)}
     ]),
     "M-8 0H0V#{Plot.f(length)}H-8M-4 #{Plot.f(length - 6)}L0 #{Plot.f(length)}" <>
       "L4 #{Plot.f(length - 6)}", [x: 8, y: Plot.f(length / 2 + 6), anchor: "start"]}
  end

  # One column with its break mark and its labels. The effect `:grow` grows
  # a column from its base: up or down in a vertical chart, and to the right
  # or to the left in a horizontal chart.
  defp column(assigns) do
    %{mark: mark} = assigns
    i = mark.index
    anchor = hd(mark.places).anchor
    channel = &Motion.ref("#{&1}#{i}", Enum.map(mark.places, fn place -> place[&1] end))

    style =
      case assigns.direction do
        :vertical ->
          [
            {"--chart-u", channel.(:u)},
            {"--chart-v", grow(assigns, channel.(:v), anchor)},
            {"--chart-w", channel.(:w)},
            {"--chart-h", grow(assigns, channel.(:h), 0)}
          ]

        :horizontal ->
          [
            {"--chart-u", grow(assigns, channel.(:u), anchor)},
            {"--chart-v", channel.(:v)},
            {"--chart-w", grow(assigns, channel.(:w), 0)},
            {"--chart-h", channel.(:h)}
          ]
      end

    assigns = Map.merge(assigns, %{style: Motion.style(style), key: Chart.key(assigns, i)})

    temple do
      rect class: "chart-waterfall-bar chart-waterfall-#{@mark.type}",
           x: 0,
           y: 0,
           width: 1,
           height: 1,
           style: @style,
           data_keys: @key

      if @cut and @mark.type == :total do
        c(&column_break/1, rest!: assigns)
      end

      if @values do
        c(&labels/1, rest!: assigns)
      end
    end
  end

  # A place that the effect `:grow` moves from `from`, or the place alone.
  defp grow(%{grow: true}, value, from), do: Motion.grow(value, from)
  defp grow(_assigns, value, _from), do: value

  # The dashed line from the end of the column before to the start of this
  # column: across the gap between two columns, at the running total.
  defp join(assigns) do
    %{mark: mark, scene: scene} = assigns
    from = hd(Enum.at(scene.marks, mark.index - 1).places)
    to = hd(mark.places)
    at = Motion.ref("j#{mark.index}", mark.joins)

    {style, x2, y2} =
      case assigns.direction do
        :vertical ->
          start = from.u + from.w
          {[{"--chart-u", Plot.f(start)}, {"--chart-v", at}], Plot.f(to.u - start), 0}

        :horizontal ->
          start = from.v + from.h
          {[{"--chart-u", at}, {"--chart-v", Plot.f(start)}], 0, Plot.f(to.v - start)}
      end

    assigns = Map.merge(assigns, %{join_style: Motion.style(style), x2: x2, y2: y2})

    temple do
      line class: "chart-waterfall-line chart-mark",
           x1: 0,
           y1: 0,
           x2: @x2,
           y2: @y2,
           style: @join_style,
           data_keys: @key
    end
  end

  # The break mark at the base of a total column of a cut axis.
  defp column_break(assigns) do
    place = hd(assigns.mark.places)

    d =
      case assigns.direction do
        :vertical -> zigzag({place.u, place.u + place.w}, assigns.box.bottom - 6)
        :horizontal -> zigzag(assigns.box.left + 6, {place.v, place.v + place.h})
      end

    assigns = Map.put(assigns, :d, d)

    temple do
      path class: "chart-break", d: @d
    end
  end

  # The labels of a column: the value of a total, or the signed change and
  # the running total of a change.
  defp labels(assigns) do
    %{mark: mark} = assigns
    i = mark.index
    place = hd(mark.places)
    totals = Enum.map(mark.columns, & &1.total)

    {label, anchor} =
      label_style(assigns, mark, Motion.ref("l#{i}", mark.labels), place)

    assigns =
      Map.merge(assigns, %{
        label: label,
        total:
          Motion.text_assigns(Enum.map(totals, &Plot.label/1), totals, "n#{i}",
            count: true,
            anchor: anchor
          ),
        change: change_text(assigns, mark),
        change_style: change_style(assigns, mark, place)
      })

    temple do
      g class: "chart-mark", style: @label, data_keys: @key do
        c(&Motion.changing/1,
          rest!:
            Map.merge(@total, %{
              class: if(@mark.type == :total, do: "chart-value", else: "chart-running"),
              keys: @key
            })
        )
      end

      if @change do
        g class: "chart-mark", style: @change_style, data_keys: @key do
          c(&Motion.changing/1, rest!: @change)
        end
      end
    end
  end

  # The text of the signed change in the frame of each state. A change of a
  # chart with frames has one copy of its text for each state, and the copy
  # of the state that shows has the opacity 1.
  defp change_text(_assigns, %{type: :total}), do: nil

  defp change_text(assigns, mark) do
    anchor = if assigns.direction == :horizontal and not mark.inside, do: "start", else: "middle"

    Motion.text_assigns(Enum.map(mark.columns, &signed(&1.change)), [], "",
      anchor: anchor,
      class: if(mark.inside, do: "chart-waterfall-change", else: "chart-value"),
      keys: Chart.key(assigns, mark.index)
    )
  end

  # The style of the label of the total or of the running total, and the
  # anchor of its text.
  defp label_style(%{direction: :vertical} = assigns, _mark, value, place) do
    x = Plot.f(place.u + place.w / 2)

    {Motion.style([{"--chart-u", x}, {"--chart-v", grow(assigns, value, place.anchor - 8)}]),
     "middle"}
  end

  defp label_style(%{direction: :horizontal} = assigns, mark, value, place) do
    y = Plot.f(place.v + place.h / 2 + 6)
    anchor = if mark.type == :total and not place.up, do: "end", else: "start"

    {Motion.style([{"--chart-u", grow(assigns, value, place.anchor + 8)}, {"--chart-v", y}]),
     anchor}
  end

  defp change_style(_assigns, %{type: :total}, _place), do: nil

  defp change_style(%{direction: :vertical} = assigns, mark, place) do
    value = Motion.ref("m#{mark.index}", mark.changes)
    x = Plot.f(place.u + place.w / 2)
    Motion.style([{"--chart-u", x}, {"--chart-v", grow(assigns, value, place.anchor)}])
  end

  defp change_style(%{direction: :horizontal} = assigns, mark, place) do
    value = Motion.ref("m#{mark.index}", mark.changes)
    y = Plot.f(place.v + place.h / 2 + 6)
    Motion.style([{"--chart-u", grow(assigns, value, place.anchor)}, {"--chart-v", y}])
  end

  # The grid, the ticks, the base line at zero, the categories, and the break
  # mark of a cut axis.
  defp axis(%{direction: :vertical} = assigns) do
    temple do
      g class: "chart-axis" do
        for tick <- @axis.ticks do
          line class: if(tick == 0, do: "chart-base", else: "chart-grid"),
               x1: @box.left,
               x2: @box.right,
               y1: Plot.f(@pos.(tick)),
               y2: Plot.f(@pos.(tick))

          text x: @box.left - 10,
               y: Plot.f(@pos.(tick) + 5),
               text_anchor: "end",
               class: "chart-tick" do
            Plot.label(tick)
          end
        end

        for {category, i} <- Enum.with_index(@categories) do
          text x: Plot.f(@box.left + @band * (i + 0.5)),
               y: @box.bottom + 28,
               text_anchor: "middle",
               class: "chart-category",
               data_keys: Chart.key(assigns, i) do
            category
          end
        end

        if @cut do
          path class: "chart-break", d: zigzag({@box.left + 2, @box.left + 18}, @box.bottom - 8)
        end
      end
    end
  end

  defp axis(%{direction: :horizontal} = assigns) do
    temple do
      g class: "chart-axis" do
        for tick <- @axis.ticks do
          line class: if(tick == 0, do: "chart-base", else: "chart-grid"),
               x1: Plot.f(@pos.(tick)),
               x2: Plot.f(@pos.(tick)),
               y1: @box.top,
               y2: @box.bottom

          text x: Plot.f(@pos.(tick)),
               y: @box.bottom + 28,
               text_anchor: "middle",
               class: "chart-tick" do
            Plot.label(tick)
          end
        end

        for {category, i} <- Enum.with_index(@categories) do
          text x: @box.left - 10,
               y: Plot.f(@box.top + @band * (i + 0.5) + 6),
               text_anchor: "end",
               class: "chart-category",
               data_keys: Chart.key(assigns, i) do
            category
          end
        end

        if @cut do
          path class: "chart-break", d: zigzag(@box.left + 8, {@box.bottom - 18, @box.bottom - 2})
        end
      end
    end
  end

  # A zigzag across a line: from `left` to `right` at the height `y`, or from
  # `top` to `bottom` at the place `x`.
  defp zigzag({left, right}, y) do
    points =
      teeth(left, right, fn place, side -> "#{Plot.f(place)} #{Plot.f(y + side * 3)}" end)

    "M" <> Enum.join(points, "L")
  end

  defp zigzag(x, {top, bottom}) do
    points =
      teeth(top, bottom, fn place, side -> "#{Plot.f(x + side * 3)} #{Plot.f(place)}" end)

    "M" <> Enum.join(points, "L")
  end

  defp teeth(from, to, point) do
    count = max(round((to - from) / 6), 2)
    step = (to - from) / count
    for n <- 0..count, do: point.(from + n * step, if(rem(n, 2) == 0, do: 1, else: -1))
  end

  # The names of the two axes: the name under the axis along the bottom, and
  # the name beside the axis at the left, turned to read from the bottom up.
  defp titles(assigns) do
    {bottom, left} =
      case assigns.direction do
        :vertical -> {assigns[:category_label], assigns[:value_label]}
        :horizontal -> {assigns[:value_label], assigns[:category_label]}
      end

    assigns = Map.merge(assigns, %{bottom_title: bottom, left_title: left})

    temple do
      if @bottom_title do
        text x: Plot.f((@box.left + @box.right) / 2),
             y: @box.bottom + 62,
             text_anchor: "middle",
             class: "chart-axis-title" do
          @bottom_title
        end
      end

      if @left_title do
        text x: 0,
             y: 0,
             transform: "translate(22 #{Plot.f((@box.top + @box.bottom) / 2)}) rotate(-90)",
             text_anchor: "middle",
             class: "chart-axis-title" do
          @left_title
        end
      end
    end
  end

  @doc """
  Return the headers and the rows of the table of a waterfall chart

  The table has one row for each column, with its category, its change and
  the running total after it. A total has no change.
  """
  @spec table(map()) :: %{headers: [String.t() | nil], rows: [[String.t()]]}
  def table(assigns) do
    frames =
      Enum.map(assigns.frames, fn %{values: [values]} = frame -> {frame, columns(values)} end)

    rows =
      for {category, i} <- Enum.with_index(assigns.categories) do
        cells =
          Enum.flat_map(frames, fn {_frame, columns} ->
            column = Enum.at(columns, i)
            [if(column.change, do: signed(column.change), else: ""), Plot.label(column.total)]
          end)

        [category | cells]
      end

    headers =
      case frames do
        [_one] ->
          ["Change", "Total"]

        _frames ->
          for {frame, _columns} <- frames,
              name <- ["Change", "Total"],
              do: "#{name} #{frame.label}"
      end

    %{headers: [assigns.category_label | headers], rows: rows}
  end
end
