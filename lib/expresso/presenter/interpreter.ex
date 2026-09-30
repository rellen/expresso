defmodule Expresso.Presenter.Interpreter do
  @moduledoc """
  Runs the program of the presenter on a state

  This module is the reference interpreter that
  `docs/research/elixir-presenter-report.md` describes in its section "The
  interpreter". Each function is pure: it takes a state and an event, and it
  returns the next state. Thus the tests of the presenter behavior need no
  browser.

  `run/3` does the first three steps that the interpreter in the browser does:

    1. It finds the first mode whose condition the state matches.
    2. It finds the commands of the event in that mode.
    3. It applies the commands to the state, one after the other.

  The result holds the new state and the built-in functions to call, such as
  `:open_speaker`. `prevented?/3` tells if the browser must not use the event:
  that is true when the state changes or a built-in function runs. A key that
  changes nothing goes to the browser, so the arrow keys still scroll the pages
  of the handout view.

  The fragment of the address and the messages between the two windows do not
  go through the modes. They go to a slide and a step of the deck directly.
  """

  alias Expresso.Presenter.Program

  @typedoc "The state of the presenter. `Expresso.Presenter.Definition` declares the fields."
  @type state :: %{atom() => term()}

  @typedoc """
  An event

  A click can hold the commands of the element under it, such as a page of the
  overview. A message holds the slide, the step and the black screen of the
  other window, and the script already made sure of their types.
  """
  @type event ::
          {:key, String.t()}
          | {:click, :left_third | :right}
          | {:click, :left_third | :right, [term()] | nil}
          | {:swipe, :left | :right}
          | {:hash, String.t()}
          | {:message, %{slide: integer(), step: integer(), blank: boolean()}}

  @typedoc "The kind and the direction of a transition"
  @type transition :: %{kind: String.t(), direction: :forward | :back}

  @doc """
  Return the first state of a program, with some fields replaced

  The script replaces the view for the speaker view, `progress` from the deck
  and `every` from the address.
  """
  @spec initial(Program.t(), map()) :: state()
  def initial(program, fields \\ %{}), do: Map.merge(program.state, fields)

  @doc """
  Apply one event to a state

  Returns the new state and the built-in functions that the event calls, in
  sequence.
  """
  @spec run(Program.t(), state(), event()) :: {state(), [atom()]}
  def run(program, state, {:hash, fragment}) do
    case Regex.run(~r/^#(\d+)(?:\.(\d+))?$/, fragment) do
      [_all, slide] -> {position(program, state, number(slide), 1, false), []}
      [_all, slide, step] -> {position(program, state, number(slide), number(step), false), []}
      nil -> {state, []}
    end
  end

  def run(program, state, {:message, %{slide: slide, step: step, blank: blank}}),
    do: {position(program, state, slide, step, blank), []}

  def run(program, state, {:click, region}), do: run(program, state, {:click, region, nil})

  def run(program, state, event) do
    case Enum.find(program.modes, &matches?(&1.when, state)) do
      nil ->
        {state, []}

      mode ->
        mode
        |> commands(event)
        |> Enum.reduce({state, []}, &apply_command(program, event, &1, &2))
    end
  end

  @doc """
  Tell if the browser must not use an event

  The result is true when the state changed or the event called a built-in
  function.
  """
  @spec prevented?(state(), state(), [atom()]) :: boolean()
  def prevented?(before, after_event, effects), do: after_event != before or effects != []

  @doc """
  Return the slide and the step of the current state, or nil for a deck with no slide
  """
  @spec entry(Program.t(), state()) :: {pos_integer(), pos_integer()} | nil
  def entry(program, state) do
    if state.index < tuple_size(program.steps), do: elem(program.steps, state.index)
  end

  @doc """
  Return the fragment of the address for a state, such as `#4.2`

  For a deck with no slide, the function returns `#1.1`.
  """
  @spec hash(Program.t(), state()) :: String.t()
  def hash(program, state) do
    {slide, step} = entry(program, state) || {1, 1}
    "##{slide}.#{step}"
  end

  @doc """
  Return the state at the next step, or nil at the last step of the deck

  The speaker view shows this step as the next step.
  """
  @spec upcoming(Program.t(), state()) :: state() | nil
  def upcoming(program, state) do
    after_step = step(program, state, 1)
    if after_step != state, do: after_step
  end

  @doc """
  Return the transition between two states, or nil

  Only a move to a different slide in the present view has a transition. In
  the two directions, the kind comes from the slide with the higher number. The
  kind `"none"` has no transition.
  """
  @spec transition(Program.t(), state(), state()) :: transition() | nil
  def transition(program, before, after_event) do
    from = slide(program, before)
    to = slide(program, after_event)

    with false <- from == to or quiet?(before) or quiet?(after_event),
         kind when kind != "none" <- kind(program, max(from, to)) do
      %{kind: kind, direction: if(to > from, do: :forward, else: :back)}
    else
      _no_transition -> nil
    end
  end

  defp quiet?(state), do: state.view != :present or state.blank or state.overview or state.help

  defp kind(program, slide) do
    if slide <= tuple_size(program.slides),
      do: elem(program.slides, slide - 1).transition,
      else: "fade"
  end

  defp matches?(condition, state),
    do: Enum.all?(condition, fn {key, value} -> state[key] == value end)

  defp commands(%{any: any}, _event) when is_list(any), do: any
  defp commands(mode, {:key, key}), do: Map.get(mode.keys, key) || mode.other || []
  defp commands(%{element: true}, {:click, _region, element}) when is_list(element), do: element
  defp commands(mode, {:click, region, _element}), do: Map.get(mode.click, region, [])
  defp commands(mode, {:swipe, direction}), do: Map.get(mode.swipe, direction, [])

  defp apply_command(_program, _event, {:builtin, name}, {state, effects}),
    do: {state, effects ++ [name]}

  defp apply_command(program, event, command, {state, effects}),
    do: {command(program, event, command, state), effects}

  defp command(_program, _event, {:set, field, value}, state), do: %{state | field => value}

  defp command(_program, _event, {:toggle, field}, state),
    do: %{state | field => not state[field]}

  defp command(program, _event, {:clear, field}, state),
    do: %{state | field => program.state[field]}

  defp command(program, _event, {:assign, :selected, {:entry, :slide}}, state),
    do: %{state | selected: slide(program, state)}

  defp command(_program, {:key, key}, {:append, :digits}, state),
    do: %{state | digits: state.digits <> key}

  defp command(program, _event, {:step, by}, state), do: step(program, state, by)
  defp command(program, _event, {:goto, index}, state), do: goto(program, state, index)

  defp command(program, _event, {:goto_slide, :selected}, state),
    do: goto_slide(program, state, state.selected)

  defp command(program, _event, {:goto_slide, slide}, state),
    do: goto_slide(program, state, slide)

  defp command(program, _event, {:select, slide}, state), do: select(program, state, slide)

  defp command(program, _event, {:select_by, by}, state),
    do: select(program, state, state.selected + by)

  defp command(_program, _event, :go_typed, %{digits: ""} = state), do: state

  defp command(program, _event, :go_typed, state),
    do: goto_slide(program, %{state | digits: ""}, number(state.digits))

  # A move past the first step or the last step makes no change.
  defp step(program, state, by), do: goto(program, state, state.index + by)

  defp goto(program, state, index)
       when is_integer(index) and index >= 0 and index < tuple_size(program.steps),
       do: %{state | index: index}

  defp goto(_program, state, _index), do: state

  defp goto_slide(program, state, slide) do
    case first_index(program, slide) do
      nil -> state
      index -> %{state | index: index}
    end
  end

  # A slide outside the deck makes no change.
  defp select(program, state, slide) when slide >= 1 and slide <= tuple_size(program.slides),
    do: %{state | selected: slide}

  defp select(_program, state, _slide), do: state

  # Go to a slide and a step, and set the black screen. A slide and a step that
  # the deck does not have make no change, and the current position also makes
  # no change.
  defp position(program, state, slide, step, blank) do
    case index_of(program, slide, step) do
      nil -> state
      index when index == state.index and blank == state.blank -> state
      index -> %{state | index: index, blank: blank, digits: ""}
    end
  end

  defp first_index(program, slide), do: index_of(program, slide, 1)

  defp index_of(program, slide, step) do
    if slide >= 1 and slide <= tuple_size(program.slides) do
      %{first: first, steps: steps} = elem(program.slides, slide - 1)
      if step >= 1 and step <= steps, do: first + step - 1
    end
  end

  defp slide(program, state) do
    case entry(program, state) do
      {slide, _step} -> slide
      nil -> 1
    end
  end

  defp number(digits), do: String.to_integer(digits)
end
