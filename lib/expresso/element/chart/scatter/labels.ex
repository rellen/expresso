defmodule Expresso.Element.Chart.Scatter.Labels do
  @moduledoc """
  The places of the labels of the points of a scatter plot

  A label goes next to its mark. The function `place/2` tries eight places in
  order: right, left, above, below, and the four corners. It takes the first
  place where the label covers no other label and no other mark, and stays
  inside the box of the plot. When no place is free, the label takes the
  place that covers the least area of the other labels, then of the marks.

  The labels go in the order of the points, so an earlier point gets the
  better place. The width of a label is an estimate from its number of
  characters, because the compiler does not measure text.
  """

  # The height of a label, the width of a character, and the gap between a
  # mark and its label, in the units of the SVG.
  @height 17
  @char 9
  @gap 4

  @typedoc "A place of a label: the offset of its baseline from the mark, and its anchor"
  @type place :: %{dx: number(), dy: number(), anchor: String.t()}

  @doc """
  Return the place of the label of each point, by the number of the point

  Each point has `index`, `name`, `x`, `y` and `r`, in the units of the SVG.
  `labeled` holds the numbers of the points with a label.

      iex> points = [%{index: 1, name: "api", x: 100, y: 100, r: 6}, %{index: 2, name: "web", x: 140, y: 100, r: 6}]
      iex> box = %{left: 0, right: 400, top: 0, bottom: 300}
      iex> places = Expresso.Element.Chart.Scatter.Labels.place(points, box)
      iex> {places[1].anchor, places[2].anchor}
      {"end", "start"}
  """
  @spec place([map()], map()) :: %{pos_integer() => place()}
  def place(points, box) do
    marks = Enum.map(points, &{&1.index, mark_box(&1)})

    {places, _boxes} =
      Enum.map_reduce(points, [], fn point, placed ->
        others = for {index, mark} <- marks, index != point.index, do: mark

        {place, area} =
          point
          |> candidates()
          |> Enum.map(&{&1, label_box(point, &1)})
          |> Enum.min_by(fn {_place, area} -> cost(area, placed, others, box) end)

        {{point.index, place}, [area | placed]}
      end)

    Map.new(places)
  end

  # The cost of a place: a place outside the box costs the most, then the
  # area that it covers of the labels, then of the marks. `Enum.min_by/2`
  # keeps the first of two places with the same cost.
  defp cost(area, placed, marks, box) do
    outside = if inside?(area, box), do: 0, else: 1
    {outside, covered(area, placed), covered(area, marks)}
  end

  defp candidates(%{r: r}) do
    g = r + @gap
    c = g * 0.7

    [
      %{dx: g, dy: 6, anchor: "start"},
      %{dx: -g, dy: 6, anchor: "end"},
      %{dx: 0, dy: -g - 4, anchor: "middle"},
      %{dx: 0, dy: g + 13, anchor: "middle"},
      %{dx: c, dy: -c - 2, anchor: "start"},
      %{dx: c, dy: c + 11, anchor: "start"},
      %{dx: -c, dy: -c - 2, anchor: "end"},
      %{dx: -c, dy: c + 11, anchor: "end"}
    ]
  end

  defp mark_box(%{x: x, y: y, r: r}), do: {x - r, y - r, x + r, y + r}

  # The box of a label at a place: from its anchor, and from its baseline to
  # the top of its letters.
  defp label_box(%{x: x, y: y, name: name}, %{dx: dx, dy: dy, anchor: anchor}) do
    width = String.length(name) * @char
    base = y + dy

    left =
      case anchor do
        "start" -> x + dx
        "end" -> x + dx - width
        "middle" -> x + dx - width / 2
      end

    {left, base - @height + 4, left + width, base + 4}
  end

  defp inside?({left, top, right, bottom}, box),
    do: left >= box.left and right <= box.right and top >= box.top and bottom <= box.bottom

  defp covered(area, boxes), do: boxes |> Enum.map(&overlap(area, &1)) |> Enum.sum()

  defp overlap({l1, t1, r1, b1}, {l2, t2, r2, b2}),
    do: max(0, min(r1, r2) - max(l1, l2)) * max(0, min(b1, b2) - max(t1, t2))
end
