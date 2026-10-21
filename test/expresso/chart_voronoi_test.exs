defmodule Expresso.ChartVoronoiTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Expresso.Element.Chart.Voronoi

  doctest Voronoi

  @box %{left: 4, right: 796, top: 4, bottom: 446}

  # A small distance in the units of the SVG, for the sums of areas.
  @tolerance 1.0e-6

  describe "check_shape/1" do
    test "accepts the three named shapes and a convex polygon in either order" do
      for shape <- [:rectangle, :circle, :hexagon] do
        assert Voronoi.check_shape(shape) == :ok
      end

      square = [{0, 0}, {1, 0}, {1, 1}, {0, 1}]
      assert Voronoi.check_shape(square) == :ok
      assert Voronoi.check_shape(Enum.reverse(square)) == :ok
    end

    test "accepts a polygon with three corners on one line, as a convex polygon" do
      assert Voronoi.check_shape([{0, 0}, {0.5, 0}, {1, 0}, {1, 1}, {0, 1}]) == :ok
    end

    test "refuses a polygon with fewer than 3 points" do
      assert {:error, message} = Voronoi.check_shape([{0, 0}, {1, 1}])
      assert message =~ "needs at least 3"
    end

    test "refuses a point outside the unit box and a point that is not a tuple of two numbers" do
      for points <- [
            [{0, 0}, {2, 0}, {0, 1}],
            [{0, 0}, [1, 0], {0, 1}],
            [{0, 0}, {:a, 0}, {0, 1}]
          ] do
        assert {:error, message} = Voronoi.check_shape(points)
        assert message =~ "from 0 to 1"
      end
    end

    test "refuses a polygon that crosses itself" do
      bow = [{0, 0}, {1, 1}, {1, 0}, {0, 1}]
      assert {:error, message} = Voronoi.check_shape(bow)
      assert message =~ "crosses itself"
    end

    test "refuses a concave polygon and a polygon with no area" do
      u = [{0, 0}, {1, 0}, {1, 1}, {0.6, 1}, {0.6, 0.4}, {0.4, 0.4}, {0.4, 1}, {0, 1}]
      line = [{0, 0}, {0.5, 0.5}, {1, 1}]

      for points <- [u, line] do
        assert {:error, message} = Voronoi.check_shape(points)
        assert message =~ "not convex"
      end
    end

    test "refuses another term" do
      assert {:error, message} = Voronoi.check_shape(:star)
      assert message =~ ":rectangle, :circle, :hexagon"
    end
  end

  describe "container/2" do
    test "a rectangle is the box" do
      polygon = Voronoi.container(:rectangle, @box)
      assert Voronoi.area(polygon) == 792 * 442
    end

    test "a circle and a hexagon have their center at the center of the box, and fit it" do
      for shape <- [:circle, :hexagon] do
        polygon = Voronoi.container(shape, @box)
        {x, y} = Voronoi.centroid(polygon)
        assert_in_delta x, 400, 1.0e-6
        assert_in_delta y, 225, 1.0e-6

        for {px, py} <- polygon do
          assert px >= @box.left - 1.0e-6 and px <= @box.right + 1.0e-6
          assert py >= @box.top - 1.0e-6 and py <= @box.bottom + 1.0e-6
        end
      end

      assert length(Voronoi.container(:hexagon, @box)) == 6
    end

    test "the points of a list keep their proportions in a square at the center of the box" do
      [{x1, y1}, {x2, _y2}, {_x3, y3}] = Voronoi.container([{0, 0}, {1, 0}, {0.5, 1}], @box)
      assert x2 - x1 == y3 - y1
      assert x2 - x1 == 442
      assert y1 == 4
    end
  end

  describe "layout/2" do
    test "a part with the value 0 and a group with the sum 0 get no cell" do
      items = [
        %{id: :a, value: 3, children: []},
        %{id: :b, value: 0, children: []},
        %{id: :g, value: 0, children: [%{id: :x, value: 0, children: []}]}
      ]

      polygon = Voronoi.container(:rectangle, @box)
      cells = Voronoi.layout(items, polygon)

      assert cells.a == polygon
      assert cells.b == []
      assert cells.g == []
      assert cells.x == []
    end

    test "a container too thin for the points of the Halton sequence gets a cell for each part" do
      needle = [{0.0, 0.0}, {800.0, 0.0}, {800.0, 1.0e-4}]
      items = for id <- 1..5, do: %{id: id, value: id, children: []}
      cells = Voronoi.layout(items, needle)

      for id <- 1..5, do: assert(Voronoi.area(cells[id]) > 0)
      sum = 1..5 |> Enum.map(&Voronoi.area(cells[&1])) |> Enum.sum()
      assert_in_delta sum, Voronoi.area(needle), 1.0e-9
    end

    test "a group has the sum of its parts, and its parts fill its cell" do
      items = [
        %{id: :a, value: 1, children: []},
        %{
          id: :g,
          value: nil,
          children: [%{id: :x, value: 2, children: []}, %{id: :y, value: 1, children: []}]
        }
      ]

      polygon = Voronoi.container(:hexagon, @box)
      cells = Voronoi.layout(items, polygon)
      whole = Voronoi.area(polygon)

      assert_in_delta Voronoi.area(cells.g), whole * 3 / 4, whole * Voronoi.limit()

      assert_in_delta Voronoi.area(cells.x) + Voronoi.area(cells.y),
                      Voronoi.area(cells.g),
                      @tolerance
    end
  end

  # A layout takes up to some hundred milliseconds, so the properties of a
  # layout take 150 runs and not the 500 of `config/config.exs`.
  describe "the properties of a layout" do
    property "the error of each area is less than the limit, in each container" do
      check all {items, polygon} <- input(), max_runs: 150 do
        cells = Voronoi.layout(items, polygon)

        for {container, children} <- containers(items, polygon, cells),
            whole = Voronoi.area(container) do
          total = children |> Enum.map(&value/1) |> Enum.sum()

          for child <- children, value(child) > 0 do
            target = value(child) / total * whole
            error = abs(Voronoi.area(cells[child.id]) - target) / whole
            assert error <= Voronoi.limit(), "error #{error} of #{inspect(child.id)}"
          end
        end
      end
    end

    property "each part with a value has a cell inside the cell of its group, with no gap and no overlap" do
      check all {items, polygon} <- input(), max_runs: 150 do
        cells = Voronoi.layout(items, polygon)

        for {container, children} <- containers(items, polygon, cells) do
          for child <- children, value(child) > 0 do
            assert Voronoi.area(cells[child.id]) > 0, "no area for #{inspect(child.id)}"
          end

          inner = for child <- children, cells[child.id] != [], do: cells[child.id]

          for cell <- inner, point <- cell, do: assert(Voronoi.inside?(point, container))

          sum = inner |> Enum.map(&Voronoi.area/1) |> Enum.sum()
          assert_in_delta sum, Voronoi.area(container), 1.0e-6 * Voronoi.area(container)

          for {a, i} <- Enum.with_index(inner), {b, j} <- Enum.with_index(inner), i < j do
            assert Voronoi.area(intersection(a, b)) <= 1.0e-6 * Voronoi.area(container)
          end
        end
      end
    end

    property "the same input gives the same output" do
      check all {items, polygon} <- input(), max_runs: 150 do
        assert Voronoi.layout(items, polygon) == Voronoi.layout(items, polygon)
      end
    end

    property "a polygon from points around a circle passes the check, in either order" do
      check all points <- convex_points() do
        assert Voronoi.check_shape(points) == :ok
        assert Voronoi.check_shape(Enum.reverse(points)) == :ok
      end
    end
  end

  # A tree of at most three levels, with values from 0 to 1000, and a
  # container of each kind.
  defp input do
    gen all items <- tree(), shape <- shape() do
      {items, Voronoi.container(shape, @box)}
    end
  end

  defp shape, do: one_of([member_of([:rectangle, :circle, :hexagon]), convex_points()])

  # The corners of a convex polygon in the unit box: points on a circle, in
  # order, with at least 30 degrees between two neighbors. Each gap is 30
  # degrees and a share of the rest. A sliver, such as a triangle with one
  # side of a few units, can stay above the limit, and
  # `Expresso.Element.Chart.Voronoi` tells why.
  defp convex_points do
    gen all count <- integer(3..8),
            shares <- list_of(integer(1..100), length: count),
            offset <- integer(0..359) do
      rest = 360 - 30 * count
      total = Enum.sum(shares)
      gaps = Enum.map(shares, &(30 + rest * &1 / total))

      gaps
      |> Enum.scan(offset, &(&1 + &2))
      |> Enum.map(fn degrees ->
        radians = degrees * :math.pi() / 180
        {0.5 + 0.5 * :math.cos(radians), 0.5 + 0.5 * :math.sin(radians)}
      end)
    end
  end

  defp tree do
    gen all groups <- list_of(branch(2), min_length: 1, max_length: 6) do
      number(groups, [])
    end
  end

  defp branch(0), do: map(leaf_value(), &%{value: &1, children: []})

  defp branch(depth) do
    one_of([
      branch(0),
      gen all children <- list_of(branch(depth - 1), min_length: 1, max_length: 6) do
        %{value: nil, children: children}
      end
    ])
  end

  defp leaf_value, do: frequency([{1, constant(0)}, {9, float(min: 1.0, max: 1000.0)}])

  # Give each part a unique id: its path in the tree.
  defp number(parts, path) do
    for {part, index} <- Enum.with_index(parts) do
      id = path ++ [index]
      %{part | children: number(part.children, id)} |> Map.put(:id, id)
    end
  end

  defp value(%{children: [], value: value}), do: value
  defp value(%{children: children}), do: children |> Enum.map(&value/1) |> Enum.sum()

  # Each container with the parts that divide it: the root polygon with the
  # top level, and the cell of each group with its children. A container
  # with parts that have the sum 0 has no cells to check.
  defp containers(items, polygon, cells) do
    groups =
      for item <- flatten(items),
          item.children != [],
          cells[item.id] != [],
          do: {cells[item.id], item.children}

    Enum.filter([{polygon, items} | groups], fn {_container, children} ->
      children |> Enum.map(&value/1) |> Enum.sum() > 0
    end)
  end

  defp flatten(items), do: Enum.flat_map(items, &[&1 | flatten(&1.children)])

  # The intersection of two convex polygons: the first one, clipped by the
  # half-plane of each edge of the second one.
  defp intersection(a, b) do
    b
    |> Enum.zip(tl(b) ++ [hd(b)])
    |> Enum.reduce(a, fn {{x1, y1}, {x2, y2}}, polygon ->
      # The inside of an edge of a polygon with a positive area is on its
      # left: (x2 - x1) (y - y1) - (y2 - y1) (x - x1) >= 0.
      Voronoi.clip(polygon, {y2 - y1, -(x2 - x1), (y2 - y1) * x1 - (x2 - x1) * y1})
    end)
  end
end
