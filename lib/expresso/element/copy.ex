defmodule Expresso.Element.Copy do
  @moduledoc """
  A copy of a part, which moves to a different place while the part stays

  The `copy` entity is inside a `part`. Its argument is the target: the id of
  an element of the SVG file of a diagram, or the name of a part of a
  formula. Its `at` option gives the steps
  that show the copy, and its `on` entities give the states of the copy. The
  `as` option gives the name of the copy. The default name is the id of the
  part, `@` and the target, such as `arg@hole1`.

  `expand/1` gives each copy its own `Expresso.Element.Part`. In a diagram,
  the render puts a copy of the element of the source after the source. In a
  formula, the render writes the copy as its own `math` element after the
  formula, and the presenter script puts it on its source. The copy then
  moves to its target with `move_to`. `docs/part-copies.md` gives the design.
  """

  alias Expresso.Element.{On, Part}

  @typedoc "The struct of a copy entity"
  @type t :: %__MODULE__{
          target: String.t(),
          as: String.t() | nil,
          at: Expresso.Overlay.t(),
          effect: atom() | nil,
          on: [On.t()]
        }

  defstruct [:target, :as, :at, :effect, on: [], __spark_metadata__: nil]

  @doc """
  Give each copy of a list of parts its own part

  The part of a copy follows the part of its source. It has the name of the
  copy as its `id`, the source in `copy_of` and the target in `copy_to`, and
  the `at`, `effect` and `on` of the copy. A `part` entity with the name of a
  copy adds its `on` entities, its `effect` and its copies to that copy, so a
  copy can have copies. A copy of a copy gets the target of its source in
  `copy_start`, because it fades in there.

  The function returns an error for a copy to its own part, for two parts or
  copies with the same name, for a part with the name of a copy and the `at`
  option, and for a loop of copies.

      iex> part = %Expresso.Element.Part{id: "arg", copies: [%Expresso.Element.Copy{target: "hole"}]}
      iex> {:ok, [_part, copy]} = Expresso.Element.Copy.expand([part])
      iex> {copy.id, copy.copy_of, copy.copy_to}
      {"arg@hole", "arg", "hole"}
  """
  @spec expand([Part.t()]) :: {:ok, [Part.t()]} | {:error, String.t()}
  def expand(parts) do
    with {:ok, parts} <- Shoddy.Result.collect(Enum.map(parts, &copy_to/1)),
         {:ok, trees} <- Shoddy.Result.collect(Enum.map(parts, &grow(&1, parts, []))) do
      # A part with the name of a copy is in the tree of that copy, so it does
      # not stand alone.
      copies = trees |> List.flatten() |> Enum.filter(& &1.copy_of) |> MapSet.new(& &1.id)
      parts = trees |> Enum.reject(&(hd(&1).id in copies)) |> List.flatten()

      with :ok <- no_copy_to_itself(parts), do: unique(parts)
    end
  end

  # A part, then the part of each of its copies with the copies of that copy.
  defp grow(%Part{id: id, copies: copies} = part, parts, path) do
    if id in path do
      {:error,
       "the copies of the part \"#{id}\" make a loop: " <>
         Enum.join(Enum.reverse([id | path]), ", ")}
    else
      (copies || [])
      |> Enum.map(&grow_copy(&1, part, parts, [id | path]))
      |> Shoddy.Result.collect()
      |> Shoddy.Result.map_ok(&[%Part{part | copies: []} | List.flatten(&1)])
    end
  end

  defp grow_copy(copy, part, parts, path) do
    with {:ok, copy} <- merge(part(copy, part), parts), do: grow(copy, parts, path)
  end

  # Add the `part` entity with the name of a copy to the part of the copy.
  defp merge(%Part{id: id} = copy, parts) do
    case Enum.find(parts, &(&1.id == id and &1.copy_of == nil)) do
      nil ->
        {:ok, copy}

      %Part{at: at} when at != nil ->
        {:error,
         "the part \"#{id}\" has the name of a copy, so it takes no at option. Give at to " <>
           "the copy"}

      %Part{on: on, copies: copies, effect: effect} ->
        {:ok,
         %Part{
           copy
           | on: copy.on ++ (on || []),
             copies: copies || [],
             effect: effect || copy.effect
         }}
    end
  end

  # Replace the `copy_to` of each `on` entity of a part with a `copy` entity
  # for each target. Each copy shows from the first step of the entity to the
  # last step of the slide. An `on` entity with no other option goes away.
  defp copy_to(%Part{on: on, copies: copies} = part) do
    {copy_tos, kept} = Enum.split_with(on || [], &((&1.copy_to || []) != []))

    with {:ok, made} <- Shoddy.Result.collect(Enum.map(copy_tos, &copies_of(&1, part))) do
      kept = kept ++ Enum.flat_map(copy_tos, &rest/1)
      {:ok, %Part{part | on: kept, copies: (copies || []) ++ List.flatten(made)}}
    end
  end

  defp copies_of(%On{at: %Expresso.Overlay{pairs: pairs}, copy_to: targets}, %Part{id: id}) do
    firsts = Enum.map(pairs, &elem(&1, 0))

    if Enum.all?(firsts, &is_integer/1) do
      at = %Expresso.Overlay{pairs: [{Enum.min(firsts), :max}]}
      {:ok, Enum.map(targets, &%__MODULE__{target: &1, at: at})}
    else
      {:error,
       "the on entity of the part \"#{id}\" has copy_to and :next. Give the step as a " <>
         "number, or use a copy entity with at: :next"}
    end
  end

  defp rest(%On{state: nil, set: nil, move_to: nil}), do: []
  defp rest(%On{} = on), do: [%On{on | copy_to: nil}]

  defp part(%__MODULE__{} = copy, %Part{id: id, effect: effect, copy_to: start}) do
    %Part{
      id: copy.as || "#{id}@#{copy.target}",
      copy_of: id,
      copy_to: copy.target,
      copy_start: start,
      at: copy.at,
      effect: copy.effect || effect,
      on: copy.on || []
    }
  end

  defp no_copy_to_itself(parts) do
    case Enum.find(parts, &(&1.copy_of != nil and &1.copy_of == &1.copy_to)) do
      nil -> :ok
      %Part{copy_of: id} -> {:error, "the part \"#{id}\" has a copy to itself"}
    end
  end

  defp unique(parts) do
    parts
    |> Enum.frequencies_by(& &1.id)
    |> Enum.find(fn {_id, count} -> count > 1 end)
    |> case do
      nil ->
        {:ok, parts}

      {id, _count} ->
        {:error,
         "two parts or copies have the name \"#{id}\". Give a copy a different name with " <>
           "the as option"}
    end
  end

  @doc """
  Give the part of each copy its move and the delay of that move

  The move is an `on` entity with `move_to` the target, at each step of the
  copy. A copy of a copy also moves to the target of its source before its
  first step. At the first step of the copy, the custom property `--move-delay`
  holds the time of the fade, so the copy fades in at its source and then
  moves. The render calls this function after the transformer gives each
  part its steps.
  """
  @spec moves(Part.t()) :: Part.t()
  def moves(%Part{copy_to: nil} = part), do: part

  def moves(%Part{copy_to: target, steps: [first | _] = steps, on: on} = part) do
    move = %On{steps: steps, move_to: target}
    delay = %On{steps: [first], set: ["move-delay": "var(--dur)"]}
    %Part{part | on: wait(part, first) ++ [move, delay | on || []]}
  end

  # Before its first step, a copy of a copy waits at the target of its
  # source, so it fades in there.
  defp wait(%Part{copy_start: start}, first) when is_binary(start) and first > 1,
    do: [%On{steps: Enum.to_list(1..(first - 1)), move_to: start}]

  defp wait(_part, _first), do: []
end
