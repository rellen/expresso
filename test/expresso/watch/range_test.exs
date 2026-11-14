defmodule Expresso.Watch.RangeTest do
  use ExUnit.Case, async: true

  doctest Expresso.Watch.Range

  alias Expresso.Watch.Range

  test "range/2 takes spaces around the unit and the numbers" do
    assert Range.range(" bytes = 2-5 ", 10) == {:ok, {2, 5}}
  end

  test "range/2 gives the whole file for the last bytes of a short file" do
    assert Range.range("bytes=-99", 10) == {:ok, {0, 9}}
  end

  test "range/2 refuses a range of an empty file, and a header with no number" do
    assert Range.range("bytes=0-", 0) == :error
    assert Range.range("bytes=-4", 0) == :error
    assert Range.range("bytes=-0", 10) == :error
    assert Range.range("bytes=-", 10) == :error
    assert Range.range("bytes", 10) == :error
  end
end
