defmodule Expresso.Presenter.SchemaTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Expresso.Builder
  alias Expresso.Presenter.{Definition, Program, Schema}
  alias Expresso.Presenter.Schema.Check
  alias Expresso.Test.{DeckTree, SchemaWriter}

  doctest Expresso.Presenter.Schema
  doctest Expresso.Presenter.Schema.Check

  # `Expresso.Test.SchemaWriter` tells how to write the file again.
  test "assets/src/schema.ts agrees with the forms of the schema" do
    written = SchemaWriter.typescript()

    if System.get_env("EXPRESSO_SCHEMA") == "write" do
      File.write!(SchemaWriter.path(), written)
    end

    assert File.read!(SchemaWriter.path()) == written, """
    #{SchemaWriter.path()} is not current. Write it again:

        EXPRESSO_SCHEMA=write mix test test/expresso/presenter/schema_test.exs
    """
  end

  # A deck of 0 to 8 slides with 1 to 5 steps each, a transition for some
  # slides, and some of the options of the deck.
  defp deck do
    gen all slides <-
              list_of(
                tuple({integer(1..5), one_of([constant(nil), member_of(Schema.transitions())])}),
                max_length: 8
              ),
            duration <- one_of([constant(nil), integer(1..90)]),
            progress <- boolean() do
      slides
      |> Enum.with_index(1)
      |> Enum.map(fn {{steps, transition}, number} ->
        Builder.slide(
          "slide #{number}",
          [steps: steps] ++ for(t <- [transition], t, do: {:transition, t})
        )
      end)
      |> Builder.deck(
        for({key, value} <- [duration: duration], value, do: {key, value}) ++ [progress: progress]
      )
    end
  end

  defp written(deck) do
    program = Program.compile(Definition.presenter(), deck)
    {JSON.decode!(Program.json(program)), JSON.decode!(Expresso.Steps.json(deck))}
  end

  property "the program and the list of the steps of each deck agree with the schema" do
    check all deck <- deck() do
      {program, steps} = written(deck)

      assert Check.check(program, :written_program) == :ok
      assert Check.check(steps, :written_deck) == :ok
    end
  end

  property "a deck with overlays, pauses and links agrees with the schema" do
    check all slides <- DeckTree.slides(), max_runs: 50 do
      {program, steps} = written(DeckTree.builder([name: "deck"], slides))

      assert Check.check(program, :written_program) == :ok
      assert Check.check(steps, :written_deck) == :ok
    end
  end

  property "the commands of a page of the overview and of a link agree with the schema" do
    check all slide <- integer(1..100), index <- integer(0..100) do
      for commands <- [Program.element(slide), Program.link(index)] do
        value = commands |> Program.json_commands() |> JSON.decode!()
        assert Check.check(value, :commands) == :ok
      end
    end
  end

  test "each form names only the forms before it" do
    Enum.reduce(Schema.types(), MapSet.new(), fn {name, _doc, form}, known ->
      for ref <- refs(form), do: assert(ref in known, "#{name} names #{ref} before its form")
      MapSet.put(known, name)
    end)
  end

  test "check refuses a value that does not agree, and names its path" do
    {program, steps} = written(Builder.deck([Builder.slide("one")]))

    assert {:error, "$.state.view: expected view"} =
             Check.check(put_in(program, ["state", "view"], "stage"), :written_program)

    assert {:error, "$.state.extra: expected no such key"} =
             Check.check(put_in(program, ["state", "extra"], 1), :written_program)

    assert {:error, "$.modes[0].any[0]: expected command"} =
             Check.check(
               put_in(program, ["modes", Access.at(0), "any"], [["toggle", "digits"]]),
               :written_program
             )

    assert {:error, "$.steps[0][2]: expected {:number, 0, 1}"} =
             Check.check(
               update_in(steps, ["steps", Access.at(0)], &List.replace_at(&1, 2, 2)),
               :written_deck
             )
  end

  test "a message can hold other keys, its time must be a number, its scheme a variant or null, and its fields the kinds of the state" do
    message = %{
      "expresso" => "position",
      "slide" => 2,
      "step" => 1,
      "fields" => %{"blank" => false, "undim" => false},
      "scheme" => nil,
      "time" => 5
    }

    assert Check.check(Map.put(message, "from", "x"), :message) == :ok
    assert Check.check(%{message | "scheme" => "dark"}, :message) == :ok
    assert {:error, _message} = Check.check(%{message | "time" => "5"}, :message)
    assert {:error, _message} = Check.check(%{message | "scheme" => "sepia"}, :message)
    assert {:error, _message} = Check.check(Map.delete(message, "scheme"), :message)
    assert {:error, _message} = Check.check(put_in(message, ["fields", "blank"], 1), :message)
  end

  defp refs({:ref, name}), do: [name]
  defp refs({_kind, types}) when is_list(types), do: Enum.flat_map(types, &refs/1)
  defp refs({:nullable, type}), do: refs(type)
  defp refs({:list, type}), do: refs(type)
  # A field of an object: its key and its form.
  defp refs({_key, type}) when is_tuple(type), do: refs(type)
  defp refs(_type), do: []
end
