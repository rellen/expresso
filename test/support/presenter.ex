defmodule Expresso.Test.Presenter do
  @moduledoc """
  Makes programs and states for the tests of the presenter model

  A test gives the number of steps for each slide, and `program/2` makes the
  program of such a deck from `Expresso.Presenter.Definition.presenter/0`.
  """

  import ExUnit.Assertions

  alias Expresso.Presenter.{Definition, Interpreter, Program}

  @doc "Return the program of a deck from the number of steps and the kind of each slide"
  @spec program([pos_integer()], [atom()]) :: Program.t()
  def program(counts, kinds \\ []) do
    counts
    |> Enum.with_index()
    |> Enum.reduce(Expresso.Deck.new("deck"), fn {steps, index}, deck ->
      metadata = %{max_step: steps, transition: Enum.at(kinds, index)}
      Expresso.Deck.add_slide(deck, "slide #{index + 1}", metadata, [])
    end)
    |> then(&Program.compile(Definition.presenter(), &1))
  end

  @doc "Return the state at a slide and a step, with no black screen and no digits"
  @spec at(Program.t(), pos_integer(), pos_integer(), atom()) :: Interpreter.state()
  def at(program, slide, step, view \\ :present) do
    index =
      Enum.find_index(Tuple.to_list(program.steps), &(&1 == {slide, step})) ||
        flunk("the deck has no step #{slide}.#{step}")

    Interpreter.initial(program, %{index: index, view: view})
  end

  @doc "Return the state after one event"
  @spec run(Program.t(), Interpreter.state(), Interpreter.event()) :: Interpreter.state()
  def run(program, state, event) do
    {state, _effects} = Interpreter.run(program, state, event)
    state
  end

  @doc "Return the state after each key, in sequence"
  @spec keys(Program.t(), Interpreter.state(), [String.t()]) :: Interpreter.state()
  def keys(program, state, keys), do: Enum.reduce(keys, state, &run(program, &2, {:key, &1}))

  @doc "Return the slide and the step of a state"
  @spec where(Program.t(), Interpreter.state()) :: {pos_integer(), pos_integer()}
  def where(program, state), do: Interpreter.entry(program, state) || flunk("no entry")
end
