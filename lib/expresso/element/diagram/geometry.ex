defmodule Expresso.Element.Diagram.Geometry do
  @moduledoc """
  The box and the center of an element of an SVG file

  The `move_to` option of an `on` entity in a part moves the part to the
  center of a different element of the file. This module finds the two
  centers from the tree of the file, with no browser. The render of the deck
  then writes the distance as `--x` and `--y`, as for `set: [x: ..., y: ...]`.

  The box of an element is the smallest rectangle that holds its shape, in
  the coordinates of the `svg` element of the file. The module reads the
  `transform` attribute of the element and of each parent, so an element in a
  moved group gets the correct box. These shapes have a box:

  | Element | Box |
  | --- | --- |
  | `rect`, `image`, `use`, `foreignObject` | `x`, `y`, `width` and `height` |
  | `circle` | `cx`, `cy` and `r` |
  | `ellipse` | `cx`, `cy`, `rx` and `ry` |
  | `line` | the two points |
  | `polyline`, `polygon` | each point of `points` |
  | `path` | each end point and each control point of `d` |
  | `text`, `tspan` | the point of `x` and `y` |
  | `g`, `a`, `svg`, `switch` | the box of each child |

  The box of a path holds its control points, so a curve can have a box that
  is a little larger than its shape. A text has no width without its font, so
  its box is the point where the text starts. A text with `text-anchor:
  middle` thus has the correct horizontal center.
  """

  # The elements that draw nothing.
  @no_shape ~w(defs title desc style script clippath mask marker lineargradient
               radialgradient pattern symbol filter metadata)

  @typedoc "An affine transform: x' = a·x + c·y + e, y' = b·x + d·y + f"
  @type matrix :: {float(), float(), float(), float(), float(), float()}

  @typedoc "A box: left, top, right, bottom"
  @type box :: {float(), float(), float(), float()}

  @identity {1.0, 0.0, 0.0, 1.0, 0.0, 0.0}

  @doc """
  Return the distance from the center of one element to the center of another

  `tree` is the tree of the file from `Floki.parse_fragment!/1`. The distance
  is in the coordinates of the parent of the element `from`, because a part
  moves in the coordinates of its parent. The function returns an error for
  an id that the file does not have, and for an element with no shape.

      iex> tree = Floki.parse_fragment!(~s{<svg><rect id="a" x="0" y="0" width="10" height="10"/><g transform="translate(100, 20)"><circle id="b" cx="5" cy="5" r="5"/></g></svg>})
      iex> Expresso.Element.Diagram.Geometry.distance(tree, "a", "b")
      {:ok, {100.0, 20.0}}
  """
  @spec distance(Floki.html_tree(), String.t(), String.t()) ::
          {:ok, {float(), float()}} | {:error, String.t()}
  def distance(tree, from, to) do
    with {:ok, {from_center, parent}} <- center(tree, from),
         {:ok, {to_center, _parent}} <- center(tree, to) do
      {dx, dy} =
        {elem(to_center, 0) - elem(from_center, 0), elem(to_center, 1) - elem(from_center, 1)}

      {:ok, unscale(parent, {dx, dy})}
    end
  end

  # The center of an element in the coordinates of the file, and the matrix of
  # its parent.
  defp center(tree, id) do
    case find(tree, id, @identity) do
      nil ->
        {:error, "has no element with the id \"#{id}\""}

      {node, parent} ->
        case box(node, parent) do
          nil -> {:error, "has no shape to measure in the element with the id \"#{id}\""}
          {left, top, right, bottom} -> {:ok, {{(left + right) / 2, (top + bottom) / 2}, parent}}
        end
    end
  end

  # The element with an id, and the matrix of its parent: the product of the
  # transforms of each parent.
  defp find(nodes, id, matrix) when is_list(nodes) do
    Enum.find_value(nodes, &find(&1, id, matrix))
  end

  defp find({_tag, attrs, children} = node, id, matrix) do
    case List.keyfind(attrs, "id", 0) do
      {"id", ^id} -> {node, matrix}
      _other -> find(children, id, multiply(matrix, transform(attrs)))
    end
  end

  defp find(_node, _id, _matrix), do: nil

  @doc """
  Return the box of an element in the coordinates of the file

  `matrix` is the matrix of the parent of the element. The function returns
  `nil` for an element with no shape.
  """
  @spec box(Floki.html_node(), matrix()) :: box() | nil
  def box({tag, attrs, children}, parent) when is_binary(tag) do
    matrix = multiply(parent, transform(attrs))

    cond do
      tag in @no_shape -> nil
      tag in ~w(g a svg switch) -> children |> Enum.map(&box(&1, matrix)) |> union()
      true -> attrs |> points(tag) |> Enum.map(&apply_matrix(matrix, &1)) |> bounds()
    end
  end

  def box(_node, _matrix), do: nil

  defp points(attrs, tag) when tag in ~w(rect image use foreignobject) do
    [x, y, w, h] = Enum.map(~w(x y width height), &number(attrs, &1))
    [{x, y}, {x + w, y}, {x, y + h}, {x + w, y + h}]
  end

  defp points(attrs, "circle") do
    [cx, cy, r] = Enum.map(~w(cx cy r), &number(attrs, &1))
    [{cx - r, cy - r}, {cx + r, cy - r}, {cx - r, cy + r}, {cx + r, cy + r}]
  end

  defp points(attrs, "ellipse") do
    [cx, cy, rx, ry] = Enum.map(~w(cx cy rx ry), &number(attrs, &1))
    [{cx - rx, cy - ry}, {cx + rx, cy - ry}, {cx - rx, cy + ry}, {cx + rx, cy + ry}]
  end

  defp points(attrs, "line") do
    [x1, y1, x2, y2] = Enum.map(~w(x1 y1 x2 y2), &number(attrs, &1))
    [{x1, y1}, {x2, y2}]
  end

  defp points(attrs, tag) when tag in ~w(polyline polygon) do
    attrs
    |> attribute("points")
    |> numbers()
    |> Enum.chunk_every(2, 2, :discard)
    |> Enum.map(&List.to_tuple/1)
  end

  defp points(attrs, "path"),
    do: attrs |> attribute("d") |> Expresso.Element.Diagram.Path.points()

  defp points(attrs, tag) when tag in ~w(text tspan) do
    [x, y] = Enum.map(~w(x y), &(attrs |> attribute(&1) |> numbers() |> List.first(0.0)))
    [{x, y}]
  end

  defp points(_attrs, _tag), do: []

  defp attribute(attrs, name) do
    case List.keyfind(attrs, name, 0) do
      {^name, value} -> value
      nil -> ""
    end
  end

  defp number(attrs, name), do: attrs |> attribute(name) |> numbers() |> List.first(0.0)

  @number ~r/[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?/

  @doc false
  @spec numbers(String.t()) :: [float()]
  def numbers(text) do
    @number |> Regex.scan(text) |> Enum.map(fn [number] -> to_float(number) end)
  end

  # `Float.parse/1` needs a digit on each side of the point, as in "0.5".
  defp to_float(text) do
    text = Regex.replace(~r/^([+-]?)\./, text, "\\g{1}0.")
    text = Regex.replace(~r/\.(?=$|[eE])/, text, ".0")
    {value, ""} = Float.parse(text)
    value
  end

  defp bounds([]), do: nil

  defp bounds(points) do
    {xs, ys} = Enum.unzip(points)
    {Enum.min(xs), Enum.min(ys), Enum.max(xs), Enum.max(ys)}
  end

  defp union(boxes) do
    case Enum.reject(boxes, &is_nil/1) do
      [] -> nil
      boxes -> boxes |> Enum.flat_map(fn {l, t, r, b} -> [{l, t}, {r, b}] end) |> bounds()
    end
  end

  # The transform attribute of an element, as one matrix.
  defp transform(attrs) do
    ~r/(matrix|translate|scale|rotate|skewX|skewY)\s*\(([^)]*)\)/
    |> Regex.scan(attribute(attrs, "transform"))
    |> Enum.map(fn [_all, name, args] -> function(name, numbers(args)) end)
    |> Enum.reduce(@identity, &multiply(&2, &1))
  end

  defp function("matrix", [a, b, c, d, e, f]), do: {a, b, c, d, e, f}
  defp function("translate", [x]), do: {1.0, 0.0, 0.0, 1.0, x, 0.0}
  defp function("translate", [x, y]), do: {1.0, 0.0, 0.0, 1.0, x, y}
  defp function("scale", [s]), do: {s, 0.0, 0.0, s, 0.0, 0.0}
  defp function("scale", [x, y]), do: {x, 0.0, 0.0, y, 0.0, 0.0}

  defp function("rotate", [angle]) do
    {cos, sin} = {:math.cos(radians(angle)), :math.sin(radians(angle))}
    {cos, sin, -sin, cos, 0.0, 0.0}
  end

  defp function("rotate", [angle, cx, cy]) do
    @identity
    |> multiply(function("translate", [cx, cy]))
    |> multiply(function("rotate", [angle]))
    |> multiply(function("translate", [-cx, -cy]))
  end

  defp function("skewX", [angle]), do: {1.0, 0.0, :math.tan(radians(angle)), 1.0, 0.0, 0.0}
  defp function("skewY", [angle]), do: {1.0, :math.tan(radians(angle)), 0.0, 1.0, 0.0, 0.0}
  defp function(_name, _args), do: @identity

  defp radians(degrees), do: degrees * :math.pi() / 180

  # The product m · n: the transform n first, then m.
  defp multiply({a1, b1, c1, d1, e1, f1}, {a2, b2, c2, d2, e2, f2}) do
    {a1 * a2 + c1 * b2, b1 * a2 + d1 * b2, a1 * c2 + c1 * d2, b1 * c2 + d1 * d2,
     a1 * e2 + c1 * f2 + e1, b1 * e2 + d1 * f2 + f1}
  end

  defp apply_matrix({a, b, c, d, e, f}, {x, y}), do: {a * x + c * y + e, b * x + d * y + f}

  # A distance in the coordinates of the file, in the coordinates of a parent.
  # A distance does not change with the translation of the parent, so only
  # the linear part of the matrix counts.
  defp unscale({a, b, c, d, _e, _f}, {dx, dy}) do
    determinant = a * d - b * c
    {(d * dx - c * dy) / determinant, (a * dy - b * dx) / determinant}
  end
end
