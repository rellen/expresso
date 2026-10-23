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
  step of each change, and its value counts. `rules/1` writes the channels of
  each state at its steps.

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
  alias Expresso.Element.Series

  # The box of the chart in the units of the SVG.
  @width 800
  @height 450

  # The part of the band of a category that its column takes.
  @column 0.7

  # The least height of a column that holds the text of its change.
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
         :ok <- revealed(chart, series) do
      {:ok, %Chart{chart | elements: groups(chart, series)}}
    end
  end

  # A chart that the check put into groups holds the whole series in each
  # group, so a second check starts from the first group.
  defp whole(%Chart{elements: [%Series{columns: [_ | _]} = group | _]} = chart),
    do: %Chart{chart | elements: [%Series{group | columns: nil}]}

  defp whole(chart), do: chart

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

  defp options(%Chart{} = chart) when chart.frames != nil or chart.timeline != [],
    do: {:error, "a waterfall chart takes no frames"}

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
      members: members,
      revealed: match?([%Series{columns: [_ | _]} | _], groups),
      frames: [%{label: nil, values: [values]}],
      grow: grow?(chart)
    }
  end

  @doc """
  Tell whether the columns of a waterfall chart move: with the steps of
  `reveal`, or with the effect `:grow`
  """
  @spec moves?(Chart.t()) :: boolean()
  def moves?(%Chart{elements: groups} = chart),
    do: match?([%Series{columns: [_ | _]} | _], groups) or grow?(chart)

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
  Return the CSS rules of the states of a waterfall chart with `reveal`

  The state of group `k` holds at the steps of group `k` at which group
  `k + 1` does not show. The first state is the value of each channel in the
  style attribute, so it needs no rule.
  """
  @spec rules(Chart.t()) :: [String.t()]
  def rules(%Chart{el: el, elements: [%Series{columns: [_ | _]} | _] = groups} = chart)
      when is_binary(el) do
    assigns = chart |> Chart.get_assigns() |> layout()
    steps = Enum.map(groups, &(&1.steps || []))
    Motion.rules(assigns, el, Enum.zip_with(steps, tl(steps) ++ [[]], &(&1 -- &2)))
  end

  def rules(%Chart{}), do: []

  @doc """
  Add the layout of a waterfall chart to its assigns: the axis, the box of the
  plot, the function `y` from a value to a coordinate, and the columns of
  each state

  A state is one set of values of the channels. A chart without steps has one
  state. The axis holds zero, or it has the ends of `value_range`.
  """
  @spec layout(map()) :: map()
  def layout(assigns) do
    %{values: [values]} = hd(assigns.frames)
    final = columns(values)
    states = states(assigns, final)
    axis = axis(states, assigns.value_range)
    box = box(assigns, axis)
    y = &(box.bottom - Scale.fraction(axis, &1) * (box.bottom - box.top))

    Map.merge(assigns, %{
      states: states,
      finals: Enum.map(states, fn _state -> final end),
      thumbnail: length(states),
      axis: axis,
      box: box,
      y: y,
      base: axis_base(axis),
      band: (box.right - box.left) / length(assigns.categories)
    })
  end

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

  # The box of the plot inside the SVG: the left edge holds the ticks of the
  # axis and its title, and the bottom edge holds the categories and their
  # title.
  defp box(assigns, axis) do
    widest = axis.ticks |> Enum.map(&String.length(Plot.label(&1))) |> Enum.max()
    left = 24 + widest * 10 + if(assigns[:value_label], do: 32, else: 0)
    top = if label?(assigns), do: 64, else: 28
    bottom = @height - 40 - if(assigns[:category_label], do: 30, else: 0)
    %{left: left, top: top, right: @width - 16, bottom: bottom}
  end

  defp label?(%{frames: [_, _ | _], frame_label: place}), do: place != :none
  defp label?(_assigns), do: false

  @doc """
  Return the places of the columns, of their labels and of the connectors in
  each state, and the channels that hold them

  A column has the channels `u`, `v`, `w` and `h`, its label of the total or
  of the running total has `l`, its number `n`, and the connector at its left
  has `j`. `Expresso.Element.Chart.Motion` leaves out a channel that has the
  same value in each state.
  """
  @spec scene(map()) :: %{marks: [map()], channels: [{String.t(), [number()]}]}
  def scene(assigns) do
    count = length(assigns.categories)

    marks =
      for i <- 0..(count - 1) do
        columns = Enum.map(assigns.states, &Enum.at(&1, i))
        places = Enum.map(columns, &place(assigns, i, &1))
        inside = assigns.values and hd(columns).type != :total and inside?(places)

        %{
          index: i,
          type: hd(columns).type,
          group: Enum.at(assigns.members, i),
          join_group: max(Enum.at(assigns.members, i), Enum.at(assigns.members, max(i - 1, 0))),
          columns: columns,
          places: places,
          inside: inside,
          labels: Enum.map(places, &label_y(&1, hd(columns), inside)),
          changes: Enum.map(places, &change_y(&1, inside)),
          joins: Enum.map(assigns.finals, &join_y(assigns, &1, i))
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
      end) ++ Motion.flags(assigns.frames)

    %{marks: marks, channels: channels}
  end

  # The corner at the top left of a column and its size. A column of the
  # change zero is a line of one unit.
  defp place(assigns, i, column) do
    from = if column.type == :total, do: assigns.base, else: column.from
    top = assigns.y.(max(from, column.to))
    bottom = assigns.y.(min(from, column.to))
    width = assigns.band * @column

    %{
      u: assigns.box.left + assigns.band * i + (assigns.band - width) / 2,
      v: top,
      w: width,
      h: max(bottom - top, 1),
      up: column.to >= from,
      anchor: assigns.y.(from)
    }
  end

  defp inside?(places), do: Enum.all?(places, &(&1.h >= @inside))

  # The base line of the label over a column, or under a column that goes
  # down from zero. A change with its text outside the column has two lines
  # of text over it.
  defp label_y(place, %{type: :total}, _inside) do
    if place.up, do: place.v - 8, else: place.v + place.h + 20
  end

  defp label_y(place, _column, true), do: place.v - 8
  defp label_y(place, _column, false), do: place.v - 30

  # The base line of the signed change: at the middle of a column that holds
  # it, else under the running total over the column.
  defp change_y(place, true), do: place.v + place.h / 2 + 6
  defp change_y(place, false), do: place.v - 8

  # The connector at the left of column `i`: at the running total after the
  # column before it.
  defp join_y(_assigns, _columns, 0), do: 0
  defp join_y(assigns, columns, i), do: assigns.y.(Enum.at(columns, i - 1).total)

  @doc """
  Draw the content of the SVG of a waterfall chart: the axis, the columns,
  their labels and the connectors
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    assigns = Map.merge(assigns, %{scene: scene(assigns), cut: cut?(assigns)})

    temple do
      c(&Motion.frame_label/1, rest!: assigns)
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
    end
  end

  # One column with its connector, its break mark and its labels.
  defp column(assigns) do
    %{mark: mark} = assigns
    i = mark.index

    anchor = hd(mark.places).anchor

    style =
      Motion.style([
        {"--chart-u", Motion.ref("u#{i}", Enum.map(mark.places, & &1.u))},
        {"--chart-v", grow(assigns, Motion.ref("v#{i}", Enum.map(mark.places, & &1.v)), anchor)},
        {"--chart-w", Motion.ref("w#{i}", Enum.map(mark.places, & &1.w))},
        {"--chart-h", grow(assigns, Motion.ref("h#{i}", Enum.map(mark.places, & &1.h)), 0)}
      ])

    assigns = Map.merge(assigns, %{style: style, key: Chart.key(assigns, i)})

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
  # column.
  defp join(assigns) do
    %{mark: mark, scene: scene} = assigns
    before = Enum.at(scene.marks, mark.index - 1)
    from = hd(before.places)
    to = hd(mark.places)
    x = from.u + from.w

    style =
      Motion.style([
        {"--chart-u", Plot.f(x)},
        {"--chart-v", Motion.ref("j#{mark.index}", mark.joins)}
      ])

    assigns = Map.merge(assigns, %{length: to.u - x, join_style: style})

    temple do
      line class: "chart-waterfall-line chart-mark",
           x1: 0,
           y1: 0,
           x2: Plot.f(@length),
           y2: 0,
           style: @join_style,
           data_keys: @key
    end
  end

  # The break mark at the base of a total column of a cut axis.
  defp column_break(assigns) do
    place = hd(assigns.mark.places)
    assigns = Map.put(assigns, :d, zigzag(place.u, place.u + place.w, assigns.box.bottom - 6))

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
    x = Plot.f(place.u + place.w / 2)
    totals = Enum.map(mark.columns, & &1.total)

    label =
      Motion.style([
        {"--chart-u", x},
        {"--chart-v", grow(assigns, Motion.ref("l#{i}", mark.labels), place.anchor - 8)}
      ])

    assigns =
      Map.merge(assigns, %{
        label: label,
        total: Motion.text_assigns(Enum.map(totals, &Plot.label/1), totals, "n#{i}", count: true),
        change: if(mark.type != :total, do: signed(hd(mark.columns).change)),
        change_style: change_style(assigns, mark, x)
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
          text x: 0,
               y: 0,
               text_anchor: "middle",
               class: if(@mark.inside, do: "chart-waterfall-change", else: "chart-value"),
               data_keys: @key do
            @change
          end
        end
      end
    end
  end

  defp change_style(_assigns, %{type: :total}, _x), do: nil

  defp change_style(assigns, mark, x) do
    value = Motion.ref("m#{mark.index}", mark.changes)
    Motion.style([{"--chart-u", x}, {"--chart-v", grow(assigns, value, hd(mark.places).anchor)}])
  end

  # The grid, the ticks, the base line at zero, the categories, and the break
  # mark of a cut axis.
  defp axis(assigns) do
    temple do
      g class: "chart-axis" do
        for tick <- @axis.ticks do
          line class: if(tick == 0, do: "chart-base", else: "chart-grid"),
               x1: @box.left,
               x2: @box.right,
               y1: Plot.f(@y.(tick)),
               y2: Plot.f(@y.(tick))

          text x: @box.left - 10,
               y: Plot.f(@y.(tick) + 5),
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
          path class: "chart-break", d: zigzag(@box.left + 2, @box.left + 18, @box.bottom - 8)
        end
      end
    end
  end

  # A zigzag across a line from `left` to `right`, at the height `y`.
  defp zigzag(left, right, y) do
    teeth = max(round((right - left) / 6), 2)
    step = (right - left) / teeth

    points =
      for n <- 0..teeth do
        "#{Plot.f(left + n * step)} #{Plot.f(if rem(n, 2) == 0, do: y + 3, else: y - 3)}"
      end

    "M" <> Enum.join(points, "L")
  end

  # The name of the categories under them, and the name of the values beside
  # the axis, turned to read from the bottom up.
  defp titles(assigns) do
    temple do
      if @category_label do
        text x: Plot.f((@box.left + @box.right) / 2),
             y: @box.bottom + 62,
             text_anchor: "middle",
             class: "chart-axis-title" do
          @category_label
        end
      end

      if @value_label do
        text x: 0,
             y: 0,
             transform: "translate(22 #{Plot.f((@box.top + @box.bottom) / 2)}) rotate(-90)",
             text_anchor: "middle",
             class: "chart-axis-title" do
          @value_label
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
    [values] = hd(assigns.frames).values

    rows =
      for {category, column} <- Enum.zip(assigns.categories, columns(values)) do
        change = if column.change, do: signed(column.change), else: ""
        [category, change, Plot.label(column.total)]
      end

    %{headers: [assigns.category_label, "Change", "Total"], rows: rows}
  end
end
