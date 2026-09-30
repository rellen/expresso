defmodule Expresso.Presenter.InterpreterPropertyTest do
  # The properties of `assets/test/state_property.test.ts`, on the model. The
  # properties of `accepts`, `stamp`, `side` and `swipe` stay in TypeScript,
  # because the model does not hold that code.
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Expresso.Test.Presenter, only: [program: 2, run: 3, where: 2]

  alias Expresso.Presenter.{Interpreter, Program}

  # The number of runs of each property, as in the TypeScript tests.
  @runs 500

  @kinds [:none, :fade, :slide, :zoom]
  @forward ["j", "ArrowRight", "ArrowDown", "PageDown", " "]
  @digits Enum.map(0..9, &Integer.to_string/1)
  @keys ~w(j k ArrowRight ArrowLeft ArrowUp ArrowDown PageDown PageUp Home End Enter b p s r f g a o ? Escape) ++
          [" "] ++ @digits

  # A deck of 1 to 12 slides, each with 1 to 6 steps and a kind of transition.
  defp decks do
    gen all slides <-
              list_of(tuple({integer(1..6), member_of(@kinds)}), min_length: 1, max_length: 12) do
      {counts, kinds} = Enum.unzip(slides)
      program(counts, kinds)
    end
  end

  # Each key of the definition, and some keys with no binding.
  defp key do
    frequency([{9, member_of(@keys)}, {1, member_of(["x", "Tab", "F5", "Shift"])}])
  end

  # A number of a slide or a step, inside and outside the deck.
  defp near(maximum), do: integer(-1..(maximum + 2))

  defp slides(program), do: tuple_size(program.slides)

  defp fragment(program) do
    one_of([
      string(:printable, max_length: 6),
      map(near(slides(program)), &"##{&1}"),
      map(tuple({near(slides(program)), near(6)}), fn {slide, step} -> "##{slide}.#{step}" end)
    ])
  end

  defp message(program) do
    gen all slide <- near(slides(program)), step <- near(6), blank <- boolean() do
      {:message, %{slide: slide, step: step, blank: blank}}
    end
  end

  defp event(program) do
    frequency([
      {12, map(key(), &{:key, &1})},
      {1, map(member_of([:right, :left_third]), &{:click, &1})},
      {1, map(member_of([:left, :right]), &{:swipe, &1})},
      {1, map(near(slides(program)), fn slide -> {:click, :right, Program.element(slide)} end)},
      {1, map(fragment(program), &{:hash, &1})},
      {1, message(program)}
    ])
  end

  # A state that the presenter can get to in a deck: the first state of the
  # present view or of the speaker view, after 0 to 60 events.
  defp state_in(program) do
    gen all view <- member_of([:present, :speaker]),
            events <- list_of(event(program), max_length: 60) do
      Enum.reduce(events, Interpreter.initial(program, %{view: view}), &run(program, &2, &1))
    end
  end

  defp reachable do
    gen(all program <- decks(), state <- state_in(program), do: {program, state})
  end

  # A reachable state with no black screen and no list of keys.
  defp shown do
    map(reachable(), fn {program, state} -> {program, %{state | blank: false, help: false}} end)
  end

  defp upcoming_all(program, state) do
    state
    |> Stream.iterate(&Interpreter.upcoming(program, &1))
    |> Enum.take_while(& &1)
  end

  property "a reachable state stays inside the deck" do
    check all {program, state} <- reachable(), max_runs: @runs do
      assert state.index in 0..(tuple_size(program.steps) - 1)
      assert state.selected in 1..slides(program)
      assert state.digits =~ ~r/^\d*$/
    end
  end

  property "upcoming goes through each step of the deck one time, in sequence" do
    check all program <- decks(), max_runs: @runs do
      indexes = program |> upcoming_all(Interpreter.initial(program)) |> Enum.map(& &1.index)
      assert indexes == Enum.to_list(0..(tuple_size(program.steps) - 1))
    end
  end

  property "a forward key and then k give the same step, and a forward key that gives the same state is the end" do
    check all {program, state} <- shown(),
              key <- member_of(@forward),
              max_runs: @runs do
      state = %{state | view: :present, overview: false, digits: ""}
      ahead = run(program, state, {:key, key})

      if ahead == state do
        assert Interpreter.upcoming(program, state) == nil
      else
        assert run(program, ahead, {:key, "k"}).index == state.index
      end
    end
  end

  property "upcoming is nil only at the last step of the last slide" do
    check all {program, state} <- reachable(), max_runs: @runs do
      last = state.index == tuple_size(program.steps) - 1
      assert Interpreter.upcoming(program, state) == nil == last
    end
  end

  property "the fragment of a state gives the step of the state" do
    check all {program, state} <- reachable(), max_runs: @runs do
      read = run(program, Interpreter.initial(program), {:hash, Interpreter.hash(program, state)})
      assert read.index == state.index
    end
  end

  property "a fragment gives a slide and a step of the deck, and other fragments give the same state" do
    check all program <- decks(),
              state <- state_in(program),
              hash <- fragment(program),
              max_runs: @runs do
      read = run(program, state, {:hash, hash})

      inside =
        case Regex.run(~r/^#(\d+)(?:\.(\d+))?$/, hash) do
          [_all, slide] -> {String.to_integer(slide), 1}
          [_all, slide, step] -> {String.to_integer(slide), String.to_integer(step)}
          nil -> nil
        end

      if inside in Tuple.to_list(program.steps) do
        assert where(program, read) == inside
      else
        assert read == state
      end
    end
  end

  property "a message of a state gives the step and the black screen of the state" do
    check all program <- decks(),
              sender <- state_in(program),
              receiver <- state_in(program),
              max_runs: @runs do
      {slide, step} = where(program, sender)
      message = {:message, %{slide: slide, step: step, blank: sender.blank}}
      read = run(program, receiver, message)
      assert {read.index, read.blank} == {sender.index, sender.blank}
    end
  end

  property "a message with a slide and a step that the deck does not have gives the same state" do
    check all program <- decks(),
              state <- state_in(program),
              {:message, data} = message <- message(program),
              max_runs: @runs do
      if {data.slide, data.step} not in Tuple.to_list(program.steps) do
        assert run(program, state, message) == state
      end
    end
  end

  property "the slide with the higher number gives the kind of a transition in the two directions" do
    check all program <- decks(),
              a <- state_in(program),
              b <- state_in(program),
              max_runs: @runs do
      there = Interpreter.transition(program, a, b)
      back = Interpreter.transition(program, b, a)

      if there && back do
        {from, _step} = where(program, a)
        {to, _step} = where(program, b)
        higher = elem(program.slides, max(from, to) - 1).transition

        assert there.kind == higher
        assert back.kind == higher
        assert there.direction != back.direction
        assert there.direction == if(to > from, do: :forward, else: :back)
      else
        assert there == back
      end
    end
  end

  property "a change of the slide in the present view with no black screen, overview or list of keys has a transition, except the kind none" do
    check all program <- decks(),
              a <- state_in(program),
              b <- state_in(program),
              max_runs: @runs do
      quiet? = fn state ->
        state.view != :present or state.blank or state.overview or state.help
      end

      {from, _step} = where(program, a)
      {to, _step} = where(program, b)
      kind = elem(program.slides, max(from, to) - 1).transition
      moves = from != to and not quiet?.(a) and not quiet?.(b) and kind != "none"

      assert Interpreter.transition(program, a, b) != nil == moves
    end
  end

  property "a key that no binding of the mode has gives the same state" do
    check all {program, state} <- shown(), key <- key(), max_runs: @runs do
      state = %{state | digits: ""}

      mode =
        Enum.find(program.modes, fn mode ->
          Enum.all?(mode.when, fn {k, v} -> state[k] == v end)
        end)

      if not Map.has_key?(mode.keys, key) do
        assert Interpreter.run(program, state, {:key, key}) == {state, []}
      end
    end
  end

  property "on a black screen or on the list of keys, each key and each click closes it, and does nothing more" do
    check all {program, state} <- shown(),
              cover <- member_of([:blank, :help]),
              event <-
                one_of([
                  map(key(), &{:key, &1}),
                  constant({:click, :right}),
                  constant({:swipe, :right})
                ]),
              max_runs: @runs do
      assert Interpreter.run(program, %{state | cover => true}, event) == {state, []}
    end
  end

  property "a digit adds to the slide number, Enter goes to step 1 of that slide, and each other key removes the digits" do
    check all {program, state} <- shown(),
              view <- member_of([:present, :speaker]),
              digits <- map(list_of(member_of(@digits), max_length: 3), &Enum.join/1),
              key <- key(),
              max_runs: @runs do
      typing = %{state | view: view, overview: false, digits: digits}
      after_key = run(program, typing, {:key, key})

      cond do
        key in @digits ->
          assert after_key.digits == digits <> key

        # The key `r` of the speaker view keeps the digits today.
        key == "r" and view == :speaker ->
          assert after_key.digits == digits

        key == "Enter" ->
          assert after_key.digits == ""
          target = if digits != "", do: {String.to_integer(digits), 1}

          if target in Tuple.to_list(program.steps) do
            assert where(program, after_key) == target
          else
            assert after_key.index == state.index
          end

        true ->
          assert after_key.digits == ""
      end
    end
  end

  property "in the overview, o and Escape close it with the same step, and Enter goes to step 1 of the selected slide" do
    check all {program, state} <- shown(),
              selected <- integer(1..slides(program)),
              max_runs: @runs do
      state = %{state | overview: true, selected: selected}

      for key <- ["o", "Escape"] do
        assert run(program, state, {:key, key}) == %{state | overview: false}
      end

      picked = run(program, state, {:key, "Enter"})
      assert picked.overview == false
      assert where(program, picked) == {selected, 1}
    end
  end

  property "a click on a page of the overview goes to step 1 of its slide, and for a number that is not a slide it only closes the overview" do
    check all {program, state} <- shown(),
              slide <- integer(-2..(slides(program) + 2)),
              max_runs: @runs do
      state = %{state | overview: true}
      chosen = run(program, state, {:click, :right, Program.element(slide)})

      if {slide, 1} in Tuple.to_list(program.steps) do
        assert %{chosen | index: state.index} == %{state | overview: false}
        assert where(program, chosen) == {slide, 1}
      else
        assert chosen == %{state | overview: false}
      end
    end
  end

  property "a click, a tap or a swipe in the handout view or in the overview gives the same state" do
    check all {program, state} <- shown(),
              where <- member_of([:handout, :overview]),
              event <-
                member_of([
                  {:click, :right},
                  {:click, :left_third},
                  {:swipe, :left},
                  {:swipe, :right}
                ]),
              max_runs: @runs do
      still =
        if where == :handout,
          do: %{state | view: :handout, overview: false},
          else: %{state | overview: true}

      assert run(program, still, event) == still
    end
  end

  property "columns gives the smallest number of columns with as many rows as columns or fewer" do
    check all slides <- integer(1..100_000), max_runs: @runs do
      width = Program.columns(slides)
      assert width * width >= slides
      assert width == 1 or (width - 1) * (width - 1) < slides
    end
  end
end
