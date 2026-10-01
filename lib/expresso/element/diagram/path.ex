defmodule Expresso.Element.Diagram.Path do
  @moduledoc """
  The points of the `d` attribute of an SVG path

  `points/1` returns each end point and each control point of the path, in
  absolute coordinates. `Expresso.Element.Diagram.Geometry` makes the box of
  the path from them. The function reads each command of SVG 1.1, in its
  absolute form and in its relative form. An arc gives its end point only.
  """

  alias Expresso.Element.Diagram.Geometry

  # The number of values of each command.
  @arity %{
    "M" => 2,
    "L" => 2,
    "H" => 1,
    "V" => 1,
    "C" => 6,
    "S" => 4,
    "Q" => 4,
    "T" => 2,
    "A" => 7,
    "Z" => 0
  }

  @doc """
  Return the absolute points of a path

      iex> Expresso.Element.Diagram.Path.points("M 10 10 h 20 v 5 l -5 5 z")
      [{10.0, 10.0}, {30.0, 10.0}, {30.0, 15.0}, {25.0, 20.0}]
  """
  @spec points(String.t()) :: [{float(), float()}]
  def points(d) do
    ~r/([MmLlHhVvCcSsQqTtAaZz])([^MmLlHhVvCcSsQqTtAaZz]*)/
    |> Regex.scan(d)
    |> Enum.reduce({[], {0.0, 0.0}, {0.0, 0.0}}, fn [_all, command, args], state ->
      run(command, Geometry.numbers(args), state)
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  # The state: the points so far, the current point, and the start of the
  # subpath for `Z`.
  defp run(command, args, {points, current, start}) do
    upper = String.upcase(command)
    relative = command != upper

    case Map.fetch!(@arity, upper) do
      0 ->
        {points, start, start}

      arity ->
        args
        |> Enum.chunk_every(arity, arity, :discard)
        |> Enum.with_index()
        |> Enum.reduce({points, current, start}, &step(upper, relative, &1, &2))
    end
  end

  # One set of values of a command. The pairs after the first pair of a move
  # are lines.
  defp step(upper, relative, {values, index}, {points, current, start}) do
    kind = if upper == "M" and index > 0, do: "L", else: upper
    new = segment(kind, values, current, relative)
    last = List.last(new)
    start = if kind == "M", do: last, else: start
    {Enum.reverse(new) ++ points, last, start}
  end

  defp segment("H", [x], {cx, cy}, relative), do: [{if(relative, do: cx + x, else: x), cy}]
  defp segment("V", [y], {cx, cy}, relative), do: [{cx, if(relative, do: cy + y, else: y)}]

  defp segment("A", [_rx, _ry, _rotation, _large, _sweep, x, y], current, relative),
    do: [absolute({x, y}, current, relative)]

  defp segment(_kind, values, current, relative) do
    values
    |> Enum.chunk_every(2)
    |> Enum.map(fn [x, y] -> absolute({x, y}, current, relative) end)
  end

  defp absolute(point, _current, false), do: point
  defp absolute({x, y}, {cx, cy}, true), do: {cx + x, cy + y}
end
