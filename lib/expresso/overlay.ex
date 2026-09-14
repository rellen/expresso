defmodule Expresso.Overlay do
  @moduledoc """
  An overlay specification, which tells the compiler which steps show an element

  A specification is an Elixir term. `new/1` accepts each form and puts it
  into this struct. The struct holds one pair for each item of the term: the
  first step and the last step. In a pair, `:next` stands for the counter of the
  slide, and `:max` stands for the maximum step number of the slide. The
  transformer resolves both with `resolve_next/2` and `steps/2`.

  `docs/overlays.md` gives the forms and the rules.
  """

  @typedoc "The first step of a pair"
  @type first :: pos_integer() | :next

  @typedoc "The last step of a pair"
  @type last :: pos_integer() | :next | :max

  @typedoc "One item of a specification"
  @type pair :: {first(), last()}

  @typedoc "The struct of a specification"
  @type t :: %__MODULE__{pairs: [pair()]}

  defstruct pairs: []

  @forms """
  an integer, a range, :next, or a list of those and of from: items, \
  such as 3, 2..4, [2, 5..7], [from: 2], :next, [from: :next] or [2, from: 5]\
  """

  @doc """
  Make a specification from a term

  This function is the custom type of the `at` option and of the `on` entity.
  It accepts a struct, a positive integer, a range with a step of 1, `:next`,
  or a list of those and of `from:` items. A different term gives an error
  tuple with a message that lists the forms.
  """
  @spec new(term()) :: {:ok, t()} | {:error, String.t()}
  def new(%__MODULE__{} = overlay), do: {:ok, overlay}
  def new([]), do: {:error, "an overlay specification cannot be an empty list"}

  def new(items) when is_list(items) do
    items
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, pairs} ->
      case pair(item) do
        {:ok, pair} -> {:cont, {:ok, [pair | pairs]}}
        {:error, message} -> {:halt, {:error, message}}
      end
    end)
    |> case do
      {:ok, pairs} -> {:ok, %__MODULE__{pairs: Enum.reverse(pairs)}}
      {:error, message} -> {:error, message}
    end
  end

  def new(term) do
    case pair(term) do
      {:ok, pair} -> {:ok, %__MODULE__{pairs: [pair]}}
      {:error, message} -> {:error, message}
    end
  end

  defp pair(step) when is_integer(step) and step >= 1, do: {:ok, {step, step}}
  defp pair(:next), do: {:ok, {:next, :next}}
  defp pair({:from, step}) when is_integer(step) and step >= 1, do: {:ok, {step, :max}}
  defp pair({:from, :next}), do: {:ok, {:next, :max}}

  defp pair(first..last//1 = range) when first >= 1 and first <= last do
    _ = range
    {:ok, {first, last}}
  end

  defp pair(first..last//step) do
    {:error,
     "the range #{first}..#{last}//#{step} is not valid in an overlay specification: " <>
       "a range goes up with a step of 1 from a step of 1 or more"}
  end

  defp pair(term) do
    {:error, "#{inspect(term)} is not an overlay specification: expected #{@forms}"}
  end

  @doc """
  Replace each `:next` with the value of the counter

  Each `:next` in one specification takes the same value. The function
  increments the counter one time when the specification holds a `:next`, and
  it returns the counter unchanged otherwise. This is the rule of `+` in Beamer.
  """
  @spec resolve_next(t(), pos_integer()) :: {t(), pos_integer()}
  def resolve_next(%__MODULE__{pairs: pairs} = overlay, counter) do
    if Enum.any?(pairs, &has_next?/1) do
      resolved =
        Enum.map(pairs, fn {first, last} -> {put(first, counter), put(last, counter)} end)

      {%__MODULE__{overlay | pairs: resolved}, counter + 1}
    else
      {overlay, counter}
    end
  end

  defp has_next?({first, last}), do: first == :next or last == :next
  defp put(:next, counter), do: counter
  defp put(bound, _counter), do: bound

  @doc """
  Give the largest explicit step number of a specification

  The function ignores `:max`, and it gives `nil` for a specification with no
  explicit step. Call `resolve_next/2` first, because a `:next` is not an
  explicit step.
  """
  @spec max_step(t()) :: pos_integer() | nil
  def max_step(%__MODULE__{pairs: pairs}) do
    pairs
    |> Enum.flat_map(fn {first, last} -> [first, last] end)
    |> Enum.filter(&is_integer/1)
    |> Enum.max(fn -> nil end)
  end

  @doc """
  Give the step numbers of a specification, with `max` as the maximum step

  The function replaces each `:max` with `max`, and it gives the steps in order
  with no repeat. It gives an error when a step is more than `max`, or when a
  specification holds a `:next`. Call `resolve_next/2` first.
  """
  @spec steps(t(), pos_integer()) :: {:ok, [pos_integer()]} | {:error, String.t()}
  def steps(%__MODULE__{pairs: pairs}, max) when is_integer(max) and max >= 1 do
    Enum.reduce_while(pairs, {:ok, []}, fn
      {first, last}, _acc when first == :next or last == :next ->
        {:halt, {:error, "the specification holds :next, and the counter did not resolve it"}}

      {first, last}, {:ok, acc} ->
        last = if last == :max, do: max, else: last

        cond do
          first > max ->
            {:halt, {:error, "the step #{first} is more than the maximum step #{max}"}}

          last > max ->
            {:halt, {:error, "the step #{last} is more than the maximum step #{max}"}}

          true ->
            {:cont, {:ok, acc ++ Enum.to_list(first..last//1)}}
        end
    end)
    |> case do
      {:ok, steps} -> {:ok, steps |> Enum.uniq() |> Enum.sort()}
      {:error, message} -> {:error, message}
    end
  end
end
