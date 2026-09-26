defmodule Expresso.Test.Overlay do
  @moduledoc """
  Generators of overlay specifications for the property tests

  `item/0` makes one item of each form of `docs/overlays.md`: an integer, a
  range, `:next`, `from: n` and `from: :next`. `spec/0` makes a specification,
  which is one item or a list of items, and `relative_spec/0` makes one with a
  `:next`. `invalid/0` makes a term that `Expresso.Overlay.new/1` refuses. The
  steps stay small, so a maximum step from `max/0` is sometimes less than a
  step and sometimes more.
  """

  import StreamData

  @spec step() :: StreamData.t(pos_integer())
  def step, do: integer(1..12)

  @spec max() :: StreamData.t(pos_integer())
  def max, do: integer(1..15)

  @spec item() :: StreamData.t(term())
  def item do
    one_of([
      step(),
      map({step(), integer(0..4)}, fn {first, length} -> first..(first + length) end),
      constant(:next),
      map(step(), &{:from, &1}),
      constant({:from, :next})
    ])
  end

  @spec spec() :: StreamData.t(term())
  def spec, do: one_of([item(), list_of(item(), min_length: 1, max_length: 4)])

  @spec absolute_spec() :: StreamData.t(term())
  def absolute_spec do
    filter(spec(), fn term -> not Enum.any?(List.wrap(term), &(&1 in [:next, {:from, :next}])) end)
  end

  @spec relative_spec() :: StreamData.t(term())
  def relative_spec do
    map({spec(), member_of([:next, {:from, :next}])}, fn {spec, next} ->
      List.wrap(spec) ++ [next]
    end)
  end

  @spec invalid() :: StreamData.t(term())
  def invalid do
    one_of([
      integer(-5..0),
      map(integer(-5..0), &{:from, &1}),
      map({step(), integer(1..4)}, fn {last, down} -> (last + down)..last//-1 end),
      map({step(), integer(2..3)}, fn {first, by} -> first..(first + 6)//by end),
      string(:alphanumeric, min_length: 1),
      float(),
      constant([]),
      map(list_of(step(), max_length: 2), &(&1 ++ [:last]))
    ])
  end
end
