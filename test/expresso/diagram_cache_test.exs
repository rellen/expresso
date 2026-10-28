defmodule Expresso.Element.DiagramCacheTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.Diagram.Cache

  # A function that sends a message for each call, so a test counts the calls.
  defp counted(value) do
    test = self()

    fn ->
      send(test, {:called, value})
      value
    end
  end

  test "fetch/2 outside run/2 calls the function each time" do
    assert Cache.fetch(:key, counted(1)) == 1
    assert Cache.fetch(:key, counted(1)) == 1
    assert_received {:called, 1}
    assert_received {:called, 1}
  end

  test "fetch/2 in a run calls the function one time for each key" do
    {result, cache} =
      Cache.run(%{}, fn ->
        [Cache.fetch(:a, counted(1)), Cache.fetch(:a, counted(1)), Cache.fetch(:b, counted(2))]
      end)

    assert result == [1, 1, 2]
    assert map_size(cache) == 2
    assert_received {:called, 1}
    refute_received {:called, 1}
    assert_received {:called, 2}
  end

  test "a run takes the values of the run before, and keeps only the keys that it used" do
    {_result, cache} =
      Cache.run(%{}, fn -> {Cache.fetch(:a, counted(1)), Cache.fetch(:b, counted(2))} end)

    assert_received {:called, 1}
    assert_received {:called, 2}

    {result, cache} = Cache.run(cache, fn -> Cache.fetch(:a, counted(1)) end)
    assert result == 1
    refute_received {:called, 1}
    assert map_size(cache) == 1

    # The key :b left the cache, so its function runs again.
    {_result, _cache} = Cache.run(cache, fn -> Cache.fetch(:b, counted(2)) end)
    assert_received {:called, 2}
  end

  test "run/2 restores the process after an error" do
    assert_raise RuntimeError, fn -> Cache.run(%{}, fn -> raise "render" end) end
    assert Cache.fetch(:key, counted(3)) == 3
    assert_received {:called, 3}
  end

  # A function of many keys that sends the keys of each call, so a test sees
  # which keys it made.
  defp many do
    test = self()

    fn keys ->
      send(test, {:made, keys})
      Enum.map(keys, &{:value, &1})
    end
  end

  describe "fetch_many/2" do
    test "outside run/2 calls the function with each key" do
      assert Cache.fetch_many([:a, :b], many()) == [value: :a, value: :b]
      assert_received {:made, [:a, :b]}
    end

    test "in a run calls the function one time with the missing keys, without a repeat" do
      {result, cache} =
        Cache.run(%{}, fn ->
          first = Cache.fetch_many([:a, :b, :a], many())
          second = Cache.fetch_many([:b, :c], many())
          {first, second}
        end)

      assert result == {[value: :a, value: :b, value: :a], [value: :b, value: :c]}
      assert_received {:made, [:a, :b]}
      assert_received {:made, [:c]}
      assert map_size(cache) == 3
    end

    test "takes the values of the run before, and calls no function when it has each key" do
      {_result, cache} = Cache.run(%{}, fn -> Cache.fetch_many([:a, :b], many()) end)
      assert_received {:made, [:a, :b]}

      {result, cache} = Cache.run(cache, fn -> Cache.fetch_many([:b], many()) end)
      assert result == [value: :b]
      refute_received {:made, _keys}
      assert map_size(cache) == 1
    end
  end
end
