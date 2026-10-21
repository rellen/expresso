defmodule Expresso.Element.Chart.Voronoi do
  @moduledoc """
  The layout of a Voronoi treemap: a convex polygon divided into cells, with
  an area in proportion to the value of each part

  A Voronoi treemap divides a container into one cell for each part of the
  top level. Each group then divides its own cell for its parts, down to the
  leaves. A cell has no fixed direction, so the cell of a small part does not
  become a thin strip, as a rectangle of a squarified treemap can.

  The layout uses the algorithm of Nocaj and Brandes, "Computing Voronoi
  Treemaps: Faster, Simpler, and Resolution-independent" (2012). In each
  container, the algorithm does these steps:

  1. Put one site for each part inside the container. The sites come from
     the Halton sequence of the bases 2 and 3, so the same input gives the
     same layout.
  2. Make the power diagram of the sites. The cell of a site is the
     container, clipped by one half-plane for each other site.
  3. Move each site to the centroid of its cell, and change its weight by the
     ratio of the target area to the area of its cell. A change is at most 50
     percent. When the error becomes larger than in the iteration before,
     the most change becomes smaller, so the weights do not swing from side
     to side. Then make sure that each site stays in its own cell, and do
     step 2 again.
  4. Stop when the error is less than 1 percent and each part has a cell, or
     after 200 iterations. The error is the sum of the differences between
     each area and its target, as a part of the area of the container. A
     small part can lose its cell while the error stays below the limit, so
     a diagram with an empty cell does not stop the iterations.
  5. When the error is still more than 1 percent, start again with the next
     sites of the Halton sequence, for at most 6 starts. The layout keeps the
     diagram with the smallest error.

  The error of each area is therefore less than the error of the diagram. A
  part with the value 0 gets no cell.

  A very thin container, such as a triangle with one side of a few units and
  two sides of hundreds, leaves little room to move the sites. Its error can
  stay above the limit after each start, and the layout then returns the
  diagram with the smallest error. A container that is a box, a circle, a
  hexagon or a polygon with no sharp corner reaches the limit.

  The container must be convex. A cell is convex before the clip, so a
  convex container gives convex cells, and each group can divide its cell
  again. The dent of a concave container can cut a cell into two pieces.
  `check_shape/1` refuses a concave polygon.

  The coordinates are the units of the SVG, and the y axis goes down. Each
  polygon has its corners in the order that gives it a positive area.
  """

  @typedoc "A point in the units of the SVG"
  @type point :: {float(), float()}

  @typedoc "A convex polygon, as its corners in order"
  @type polygon :: [point()]

  @typedoc """
  A part to lay out. A leaf has a value, and a group has the sum of the
  values of its children.
  """
  @type item :: %{id: term(), value: number(), children: [item()]}

  @typedoc """
  The shape of the container: the box, a circle or a hexagon in the box, or
  the corners of a polygon in a unit box
  """
  @type shape :: :rectangle | :circle | :hexagon | [{number(), number()}]

  @typedoc "A box, as the edges of a chart give it"
  @type box :: %{left: number(), right: number(), top: number(), bottom: number()}

  # The limit of the error, the most iterations of one container, the most
  # change of a weight in one iteration, and a small distance.
  @limit 0.01
  @iterations 200
  @starts 6

  # The most points of the Halton sequence to try for the sites of one
  # container.
  @search 50_000
  @flicker 0.5
  @epsilon 1.0e-9

  # The number of corners of the polygon of a circle.
  @circle 64

  @doc """
  Return the limit of the error of a diagram, as a part of the area of its
  container

      iex> Expresso.Element.Chart.Voronoi.limit()
      0.01
  """
  @spec limit() :: float()
  def limit, do: @limit

  @doc """
  Check a shape of a container

  A list of points must have at least 3 points, each in the unit box from 0
  to 1. The polygon must not cross itself, and it must be convex.

      iex> Expresso.Element.Chart.Voronoi.check_shape(:hexagon)
      :ok

      iex> Expresso.Element.Chart.Voronoi.check_shape([{0, 0}, {1, 0}, {0.5, 1}])
      :ok

      iex> {:error, _message} = Expresso.Element.Chart.Voronoi.check_shape([{0, 0}, {1, 0}])
  """
  @spec check_shape(term()) :: :ok | {:error, String.t()}
  def check_shape(shape) when shape in [:rectangle, :circle, :hexagon], do: :ok

  def check_shape(points) when is_list(points) do
    cond do
      not Enum.all?(points, &unit_point?/1) ->
        {:error,
         "each point of the shape is a tuple {x, y} of two numbers from 0 to 1, " <>
           "such as {0.5, 1}"}

      length(points) < 3 ->
        {:error, "the shape has #{length(points)} points, and a polygon needs at least 3"}

      crosses?(Enum.map(points, &float_point/1)) ->
        {:error, "the polygon of the shape crosses itself. Give its points in order around it."}

      not convex?(Enum.map(points, &float_point/1)) ->
        {:error,
         "the polygon of the shape is not convex: it has a dent, or its area is zero. " <>
           "A Voronoi treemap fills a convex polygon only."}

      true ->
        :ok
    end
  end

  def check_shape(_shape),
    do: {:error, "the shape is :rectangle, :circle, :hexagon or a list of points"}

  @doc """
  Check the `shape` option of a chart, for the DSL

      iex> Expresso.Element.Chart.Voronoi.shape(:circle)
      {:ok, :circle}
  """
  @spec shape(term()) :: {:ok, shape()} | {:error, String.t()}
  def shape(shape) do
    with :ok <- check_shape(shape), do: {:ok, shape}
  end

  defp unit_point?({x, y}) when is_number(x) and is_number(y),
    do: x >= 0 and x <= 1 and y >= 0 and y <= 1

  defp unit_point?(_point), do: false

  defp float_point({x, y}), do: {x / 1, y / 1}

  @doc """
  Return the polygon of a shape in a box

  A circle and a hexagon have their center at the center of the box, and the
  largest size that fits it. The points of a list go into the largest square
  at the center of the box, so the polygon keeps its proportions.

      iex> box = %{left: 0, right: 200, top: 0, bottom: 100}
      iex> Expresso.Element.Chart.Voronoi.container([{0, 0}, {1, 0}, {0.5, 1}], box)
      [{50.0, 0.0}, {150.0, 0.0}, {100.0, 100.0}]
  """
  @spec container(shape(), box()) :: polygon()
  def container(:rectangle, box) do
    orient([
      {box.left / 1, box.top / 1},
      {box.right / 1, box.top / 1},
      {box.right / 1, box.bottom / 1},
      {box.left / 1, box.bottom / 1}
    ])
  end

  def container(:circle, box) do
    {cx, cy, w, h} = center(box)
    regular(cx, cy, min(w, h) / 2, @circle)
  end

  def container(:hexagon, box) do
    {cx, cy, w, h} = center(box)
    regular(cx, cy, min(w / 2, h / :math.sqrt(3)), 6)
  end

  def container(points, box) when is_list(points) do
    {cx, cy, w, h} = center(box)
    side = min(w, h)
    left = cx - side / 2
    top = cy - side / 2

    points
    |> Enum.map(fn {u, v} -> {left + u * side, top + v * side} end)
    |> orient()
  end

  defp center(box) do
    w = box.right - box.left
    h = box.bottom - box.top
    {box.left + w / 2, box.top + h / 2, w, h}
  end

  defp regular(cx, cy, radius, corners) do
    for k <- 0..(corners - 1) do
      angle = 2 * :math.pi() * k / corners
      {cx + radius * :math.cos(angle), cy + radius * :math.sin(angle)}
    end
    |> orient()
  end

  # The corners in the order that gives a positive area.
  defp orient(polygon), do: if(signed_area(polygon) < 0, do: Enum.reverse(polygon), else: polygon)

  @doc """
  Divide a convex polygon into the cells of a tree of parts

  Return a map from the id of each part to its cell. A group gets the cell
  that holds the cells of its parts. A part with the value 0, and a group
  with the sum 0, get an empty list.

      iex> square = [{0.0, 0.0}, {10.0, 0.0}, {10.0, 10.0}, {0.0, 10.0}]
      iex> cells = Expresso.Element.Chart.Voronoi.layout([%{id: :a, value: 1, children: []}], square)
      iex> cells.a == square
      true
  """
  @spec layout([item()], polygon()) :: %{term() => polygon()}
  def layout(items, polygon), do: place(items, polygon, %{})

  defp place(items, [], cells), do: Enum.reduce(items, cells, &empty_cells/2)

  defp place(items, polygon, cells) do
    {full, empty} = Enum.split_with(items, &(value(&1) > 0))
    cells = Enum.reduce(empty, cells, &empty_cells/2)

    full
    |> divide(polygon)
    |> Enum.reduce(cells, fn {item, cell}, cells ->
      place(item.children, cell, Map.put(cells, item.id, cell))
    end)
  end

  defp empty_cells(item, cells),
    do: Enum.reduce(item.children, Map.put(cells, item.id, []), &empty_cells/2)

  defp value(%{children: []} = item), do: item.value
  defp value(%{children: children}), do: children |> Enum.map(&value/1) |> Enum.sum()

  # The cells of the items of one container, each with a value more than 0.
  defp divide([], _polygon), do: []
  defp divide([item], polygon), do: [{item, polygon}]

  defp divide(items, polygon) do
    whole = area(polygon)
    total = items |> Enum.map(&value/1) |> Enum.sum()
    targets = Enum.map(items, &(value(&1) / total * whole))
    count = length(items)
    weights = List.duplicate(whole / count / 2, count)

    cells =
      Enum.reduce_while(0..(@starts - 1), nil, fn start, best ->
        sites = halton(polygon, count, start * count)
        run = iterate({sites, weights, @flicker, nil}, targets, polygon, whole, @iterations, nil)
        best = if best == nil or elem(run, 1) < elem(best, 1), do: run, else: best
        if elem(best, 1) <= @limit, do: {:halt, best}, else: {:cont, best}
      end)
      |> elem(0)

    Enum.zip(items, cells)
  end

  # The state of one iteration: the sites, their weights, the most change of
  # a weight, and the error of the iteration before. A larger error than
  # before makes the next change smaller, so the weights do not swing from
  # side to side.
  defp iterate({sites, weights, flicker, before}, targets, polygon, whole, left, best) do
    cells = diagram(sites, weights, polygon)
    error = score(cells, targets, whole)
    best = if best == nil or error < elem(best, 1), do: {cells, error}, else: best

    if error <= @limit or left == 0 do
      best
    else
      flicker =
        if before != nil and error > before,
          do: max(flicker * 0.8, 0.01),
          else: min(flicker * 1.05, @flicker)

      sites = Enum.zip_with(cells, sites, &move/2)
      weights = Enum.zip_with([cells, weights, targets], &adapt(&1, flicker))
      weights = settle(sites, weights)
      iterate({sites, weights, flicker, error}, targets, polygon, whole, left - 1, best)
    end
  end

  # The error of a diagram, and 2 more when a part has no area: the error is
  # at most 2, so such a diagram is worse than each diagram with an area for
  # each part, and it is never the result while a better one exists.
  defp score(cells, targets, whole) do
    error = error(cells, targets, whole)
    if Enum.any?(cells, &(area(&1) <= @epsilon)), do: error + 2, else: error
  end

  @doc """
  Return the error of the cells of one container: the sum of the
  differences between each area and its target, as a part of the area of
  the container
  """
  @spec error([polygon()], [number()], number()) :: float()
  def error(cells, targets, whole) do
    cells
    |> Enum.zip_with(targets, &abs(area(&1) - &2))
    |> Enum.sum()
    |> Kernel./(whole)
  end

  # A site goes to the centroid of its cell. A site with an empty cell stays.
  defp move(cell, site), do: if(area(cell) > @epsilon, do: centroid(cell), else: site)

  defp adapt([cell, weight, target], flicker) do
    current = area(cell)
    ratio = if current > @epsilon, do: target / current, else: 1 + flicker
    ratio = ratio |> max(1 - flicker) |> min(1 + flicker)
    max(weight * ratio, @epsilon)
  end

  # A site is outside its own cell when another site has a weight more than
  # its own by more than the square of their distance. The heavier weight
  # then goes down to that limit, until no site is outside its cell.
  defp settle(sites, weights) do
    indexed = Enum.with_index(sites)
    settle(indexed, List.to_tuple(weights), length(sites) * length(sites))
  end

  defp settle(_indexed, weights, 0), do: Tuple.to_list(weights)

  defp settle(indexed, weights, left) do
    {weights, fixed} =
      for {si, i} <- indexed, {sj, j} <- indexed, i < j, reduce: {weights, false} do
        {weights, fixed} ->
          wi = elem(weights, i)
          wj = elem(weights, j)
          d2 = distance2(si, sj)

          cond do
            wi - wj > d2 -> {put_elem(weights, i, max(wj + d2 - @epsilon, @epsilon)), true}
            wj - wi > d2 -> {put_elem(weights, j, max(wi + d2 - @epsilon, @epsilon)), true}
            true -> {weights, fixed}
          end
      end

    if fixed, do: settle(indexed, weights, left - 1), else: Tuple.to_list(weights)
  end

  @doc """
  Return the power diagram of weighted sites, clipped to a convex polygon

  The cell of a site holds each point `p` of the polygon where
  `|p - site|² - weight` is the least of all the sites.
  """
  @spec diagram([point()], [number()], polygon()) :: [polygon()]
  def diagram(sites, weights, polygon) do
    pairs = Enum.zip(sites, weights)

    for {{si, wi}, i} <- Enum.with_index(pairs) do
      pairs
      |> Enum.with_index()
      |> Enum.reject(fn {_pair, j} -> j == i end)
      |> Enum.reduce(polygon, fn {{sj, wj}, _j}, cell -> clip(cell, bisector(si, wi, sj, wj)) end)
    end
  end

  # The half-plane of the points nearer to site i than to site j, in the
  # power distance: a x + b y <= c.
  defp bisector({xi, yi}, wi, {xj, yj}, wj) do
    {2 * (xj - xi), 2 * (yj - yi), xj * xj + yj * yj - wj - (xi * xi + yi * yi - wi)}
  end

  @doc """
  Clip a convex polygon to the half-plane `a x + b y <= c`

      iex> square = [{0.0, 0.0}, {2.0, 0.0}, {2.0, 2.0}, {0.0, 2.0}]
      iex> Expresso.Element.Chart.Voronoi.clip(square, {1, 0, 1})
      [{1.0, 0.0}, {1.0, 2.0}, {0.0, 2.0}, {0.0, 0.0}]
  """
  @spec clip(polygon(), {number(), number(), number()}) :: polygon()
  def clip([], _half), do: []

  def clip(polygon, {a, b, c}) do
    side = fn {x, y} -> a * x + b * y - c end

    polygon
    |> Enum.zip(tl(polygon) ++ [hd(polygon)])
    |> Enum.flat_map(fn {p, q} ->
      fp = side.(p)
      fq = side.(q)

      cond do
        fp <= 0 and fq <= 0 -> [q]
        fp <= 0 -> [cross(p, q, fp, fq)]
        fq <= 0 -> [cross(p, q, fp, fq), q]
        true -> []
      end
    end)
    |> tidy()
  end

  defp cross({px, py}, {qx, qy}, fp, fq) do
    t = fp / (fp - fq)
    {px + t * (qx - px), py + t * (qy - py)}
  end

  # Drop a corner at the same place as the corner before it. A polygon with
  # less than 3 corners, or with no area, is empty.
  defp tidy(points) do
    points =
      points
      |> Enum.chunk_every(2, 1, [hd(points ++ [nil])])
      |> Enum.reject(fn
        [p, q] when q != nil -> distance2(p, q) < @epsilon * @epsilon
        _last -> false
      end)
      |> Enum.map(&hd/1)

    if length(points) < 3 or abs(signed_area(points)) < @epsilon, do: [], else: points
  end

  @doc """
  Return the area of a polygon

      iex> Expresso.Element.Chart.Voronoi.area([{0.0, 0.0}, {4.0, 0.0}, {4.0, 3.0}])
      6.0
  """
  @spec area(polygon()) :: float()
  def area([]), do: 0.0
  def area(polygon), do: abs(signed_area(polygon))

  defp signed_area(polygon) do
    polygon
    |> Enum.zip(tl(polygon) ++ [hd(polygon)])
    |> Enum.map(fn {{x1, y1}, {x2, y2}} -> x1 * y2 - x2 * y1 end)
    |> Enum.sum()
    |> Kernel./(2)
  end

  @doc """
  Return the centroid of a polygon

      iex> Expresso.Element.Chart.Voronoi.centroid([{0.0, 0.0}, {4.0, 0.0}, {4.0, 2.0}, {0.0, 2.0}])
      {2.0, 1.0}
  """
  @spec centroid(polygon()) :: point()
  def centroid(polygon) do
    a = signed_area(polygon)

    {sx, sy} =
      polygon
      |> Enum.zip(tl(polygon) ++ [hd(polygon)])
      |> Enum.reduce({0.0, 0.0}, fn {{x1, y1}, {x2, y2}}, {sx, sy} ->
        k = x1 * y2 - x2 * y1
        {sx + (x1 + x2) * k, sy + (y1 + y2) * k}
      end)

    {sx / (6 * a), sy / (6 * a)}
  end

  @doc """
  Return true when a point is inside a convex polygon or on its edge
  """
  @spec inside?(point(), polygon()) :: boolean()
  def inside?(point, polygon), do: edge_distance(point, polygon) >= -1.0e-6

  @doc """
  Return the pole of inaccessibility of a convex polygon, and its distance
  to the nearest edge

  The pole is the point inside the polygon that is farthest from its edges,
  so a label at the pole has the most room. The search of Agafonkin
  (`polylabel`) divides the box of the polygon into squares, and it divides
  each square again while the square can hold a better point. It stops at a
  precision of half a unit.

      iex> square = [{0.0, 0.0}, {10.0, 0.0}, {10.0, 10.0}, {0.0, 10.0}]
      iex> {{x, y}, distance} = Expresso.Element.Chart.Voronoi.pole(square)
      iex> {round(x), round(y), round(distance)}
      {5, 5, 5}
  """
  @spec pole(polygon()) :: {point(), float()}
  def pole([]), do: {{0.0, 0.0}, 0.0}

  def pole(polygon) do
    {xs, ys} = Enum.unzip(polygon)
    {left, right} = Enum.min_max(xs)
    {top, bottom} = Enum.min_max(ys)
    size = min(right - left, bottom - top)

    if size <= 0 do
      {centroid(polygon), 0.0}
    else
      half = size / 2

      squares =
        for x <- steps(left, right, size), y <- steps(top, bottom, size) do
          square({x + half, y + half}, half, polygon)
        end

      start = square(centroid(polygon), 0, polygon)
      best = Enum.max_by([start | squares], &elem(&1, 1))
      search(:gb_sets.from_list(Enum.map(squares, &queued/1)), best, polygon)
    end
  end

  defp steps(from, to, size),
    do: Stream.iterate(from, &(&1 + size)) |> Enum.take_while(&(&1 < to))

  # A square of the search: its center, the distance of its center to the
  # edges, its half size, and the best distance that a point in it can have.
  defp square(center, half, polygon) do
    distance = edge_distance(center, polygon)
    {center, distance, half, distance + half * :math.sqrt(2)}
  end

  defp queued({center, _distance, half, most} = square), do: {-most, center, half, square}

  defp search(queue, best, polygon) do
    if :gb_sets.is_empty(queue) do
      {elem(best, 0), max(elem(best, 1), 0.0)}
    else
      {{_key, _center, _half, square}, queue} = :gb_sets.take_smallest(queue)
      {center, distance, half, most} = square
      best = if distance > elem(best, 1), do: square, else: best

      if most - elem(best, 1) <= 0.5,
        do: search(queue, best, polygon),
        else: search(split(center, half, polygon, queue), best, polygon)
    end
  end

  # Put the four quarters of a square into the queue.
  defp split({x, y}, half, polygon, queue) do
    quarter = half / 2

    for dx <- [-quarter, quarter], dy <- [-quarter, quarter], reduce: queue do
      queue -> :gb_sets.add(queued(square({x + dx, y + dy}, quarter, polygon)), queue)
    end
  end

  # The distance from a point to the nearest edge line of a convex polygon
  # with a positive area: more than 0 inside, and less than 0 outside.
  defp edge_distance({px, py}, polygon) do
    polygon
    |> Enum.zip(tl(polygon) ++ [hd(polygon)])
    |> Enum.map(fn {{x1, y1}, {x2, y2}} ->
      length = :math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
      ((x2 - x1) * (py - y1) - (y2 - y1) * (px - x1)) / length
    end)
    |> Enum.min()
  end

  # The sites of a container: the points of the Halton sequence in the box of
  # the polygon, in the order of the sequence, that fall inside the polygon.
  # The search stops after a fixed number of points of the sequence, so a
  # container too thin to hold enough of them gets more sites between its
  # centroid and its corners. A convex polygon holds each such point.
  defp halton(polygon, count, skip) do
    {xs, ys} = Enum.unzip(polygon)
    {left, right} = Enum.min_max(xs)
    {top, bottom} = Enum.min_max(ys)

    inside =
      1..@search
      |> Stream.map(
        &{left + radical(&1, 2) * (right - left), top + radical(&1, 3) * (bottom - top)}
      )
      |> Stream.filter(&(edge_distance(&1, polygon) > 0))
      |> Stream.drop(skip)
      |> Enum.take(count)

    inside ++ inner(polygon, count - length(inside))
  end

  defp inner(_polygon, 0), do: []

  defp inner(polygon, count) do
    {cx, cy} = centroid(polygon)
    corners = List.to_tuple(polygon)

    for k <- 1..count do
      {x, y} = elem(corners, rem(k, tuple_size(corners)))
      t = 0.1 + 0.8 * radical(k, 2)
      {cx + t * (x - cx), cy + t * (y - cy)}
    end
  end

  # The radical inverse of an index in a base: the digits of the index in
  # that base, after the point in the opposite order.
  defp radical(index, base), do: radical(index, base, 1 / base, 0.0)
  defp radical(0, _base, _scale, sum), do: sum

  defp radical(index, base, scale, sum),
    do: radical(div(index, base), base, scale / base, sum + rem(index, base) * scale)

  defp distance2({x1, y1}, {x2, y2}), do: (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1)

  # A polygon crosses itself when two edges that do not share a corner meet.
  defp crosses?(points) do
    edges = Enum.zip(points, tl(points) ++ [hd(points)])
    indexed = Enum.with_index(edges)
    count = length(edges)

    Enum.any?(
      for {e1, i} <- indexed,
          {e2, j} <- indexed,
          j > i + 1,
          not (i == 0 and j == count - 1),
          do: meet?(e1, e2)
    )
  end

  defp meet?({p1, p2}, {p3, p4}) do
    d1 = turn(p3, p4, p1)
    d2 = turn(p3, p4, p2)
    d3 = turn(p1, p2, p3)
    d4 = turn(p1, p2, p4)
    d1 * d2 < 0 and d3 * d4 < 0
  end

  # A polygon is convex when each corner turns in the same direction, and its
  # area is more than zero.
  defp convex?(points) do
    nexts = rotate(points)

    turns =
      [points, nexts, rotate(nexts)]
      |> Enum.zip_with(fn [a, b, c] -> turn(a, b, c) end)
      |> Enum.reject(&(abs(&1) < @epsilon))

    abs(signed_area(points)) > @epsilon and
      (Enum.all?(turns, &(&1 > 0)) or Enum.all?(turns, &(&1 < 0)))
  end

  defp rotate([first | rest]), do: rest ++ [first]

  defp turn({ax, ay}, {bx, by}, {cx, cy}), do: (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
end
