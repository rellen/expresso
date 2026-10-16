defmodule Expresso.Element.Chart do
  @moduledoc """
  An element that draws a bar chart, a line chart, a pie chart, a treemap, a
  sunburst, a sankey, an alluvial chart, a parallel sets chart or a chord chart

  The `chart` entity takes the kind as its first argument: `:bar`, `:line`,
  `:pie`, `:treemap`, `:sunburst`, `:sankey`, `:alluvial`, `:parallel_sets` or
  `:chord`. A slash in a category of a treemap or a
  sunburst names a part of a group, and `Expresso.Element.Chart.Hierarchy`
  draws them. The `categories` option gives the names of the categories, and each
  `series` entity gives a name and one value for each category. The `src`
  option gives a CSV file in place of the two: the first row holds the names
  of the series, and each other row holds a category and its values.

  The render function draws the chart as SVG in the document, so the chart
  needs no script and no file, and it prints. The colors of the series are
  `--chart-1` to `--chart-8` of the theme, in a fixed order. A chart with two
  or more series has a legend, a bar shows its value, the end of a line shows
  its name and its last value, and the legend of a pie shows each part in
  percent. A table with the values goes into the document for a screen
  reader.

  A series is a child of the chart, so `reveal true` shows each series at its
  own step, and `dim true` dims each series when a later series shows. The
  `highlight` option shows each series at each step, and it puts one group of
  series in focus at each step: the other series dim. `check/1` makes an
  `Expresso.Element.Focus` for each group, and `rules/1` writes the rules
  that dim the series.

  A `frame` entity holds the series at one point in time, and each frame
  after the first takes one step. A chart with frames, or with the effect
  `:grow`, moves its marks: `Expresso.Element.Chart.Motion` draws them.
  `docs/reference/chart-element.md` gives the rules.

  A category of a sankey is a path of nodes. The `flow` entities give the
  same data in a shorter form. `Expresso.Element.Chart.Sankey` draws a
  sankey. With `reveal true`, the check makes one series for each step: a
  source column of the links in a sankey or an alluvial chart, a node of the
  first column in a parallel sets chart, and a source in a chord chart. An
  alluvial chart is a sankey with one node for each name in each column. The
  place of a name in its path sets its column. A parallel sets chart has the
  nodes of an alluvial chart. `Expresso.Element.Chart.ParallelSets` draws
  each of its categories as one ribbon through the columns. A chord chart
  takes the flows of a sankey. `Expresso.Element.Chart.Chord` draws its
  nodes as arcs of a ring.
  """

  use Expresso.Element

  import Expresso.Element.Chart.Kinds

  alias Expresso.Element.Chart.{Chord, Csv, Hierarchy, Motion, ParallelSets, Plot, Sankey, Table}
  alias Expresso.Element.{Flow, Focus, Frame, Series}
  alias Shoddy.Result

  @typedoc "The struct of a chart"
  @type t :: %__MODULE__{}

  # The colors of a palette for the series, so the most series of a chart.
  @colors 8

  # The box of the chart in the units of the SVG.
  @width 800
  @height 450

  defstruct [
              :class,
              :kind,
              :title,
              :category_label,
              :value_label,
              :categories,
              :src,
              :width,
              :frames,
              :levels,
              :delimiter,
              :highlight,
              separator: "/",
              values: true,
              reveal: false,
              dim: false,
              whole_first: false,
              frame_label: :top_right,
              sort: false,
              count: false,
              thumbnail: :first,
              elements: [],
              timeline: [],
              flows: [],
              focus: [],
              __spark_metadata__: nil
            ] ++ Expresso.Overlay.fields()

  @doc """
  Check the options of a chart

  The transform of the `chart` entity calls this function. A chart with `src`
  keeps its file until `Expresso.PathTransformer` runs, because the `root`
  option of the deck can change the path, and `build/1` then reads it.
  """
  @spec check(t()) :: {:ok, t()} | {:error, String.t()}
  def check(%__MODULE__{} = chart), do: with({:ok, chart} <- flows(chart), do: data(chart))

  # The flows and the nodes of a sankey. The flows of the chart and of its
  # frames become its categories and its series, and the `flows` field then
  # holds only the node entities.
  defp flows(%__MODULE__{flows: [_ | _] = items, kind: kind}) when not is_flow(kind) do
    if Enum.any?(items, &is_struct(&1, Flow)),
      do: {:error, "a flow is a link of a sankey, so a #{kind} chart takes no flow"},
      else:
        {:error,
         "a node entity changes a node of a sankey, so a #{kind} chart takes no node entity"}
  end

  defp flows(%__MODULE__{kind: kind, timeline: [%Frame{flows: [_ | _]} | _]})
       when not is_flow(kind),
       do: {:error, "a flow is a link of a sankey, so a #{kind} chart takes no flow"}

  defp flows(%__MODULE__{timeline: [%Frame{flows: [_ | _]} | _] = timeline} = chart) do
    cond do
      chart.categories != nil or chart.src != nil ->
        {:error, "a sankey with flows in its frames takes no categories and no src option"}

      Enum.any?(timeline, &(&1.flows == [] or &1.elements != [])) ->
        {:error, "each frame of a sankey with flows holds flows, and no series"}

      true ->
        pairs =
          timeline
          |> Enum.flat_map(& &1.flows)
          |> Enum.map(&[&1.from, &1.to])
          |> Enum.uniq()

        name = chart.value_label || "Value"
        timeline = Enum.map(timeline, &flow_frame(&1, pairs, name))
        flows(%__MODULE__{chart | categories: pairs, timeline: timeline})
    end
  end

  defp flows(%__MODULE__{flows: items} = chart) do
    case Enum.split_with(items, &is_struct(&1, Flow)) do
      {[], _nodes} ->
        {:ok, chart}

      {_flows, _nodes}
      when chart.src != nil or chart.categories != nil or chart.elements != [] or
             chart.timeline != [] ->
        {:error,
         "a sankey takes flow entities, or categories and a series, or the src option, " <>
           "and only one of them"}

      {flows, nodes} ->
        {:ok,
         %__MODULE__{
           chart
           | flows: nodes,
             categories: Enum.map(flows, fn %Flow{from: from, to: to} -> [from, to] end),
             elements: [
               %Series{name: chart.value_label || "Value", values: Enum.map(flows, & &1.value)}
             ]
         }}
    end
  end

  defp data(%__MODULE__{src: src} = chart) when is_binary(src) do
    if chart.categories != nil or chart.elements != [] or chart.timeline != [],
      do:
        {:error, "a chart takes the src option, or categories and series or frames, and not both"},
      else: with(:ok <- delimiter_option(chart.delimiter), do: options(chart))
  end

  defp data(%__MODULE__{frames: frames}) when is_binary(frames),
    do: {:error, "the frames option names a column of a CSV file, so it needs the src option"}

  defp data(%__MODULE__{delimiter: delimiter}) when is_binary(delimiter),
    do:
      {:error,
       "the delimiter option gives the character between two cells of a chart file, so it needs the src option"}

  defp data(%__MODULE__{levels: [_ | _], kind: kind})
       when not is_titled(kind),
       do:
         {:error,
          "the levels option names columns of a CSV file, so it needs the src option. " <>
            "Give a list of levels in the categories option, such as [\"Production\", \"Press\"]."}

  defp data(%__MODULE__{timeline: [_ | _], elements: [_ | _]}),
    do: {:error, "a chart with frames holds its series in each frame, and not in the chart"}

  defp data(%__MODULE__{} = chart), do: chart |> first_frame() |> validate()

  # A frame of a sankey with flows, with one series in place of its flows. The
  # series holds a value for each link of `pairs`, and 0 for a link that the
  # frame does not hold.
  defp flow_frame(%Frame{flows: flows} = frame, pairs, name) do
    sums =
      Enum.reduce(flows, %{}, fn flow, sums ->
        Map.update(sums, [flow.from, flow.to], flow.value, &(&1 + flow.value))
      end)

    values = Enum.map(pairs, &Map.get(sums, &1, 0))
    %Frame{frame | flows: [], elements: [%Series{name: name, values: values}]}
  end

  @doc """
  Read the CSV file of a chart with `src`, and make its categories and series

  The first row holds a heading for the categories, then the name of each
  series. Each other row holds a category, then one number for each series.
  A comma divides the cells, or a tab in a file that ends in `.tsv`, or the
  `delimiter` option. `Expresso.Element.Chart.Csv` tells the rules. The
  function reads the file through `Expresso.DeckFile`, so the watch mode
  renders the deck again after a change to the file.
  """
  @spec build(t()) :: {:ok, t()} | {:error, String.t()}
  def build(%__MODULE__{src: src, frames: nil} = chart) when is_binary(src) do
    with {:ok, text} <- read(src),
         {:ok, categories, series} <- Csv.table(text, src, reader(chart)) do
      validate(%__MODULE__{
        chart
        | categories: categories,
          elements: series,
          category_label: chart.category_label || Csv.heading(text, src, reader(chart))
      })
    end
  end

  def build(%__MODULE__{src: src} = chart) when is_binary(src) do
    with {:ok, text} <- read(src),
         {:ok, categories, timeline} <- Csv.frames(text, chart.frames, src, reader(chart)) do
      label = chart.category_label || Csv.heading(text, src, reader(chart), chart.frames)

      %__MODULE__{chart | categories: categories, timeline: timeline, category_label: label}
      |> first_frame()
      |> validate()
    end
  end

  def build(%__MODULE__{} = chart), do: {:ok, chart}

  defp delimiter_option(nil), do: :ok

  defp delimiter_option(delimiter) do
    if String.length(delimiter) == 1 and delimiter not in ["\"", "\n", "\r"],
      do: :ok,
      else: {:error, "the delimiter option is one character, and not a quote or a line break"}
  end

  defp reader(chart), do: [levels: chart.levels, delimiter: delimiter(chart)]

  # The delimiter option, else a tab for a file that ends in .tsv, else a
  # comma.
  defp delimiter(%__MODULE__{delimiter: delimiter}) when is_binary(delimiter), do: delimiter

  defp delimiter(%__MODULE__{src: src}),
    do: if(String.downcase(Path.extname(src)) == ".tsv", do: "\t", else: ",")

  defp read(src) do
    case Expresso.DeckFile.read(src) do
      {:ok, text} ->
        {:ok, text}

      {:error, reason} ->
        {:error, Expresso.DeckFile.read_error(src, "chart file", reason)}
    end
  end

  # The checks of a chart with its categories and its series.
  defp validate(%__MODULE__{} = chart) do
    with {:ok, chart} <- options(chart),
         :ok <- categories(chart),
         :ok <- series(chart),
         {:ok, chart} <- single(chart),
         {:ok, chart} <- later_frames(chart),
         do: focus(chart)
  end

  # A chart with frames shows the series of its first frame, so `reveal`,
  # `dim` and the overlay options of a series work as for a chart without
  # frames.
  defp first_frame(%__MODULE__{timeline: [%Frame{elements: elements} | _]} = chart),
    do: %__MODULE__{chart | elements: elements}

  defp first_frame(chart), do: chart

  defp options(%__MODULE__{kind: kind, reveal: true}) when is_single(kind),
    do: {:error, "a #{kind} has one series, so it takes no reveal option. Give it an at option."}

  defp options(%__MODULE__{kind: kind, levels: [_ | _]}) when not is_path(kind),
    do:
      {:error,
       "the levels option gives the groups of a treemap or a sunburst, or the paths of a sankey, " <>
         "so a #{kind} chart takes no levels option"}

  defp options(%__MODULE__{kind: kind, levels: [_]}) when is_flow(kind),
    do:
      {:error,
       "the levels option of a sankey names two columns or more, one for each node of a path"}

  defp options(%__MODULE__{kind: kind, reveal: true} = chart)
       when is_flow(kind) and (chart.frames != nil or chart.timeline != []),
       do:
         {:error,
          "a sankey with frames takes no reveal option, because each frame shows the whole chart"}

  defp options(%__MODULE__{kind: kind} = chart)
       when is_flow(kind) and (chart.effect == :grow or chart.count == true),
       do: {:error, "a sankey takes no effect :grow and no count option"}

  defp options(%__MODULE__{separator: ""}),
    do: {:error, "the separator option needs at least one character"}

  defp options(%__MODULE__{kind: kind, sort: true}) when kind != :bar,
    do:
      {:error,
       "the sort option puts the bars of a bar chart in order, so a #{kind} chart takes no sort option"}

  defp options(%__MODULE__{count: true, timeline: [], frames: nil}),
    do: {:error, "the count option counts from one frame to the next, so it needs frames"}

  defp options(%__MODULE__{thumbnail: thumbnail, timeline: [_ | _] = timeline})
       when is_integer(thumbnail) and thumbnail > length(timeline),
       do:
         {:error,
          "the thumbnail option names frame #{thumbnail}, and the chart has #{length(timeline)} frames"}

  defp options(chart), do: {:ok, chart}

  # The checks of each frame after the first. Each one holds the series of the
  # first frame, with the same names in the same order, and only the series
  # of the first frame take the overlay options and the class option.
  defp later_frames(%__MODULE__{timeline: [first | rest]} = chart) do
    names = Enum.map(first.elements, & &1.name)

    Enum.reduce_while(rest, {:ok, chart}, fn %Frame{} = frame, ok ->
      case frame(chart, frame, names) do
        :ok -> {:cont, ok}
        error -> {:halt, error}
      end
    end)
  end

  defp later_frames(chart), do: {:ok, chart}

  defp frame(%__MODULE__{} = chart, %Frame{label: label, elements: elements}, names) do
    cond do
      Enum.map(elements, & &1.name) != names ->
        {:error,
         "the frame \"#{label}\" needs the series #{Enum.map_join(names, ", ", &inspect/1)}, " <>
           "in the order of the first frame"}

      Enum.any?(elements, &(&1.at != nil or &1.on != [] or &1.class != nil)) ->
        {:error,
         "the frame \"#{label}\" gives a series an overlay option or a class. Give them to " <>
           "the series of the first frame."}

      true ->
        with :ok <- series(%__MODULE__{chart | elements: elements}),
             do: frame_single(%__MODULE__{chart | elements: elements})
    end
  end

  # `single/1` checks each frame of a chart of flows with the whole timeline,
  # so a later frame of such a chart needs no check of its own.
  defp frame_single(%__MODULE__{kind: kind}) when is_flow(kind), do: :ok
  defp frame_single(chart), do: with({:ok, _chart} <- single(chart), do: :ok)

  # The groups of the highlight option. Each item of the option is the name of
  # a series or a list of names, and it becomes one group with the
  # specification `:next`. The transformer then gives each group one step from
  # the counter of the slide, as it gives a step to a group of lines of a code
  # element.
  defp focus(%__MODULE__{highlight: nil, whole_first: true}),
    do: {:error, "the whole_first option of a chart needs the highlight option"}

  defp focus(%__MODULE__{highlight: nil} = chart), do: {:ok, chart}

  defp focus(%__MODULE__{highlight: highlight} = chart) do
    with :ok <- focus_options(chart),
         {:ok, groups} <- Result.collect(Enum.map(highlight, &focus_group(chart, &1))) do
      {:ok, %__MODULE__{chart | focus: groups}}
    end
  end

  defp focus_options(%__MODULE__{kind: kind}) when not is_axis(kind),
    do:
      {:error,
       "the highlight option puts series in focus, so a #{kind} chart takes no highlight option. " <>
         "A bar chart and a line chart take it."}

  defp focus_options(%__MODULE__{highlight: []}),
    do: {:error, "the highlight option needs one group or more"}

  defp focus_options(%__MODULE__{reveal: true}),
    do: {:error, "a chart takes the reveal option or the highlight option, and not both"}

  defp focus_options(%__MODULE__{dim: true}),
    do:
      {:error,
       "the highlight option dims the other series itself, so the chart takes no dim option"}

  defp focus_options(%__MODULE__{} = chart) when chart.timeline != [] or chart.frames != nil,
    do:
      {:error,
       "each frame of a chart takes a step, so a chart with frames takes no highlight option"}

  defp focus_options(%__MODULE__{elements: elements}) do
    if Enum.any?(elements, &(&1.at != nil or &1.on != [])),
      do:
        {:error,
         "the highlight option shows each series at each step, " <>
           "so a series of the chart takes no at option and no on entity"},
      else: :ok
  end

  defp focus_group(_chart, []),
    do: {:error, "a group of the highlight option needs one name or more"}

  defp focus_group(%__MODULE__{elements: elements}, item) do
    names = Enum.map(elements, & &1.name)
    {:ok, next} = Expresso.Overlay.new(:next)

    item
    |> List.wrap()
    |> Enum.map(fn name ->
      case Enum.find_index(names, &(&1 == name)) do
        nil ->
          {:error,
           "the highlight option names #{inspect(name)}, and the chart has no series with that name. " <>
             "The series are #{Enum.map_join(names, ", ", &inspect/1)}."}

        index ->
          {:ok, index + 1}
      end
    end)
    |> Result.collect()
    |> Result.map_ok(&%Focus{at: next, series: &1})
  end

  @doc """
  Return the number of steps that a chart takes before the groups of its
  `highlight` option

  The `whole_first` option gives the chart one step with no group in focus,
  as a `pause` in front of the chart does. `Expresso.Overlay.Expand` reads
  this number.
  """
  @spec lead(t()) :: 0 | 1
  def lead(%__MODULE__{whole_first: true}), do: 1
  def lead(%__MODULE__{}), do: 0

  defp categories(%__MODULE__{kind: kind, categories: [_ | _] = categories}) do
    cond do
      Enum.all?(categories, &is_binary/1) ->
        :ok

      not is_path(kind) ->
        {:error,
         "a category of a #{kind} chart is a string. A list of levels is for a treemap, a sunburst or a sankey."}

      Enum.all?(
        categories,
        &(is_binary(&1) or (is_list(&1) and Enum.all?(&1, fn level -> is_binary(level) end)))
      ) ->
        :ok

      true ->
        {:error, "a category is a string or a list of strings"}
    end
  end

  defp categories(_chart), do: {:error, "a chart needs the categories option or the src option"}

  defp series(%__MODULE__{elements: [], kind: kind}),
    do: {:error, "a chart #{inspect(kind)} needs a series"}

  defp series(%__MODULE__{elements: elements}) when length(elements) > @colors,
    do:
      {:error,
       "a chart has at most #{@colors} series, one for each color. Put the smallest into a series \"Other\"."}

  defp series(%__MODULE__{elements: elements, categories: categories}) do
    count = length(categories)

    case Enum.find(elements, &(not values?(&1.values, count))) do
      nil ->
        :ok

      %Series{name: name} ->
        {:error, "the series \"#{name}\" needs #{count} numbers, one for each category"}
    end
  end

  defp values?(values, count),
    do: is_list(values) and length(values) == count and Enum.all?(values, &is_number/1)

  # The checks of a chart of one series: a pie, a treemap or a sunburst.
  defp single(
         %__MODULE__{kind: kind, elements: [%Series{values: values}], categories: categories} =
           chart
       )
       when is_single(kind) do
    cond do
      Enum.any?(values, &(&1 < 0)) or Enum.sum(values) <= 0 ->
        {:error, "the values of a #{kind} are zero or more, and their sum is more than zero"}

      kind == :pie and length(categories) > @colors ->
        {:error,
         "a pie has at most #{@colors} parts, one for each color. Put the smallest into a part \"Other\"."}

      kind == :pie ->
        {:ok, chart}

      true ->
        with :ok <- Hierarchy.check(categories, chart.separator), do: {:ok, chart}
    end
  end

  defp single(%__MODULE__{kind: kind}) when is_single(kind),
    do: {:error, "a #{kind} has one series"}

  defp single(%__MODULE__{kind: kind, elements: [%Series{effect: :grow}]}) when is_flow(kind),
    do: {:error, "a sankey takes no effect :grow and no count option"}

  defp single(%__MODULE__{kind: :parallel_sets, timeline: [_ | _] = timeline} = chart) do
    with {:ok, series} <- frame_series(timeline),
         :ok <-
           each_frame(series, &Sankey.check(chart.categories, &1.values, chart.separator, true)),
         :ok <- ParallelSets.check(chart.categories, chart.separator),
         sums =
           Enum.map(series, &ParallelSets.paths(chart.categories, &1.values, chart.separator)),
         paths = sums |> hd() |> elem(0),
         links = path_links(paths),
         :ok <- nodes_check(chart, links),
         :ok <- titles_check(chart, links) do
      timeline =
        for {%Frame{} = frame, {%Series{} = one, {_paths, values}}} <-
              Enum.zip(timeline, Enum.zip(series, sums)),
            do: %Frame{frame | elements: [%Series{one | values: values}]}

      {:ok,
       %__MODULE__{chart | categories: paths, timeline: timeline, elements: hd(timeline).elements}}
    end
  end

  defp single(%__MODULE__{kind: :parallel_sets, elements: [%Series{} = series]} = chart) do
    with :ok <- Sankey.check(chart.categories, series.values, chart.separator, true),
         :ok <- ParallelSets.check(chart.categories, chart.separator),
         {paths, values} = ParallelSets.paths(chart.categories, series.values, chart.separator),
         links = path_links(paths),
         :ok <- nodes_check(chart, links),
         :ok <- titles_check(chart, links) do
      elements =
        if chart.reveal,
          do: first_stages(paths, values, series),
          else: [%Series{series | values: values}]

      {:ok, %__MODULE__{chart | categories: paths, elements: elements}}
    end
  end

  defp single(%__MODULE__{kind: kind, timeline: [_ | _] = timeline} = chart)
       when is_flow(kind) do
    alluvial = kind == :alluvial

    with {:ok, series} <- frame_series(timeline),
         :ok <-
           each_frame(
             series,
             &Sankey.check(chart.categories, &1.values, chart.separator, alluvial)
           ),
         frames =
           Enum.map(
             series,
             &Sankey.links(chart.categories, &1.values, chart.separator, alluvial)
           ),
         :ok <- nodes_check(chart, List.flatten(frames)),
         :ok <- titles_check(chart, List.flatten(frames)) do
      pairs = frames |> List.flatten() |> Enum.map(&[&1.from, &1.to]) |> Enum.uniq()

      timeline =
        for {%Frame{} = frame, {links, %Series{} = one}} <-
              Enum.zip(timeline, Enum.zip(frames, series)) do
          sums = Map.new(links, &{[&1.from, &1.to], &1.value})

          %Frame{
            frame
            | elements: [%Series{one | values: Enum.map(pairs, &Map.get(sums, &1, 0))}]
          }
        end

      {:ok,
       %__MODULE__{
         chart
         | categories: pairs,
           timeline: timeline,
           elements: hd(timeline).elements
       }}
    end
  end

  defp single(%__MODULE__{kind: kind, elements: [%Series{} = series]} = chart)
       when is_flow(kind) do
    alluvial = kind == :alluvial

    with :ok <- Sankey.check(chart.categories, series.values, chart.separator, alluvial),
         links = Sankey.links(chart.categories, series.values, chart.separator, alluvial),
         :ok <- nodes_check(chart, links),
         :ok <- titles_check(chart, links) do
      categories = Enum.map(links, &[&1.from, &1.to])
      values = Enum.map(links, & &1.value)

      elements =
        if chart.reveal,
          do: stages(links, series, kind),
          else: [%Series{series | values: values}]

      {:ok, %__MODULE__{chart | categories: categories, elements: elements}}
    end
  end

  defp single(%__MODULE__{kind: kind}) when is_flow(kind),
    do: {:error, "a sankey has one series"}

  defp single(%__MODULE__{kind: kind} = chart) when is_axis(kind), do: {:ok, chart}

  # The node entities of a sankey: one for each node at most, and each for a
  # node of the flows.
  defp nodes_check(%__MODULE__{flows: []}, _links), do: :ok

  defp nodes_check(%__MODULE__{flows: nodes} = chart, links) do
    names = links |> Enum.flat_map(&[Sankey.name(&1.from), Sankey.name(&1.to)]) |> MapSet.new()
    given = Enum.map(nodes, & &1.name)
    twice = given -- Enum.uniq(given)

    cond do
      twice != [] ->
        {:error, "the node \"#{hd(twice)}\" has two node entities, and a node has one"}

      unknown = Enum.find(given, &(not MapSet.member?(names, &1))) ->
        {:error, "the node entity \"#{unknown}\" names no node of the flows"}

      chart.kind != :sankey and Enum.any?(nodes, &(&1.column != nil)) ->
        {:error,
         "only a sankey takes the column option of a node entity, " <>
           "so a node entity of #{named(chart.kind)} takes no column option"}

      true ->
        :ok
    end
  end

  defp named(:alluvial), do: "an alluvial chart"
  defp named(:parallel_sets), do: "a parallel sets chart"
  defp named(kind), do: "a #{kind} chart"

  # The levels of an alluvial chart give a title to each column.
  defp titles_check(%__MODULE__{kind: kind, levels: [_ | _] = levels}, links)
       when is_titled(kind) do
    count = links |> Enum.map(&(elem(&1.to, 0) + 1)) |> Enum.max()

    if length(levels) == count,
      do: :ok,
      else:
        {:error,
         "the levels option of #{named(kind)} " <>
           "gives a title for each column, " <>
           "so give #{count} titles"}
  end

  defp titles_check(_chart, _links), do: :ok

  # The links between the neighbors of each path.
  defp path_links(paths) do
    for path <- paths,
        [from, to] <- Enum.chunk_every(path, 2, 1, :discard),
        do: %{from: from, to: to}
  end

  # The series of a parallel sets chart with reveal: one series for each
  # name in the first column, with the value of each path that starts there.
  defp first_stages(paths, values, %Series{} = series) do
    firsts = paths |> Enum.map(&hd/1) |> Enum.uniq()

    for {_column, name} = first <- firsts do
      values = Enum.zip_with(paths, values, &if(hd(&1) == first, do: &2, else: 0))
      %Series{name: name, values: values, class: series.class}
    end
  end

  # The one series of each frame of a sankey.
  defp frame_series(timeline) do
    if Enum.all?(timeline, &match?(%Frame{elements: [%Series{}]}, &1)),
      do: {:ok, Enum.map(timeline, &hd(&1.elements))},
      else: {:error, "a sankey has one series in each frame"}
  end

  defp each_frame(series, check) do
    Enum.find_value(series, :ok, fn one ->
      case check.(one) do
        :ok -> nil
        error -> error
      end
    end)
  end

  # The series of a chord chart with reveal: one series for each source. Each
  # series holds the values of the links from its source, and zero for each
  # other link.
  defp stages(links, %Series{} = series, :chord) do
    for source <- links |> Enum.map(& &1.from) |> Enum.uniq() do
      values = Enum.map(links, &if(&1.from == source, do: &1.value, else: 0))
      %Series{name: source, values: values, class: series.class}
    end
  end

  defp stages(links, series, _kind), do: stages(links, series)

  # The series of a sankey with reveal: one series for each source column.
  # Each series holds the values of the links that start in its column, and
  # zero for each other link.
  defp stages(links, %Series{} = series) do
    columns = Sankey.columns(links)
    stages = links |> Enum.map(&columns[&1.from]) |> Enum.uniq() |> Enum.sort()

    for {stage, index} <- Enum.with_index(stages, 1) do
      values = Enum.map(links, &if(columns[&1.from] == stage, do: &1.value, else: 0))
      %Series{name: "#{series.name} #{index}", values: values, class: series.class}
    end
  end

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, and the
  `style` attribute of the `width` option. The key `series` holds each series
  with its color number and its overlay attributes. A series of a chart with
  the `highlight` option also gets `data-series` with its color number, and
  the rules of `rules/1` select it by that number.
  """
  @spec get_assigns(t()) :: map()
  @impl Expresso.Element
  def get_assigns(%__MODULE__{} = chart) do
    series =
      chart.elements
      |> Enum.with_index(1)
      |> Enum.map(fn {series, color} ->
        %{
          name: series.name,
          values: series.values,
          color: color,
          class: series.class,
          overlay: Expresso.Overlay.Render.attributes(series) ++ series_key(chart, color)
        }
      end)

    width =
      if chart.width,
        do: [{"style", "--chart-width: #{Expresso.Element.viewport_unit(chart.width)}"}],
        else: []

    %{
      kind: chart.kind,
      title: chart.title,
      category_label: chart.category_label,
      value_label: chart.value_label,
      categories: chart.categories,
      series: series,
      values: chart.values,
      frames: frame_values(chart),
      moves: moves?(chart),
      el: chart.el,
      count: chart.count,
      sort: chart.sort,
      frame_label: chart.frame_label,
      separator: chart.separator,
      levels: chart.levels,
      thumbnail: chart.thumbnail,
      node_settings: Map.new(chart.flows, &{&1.name, &1}),
      overlay: Expresso.Overlay.Render.attributes(chart) ++ width
    }
  end

  defp series_key(%__MODULE__{focus: []}, _color), do: []
  defp series_key(%__MODULE__{}, color), do: [{"data-series", Integer.to_string(color)}]

  # The values of each frame, as a list of the values of each series. A chart
  # without frames has one frame.
  defp frame_values(%__MODULE__{timeline: [_ | _] = timeline}) do
    for %Frame{label: label, elements: elements} <- timeline,
        do: %{label: label, values: Enum.map(elements, & &1.values)}
  end

  defp frame_values(%__MODULE__{elements: elements}),
    do: [%{label: nil, values: Enum.map(elements, & &1.values)}]

  @doc """
  Tell whether the marks of a chart move

  The marks move in a chart with two or more frames, and in a chart with the
  effect `:grow` on the chart or on a series. `Expresso.Element.Chart.Motion`
  then draws them.
  """
  @spec moves?(t()) :: boolean()
  def moves?(%__MODULE__{timeline: [_, _ | _]}), do: true

  def moves?(%__MODULE__{effect: effect, elements: elements}),
    do: effect == :grow or Enum.any?(elements, &(&1.effect == :grow))

  @doc """
  Return the CSS rules of the frames and of the `highlight` option of a chart

  `Expresso.Overlay.Render.style/1` calls this function for each chart, after
  `Expresso.Overlay.Render.identify/1`. A chart without frames and without
  the `highlight` option has no rules.

  A group of the `highlight` option gives one rule at its step. The rule sets
  `--chart-dim: 1` on each series that is not in the group, and the theme
  dims a series with that property.
  """
  @spec rules(t()) :: [String.t()]
  def rules(%__MODULE__{} = chart), do: frame_rules(chart) ++ focus_rules(chart)

  defp frame_rules(%__MODULE__{timeline: [_, _ | _] = timeline, el: el} = chart)
       when is_binary(el) do
    assigns = chart |> get_assigns() |> layout()
    Motion.rules(assigns, el, timeline |> tl() |> Enum.map(&(&1.steps || [])))
  end

  defp frame_rules(%__MODULE__{}), do: []

  defp focus_rules(%__MODULE__{focus: focus, el: el}) when is_binary(el) do
    for %Focus{steps: steps, series: series} <- focus, step <- steps || [] do
      others = Enum.map_join(series, &":not([data-series=\"#{&1}\"])")

      "section[data-step=\"#{step}\"] [data-el=\"#{el}\"] [data-series]#{others} " <>
        "{ --chart-dim: 1; }"
    end
  end

  defp focus_rules(%__MODULE__{}), do: []

  @doc """
  Make the HTML of a chart: a `figure` with the SVG and a table of the values

  The SVG has `role="img"` and the title as its name. The table has the class
  `chart-table`, and the style sheet hides it from the eye and not from a
  screen reader.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  @impl Expresso.Element
  def render(assigns) do
    assigns = assigns |> Map.put(:view_box, "0 0 #{@width} #{@height}") |> layout()

    temple do
      figure class: Expresso.Element.classes("chart #{kind_class(@kind)}", assigns[:class]),
             rest!: @overlay do
        svg viewBox: @view_box, role: "img", aria_label: @title do
          c(&plot/1, rest!: assigns)
        end

        if length(@frames) > 1 do
          div class: "chart-frames", aria_hidden: "true" do
            for frame <- @frames do
              figure class: "chart-copy" do
                svg viewBox: @view_box do
                  c(&plot/1, rest!: copy(assigns, frame))
                end

                figcaption do
                  frame.label
                end
              end
            end
          end
        end

        c(&Table.render/1, rest!: table(assigns))
      end
    end
  end

  # The class of the kind, with a hyphen in place of an underscore.
  defp kind_class(kind), do: "chart-" <> String.replace(Atom.to_string(kind), "_", "-")

  # A chart of one frame that does not move, for paper and for the handout
  # view. It has the axis of the chart with each frame.
  defp copy(assigns, frame) do
    series =
      for {series, values} <- Enum.zip(assigns.series, frame.values),
          do: %{series | values: values}

    %{assigns | series: series, moves: false, frames: [frame]}
  end

  # The caption, the headers and the rows of the table of a chart, for a
  # screen reader.
  defp table(assigns) do
    assigns
    |> rows()
    |> Map.put(:caption, Table.caption(assigns.title, assigns.value_label))
  end

  defp rows(%{kind: :parallel_sets} = assigns), do: ParallelSets.table(assigns)
  defp rows(%{kind: kind} = assigns) when is_flow(kind), do: Sankey.table(assigns)

  # The table of a chart with an axis, a pie, a treemap or a sunburst holds
  # one column for each series in each frame. The corner names the
  # categories, and a chart without a name for them has no header there.
  defp rows(%{kind: kind} = assigns) when is_axis(kind) or is_single(kind) do
    columns =
      for frame <- assigns.frames, {series, s} <- Enum.with_index(assigns.series) do
        name =
          case {frame.label, assigns.series} do
            {nil, _series} -> series.name
            {label, [_one]} -> label
            {label, _series} -> "#{series.name} #{label}"
          end

        {name, Enum.at(frame.values, s)}
      end

    rows =
      for {category, index} <- Enum.with_index(assigns.categories) do
        name = if is_list(category), do: Enum.join(category, " / "), else: category
        [name | Enum.map(columns, fn {_name, values} -> Plot.label(Enum.at(values, index)) end)]
      end

    %{headers: [assigns.category_label | Enum.map(columns, &elem(&1, 0))], rows: rows}
  end

  # The kinds of a chart. Each one writes the content of the SVG.
  defp plot(%{kind: :parallel_sets} = assigns), do: ParallelSets.render(assigns)
  defp plot(%{kind: :chord} = assigns), do: Chord.render(assigns)
  defp plot(%{kind: kind} = assigns) when is_flow(kind), do: Sankey.render(assigns)

  defp plot(%{kind: kind} = assigns) when is_part(kind), do: Motion.render(assigns)

  defp plot(%{kind: :pie, moves: true} = assigns), do: Motion.render(assigns)
  defp plot(%{kind: :pie} = assigns), do: pie_plot(assigns)
  defp plot(%{kind: kind} = assigns) when is_axis(kind), do: axis_plot(assigns)

  # The axis of a chart with each value of each frame, the box of the plot,
  # the function from a value to its coordinate, and the legend. A pie has no
  # axis.
  defp layout(%{kind: :pie} = assigns), do: assigns
  defp layout(%{kind: :sunburst} = assigns), do: assigns

  # A sankey fills the SVG. The label of the frame takes a row at the top.
  # An alluvial chart with `levels` has a row for the column titles under it.
  defp layout(%{kind: kind} = assigns) when is_flow(kind) do
    rows = Enum.count([label?(assigns), Sankey.titles?(assigns)], & &1)
    top = 8 + 44 * rows
    Map.put(assigns, :box, %{left: 4, right: @width - 4, top: top, bottom: @height - 8})
  end

  # A treemap fills the SVG. The label of the frame takes a row at the top.
  defp layout(%{kind: :treemap} = assigns) do
    top = if label?(assigns), do: 52, else: 4
    Map.put(assigns, :box, %{left: 4, right: @width - 4, top: top, bottom: @height - 4})
  end

  defp layout(%{kind: kind} = assigns) when is_axis(kind) do
    ticks = assigns.frames |> Enum.flat_map(& &1.values) |> List.flatten() |> Plot.ticks()
    box = box(assigns, ticks)
    low = List.first(ticks)
    high = List.last(ticks)
    y = fn value -> box.bottom - (value - low) / (high - low) * (box.bottom - box.top) end

    assigns =
      Map.merge(assigns, %{
        ticks: ticks,
        box: box,
        y: y,
        legend: legend(assigns.series, legend_left(assigns, box)),
        legend_item: &legend_item/1
      })

    Map.put(assigns, :category_x, &category_x(assigns, &1))
  end

  # The box of the plot inside the SVG: the left edge holds the labels of the
  # axis, the top edge holds the legend, and the right edge of a line chart
  # holds the names at the ends of the lines.
  defp box(assigns, ticks) do
    widest = ticks |> Enum.map(&String.length(Plot.label(&1))) |> Enum.max()
    left = 24 + widest * 10 + if(assigns[:value_label], do: 32, else: 0)
    top = if length(assigns.series) > 1 or label?(assigns), do: 64, else: 28
    right = if assigns.kind == :line, do: @width - 150, else: @width - 16
    bottom = @height - 40 - if(assigns[:category_label], do: 30, else: 0)
    %{left: left, top: top, right: right, bottom: bottom}
  end

  defp axis_plot(assigns) do
    temple do
      g class: "chart-axis" do
        for tick <- @ticks do
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

        # The bars of a chart that moves draw their own categories, because
        # the `sort` option moves them.
        if not (@moves and @kind == :bar) do
          for {category, index} <- Enum.with_index(@categories) do
            text x: Plot.f(@category_x.(index)),
                 y: @box.bottom + 28,
                 text_anchor: "middle",
                 class: "chart-category" do
              category
            end
          end
        end
      end

      c(&axis_titles/1, rest!: assigns)

      cond do
        @moves -> Motion.render(assigns)
        @kind == :bar -> c(&bars/1, rest!: assigns)
        true -> c(&lines/1, rest!: assigns)
      end
    end
  end

  # The name of the categories under their axis, and the name of the values
  # beside their axis, turned to read from the bottom up.
  defp axis_titles(assigns) do
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

  # The center of a category on the axis. A bar chart gives each category a
  # band of the same width, and a line chart puts the first and the last
  # category on the edges of the plot.
  defp category_x(%{kind: :bar, box: box, categories: categories}, index) do
    band = (box.right - box.left) / length(categories)
    box.left + band * (index + 0.5)
  end

  defp category_x(%{box: box, categories: [_one]}, _index),
    do: (box.left + box.right) / 2

  defp category_x(%{box: box, categories: categories}, index) do
    inset = 24
    box.left + inset + (box.right - box.left - 2 * inset) * index / (length(categories) - 1)
  end

  defp bars(assigns) do
    band = (assigns.box.right - assigns.box.left) / length(assigns.categories)
    group = band * 0.7
    slot = group / length(assigns.series)
    assigns = Map.merge(assigns, %{band: band, slot: slot, group: group})

    temple do
      for series <- @series do
        g class: Expresso.Element.classes("chart-series chart-c#{series.color}", series.class),
          rest!: series.overlay do
          c(&legend_item/1, legend: @legend, series: series)

          for {value, index} <- Enum.with_index(series.values) do
            c(&bar/1, rest!: Map.merge(assigns, %{series: series, value: value, index: index}))
          end
        end
      end
    end
  end

  # One bar and its value. The bars of a category stand side by side, with a
  # gap of 2 units, in the order of the series.
  defp bar(assigns) do
    x =
      category_x(assigns, assigns.index) - assigns.group / 2 +
        (assigns.series.color - 1) * assigns.slot + 1

    width = max(assigns.slot - 2, 1)

    label_y =
      if assigns.value >= 0,
        do: assigns.y.(assigns.value) - 8,
        else: assigns.y.(assigns.value) + 20

    assigns = Map.merge(assigns, %{x: x, bar_width: width, label_y: label_y})

    temple do
      path class: "chart-bar", d: Plot.bar(@x, @bar_width, @y.(0), @y.(@value))

      if @values do
        text x: Plot.f(@x + @bar_width / 2),
             y: Plot.f(@label_y),
             text_anchor: "middle",
             class: "chart-value" do
          Plot.label(@value)
        end
      end
    end
  end

  defp lines(assigns) do
    ends =
      assigns.series
      |> Enum.map(&assigns.y.(List.last(&1.values)))
      |> Plot.spread(22)

    assigns = Map.put(assigns, :ends, ends)

    temple do
      for {series, end_y} <- Enum.zip(@series, @ends) do
        g class: Expresso.Element.classes("chart-series chart-c#{series.color}", series.class),
          rest!: series.overlay do
          c(&legend_item/1, legend: @legend, series: series)

          polyline class: "chart-line",
                   points:
                     series.values
                     |> Enum.with_index()
                     |> Enum.map_join(" ", fn {value, index} ->
                       "#{Plot.f(category_x(assigns, index))},#{Plot.f(@y.(value))}"
                     end)

          for {value, index} <- Enum.with_index(series.values) do
            circle class: "chart-dot",
                   cx: Plot.f(category_x(assigns, index)),
                   cy: Plot.f(@y.(value)),
                   r: 5
          end

          text x: Plot.f(category_x(assigns, length(@categories) - 1) + 14),
               y: Plot.f(end_y + 5),
               class: "chart-end" do
            "#{series.name} #{Plot.label(List.last(series.values))}"
          end
        end
      end
    end
  end

  # The legend of two or more series: a row of colors and names above the
  # plot, with the left edge of each item. A chart of one series has no
  # legend, because the title names it. Each item goes into the group of its
  # series, so it shows and dims with the series.
  defp legend([_one], _left), do: %{}

  defp legend(series, left) do
    series
    |> Enum.map_reduce(left, fn series, x ->
      {{series.color, x}, x + 44 + String.length(series.name) * 11}
    end)
    |> elem(0)
    |> Map.new()
  end

  # The label of the frame goes into the row of the legend, at the right or at
  # the left. At the left, the legend starts after the longest label.
  defp label?(%{frames: [_, _ | _], frame_label: place}), do: place != :none
  defp label?(_assigns), do: false

  defp legend_left(%{frame_label: :top_left} = assigns, box) do
    if label?(assigns) do
      widest = assigns.frames |> Enum.map(&String.length(&1.label)) |> Enum.max()
      box.left + widest * 20 + 24
    else
      box.left
    end
  end

  defp legend_left(_assigns, box), do: box.left

  defp legend_item(assigns) do
    temple do
      if x = @legend[@series.color] do
        rect class: "chart-swatch", x: x, y: 14, width: 16, height: 16, rx: 3

        text x: x + 24, y: 28, class: "chart-name" do
          @series.name
        end
      end
    end
  end

  # A pie: one slice for each category, from the top and clockwise, and a
  # legend at the right with the name and the part in percent of each one.
  defp pie_plot(assigns) do
    [series] = assigns.series
    total = Enum.sum(series.values)

    turns =
      series.values
      |> Enum.map_reduce(0, fn value, from ->
        {{from, from + value / total}, from + value / total}
      end)
      |> elem(0)

    radius = 180
    cx = 40 + radius
    cy = @height / 2
    top = cy - length(assigns.categories) * 36 / 2

    assigns =
      Map.merge(assigns, %{
        series: series,
        total: total,
        turns: turns,
        radius: radius,
        cx: cx,
        cy: cy,
        top: top
      })

    temple do
      g class: Expresso.Element.classes("chart-series", @series.class), rest!: @series.overlay do
        for {{from, to}, index} <- Enum.with_index(@turns), to > from do
          path class: "chart-slice chart-c#{index + 1}",
               d: Plot.slice(@cx, @cy, @radius, from, to)
        end

        for {{category, value}, index} <-
              Enum.with_index(Enum.zip(@categories, @series.values)) do
          rect class: "chart-swatch chart-c#{index + 1}",
               x: @cx + @radius + 60,
               y: Plot.f(@top + index * 36 + 4),
               width: 16,
               height: 16,
               rx: 3

          text x: @cx + @radius + 88, y: Plot.f(@top + index * 36 + 18), class: "chart-name" do
            "#{category} #{Plot.label(Float.round(value / @total * 100, 1))}%"
          end
        end
      end
    end
  end
end
