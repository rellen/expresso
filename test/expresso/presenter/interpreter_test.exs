defmodule Expresso.Presenter.InterpreterTest do
  # The tests of `assets/test/state.test.ts`, on the model. The tests of the
  # messages between the windows (`message`, `isMessage`, `stamp` and
  # `accepts`) and of the sources of events (`side` and `swipe`) stay in
  # TypeScript, because the model does not hold that code.
  use ExUnit.Case, async: true

  import Expresso.Test.Presenter, only: [program: 1, program: 2, run: 3]

  alias Expresso.Presenter.{Interpreter, Program}
  alias Expresso.Test.Presenter, as: Model

  # Three slides. Slide 2 has three steps, and slide 3 has two steps.
  @three program([1, 3, 2])

  defp at(slide, step, view \\ :present), do: Model.at(@three, slide, step, view)
  defp key(state, key, program \\ @three), do: run(program, state, {:key, key})
  defp keys(state, keys), do: Model.keys(@three, state, keys)

  defp effects(state, key, program \\ @three) do
    {after_key, effects} = Interpreter.run(program, state, {:key, key})
    {after_key, effects, Interpreter.prevented?(state, after_key, effects)}
  end

  describe "the steps" do
    test "the first state is slide 1, step 1, in the present view" do
      assert Interpreter.initial(@three) == at(1, 1)
    end

    test "entry gives the slide and the step, and nil for a deck with no slide" do
      assert Interpreter.entry(@three, at(2, 3)) == {2, 3}
      assert Interpreter.entry(program([]), Interpreter.initial(program([]))) == nil
    end

    test "j moves to the next step, and to the first step of the next slide after the last" do
      assert key(at(2, 1), "j") == at(2, 2)
      assert key(at(2, 3), "j") == at(3, 1)
      assert key(at(1, 1), "j") == at(2, 1)
    end

    test "j on the last step of the last slide gives the same state, and the key goes to the browser" do
      assert effects(at(3, 2), "j") == {at(3, 2), [], false}
    end

    test "k moves to the previous step, and to the last step of the previous slide at the first" do
      assert key(at(2, 3), "k") == at(2, 2)
      assert key(at(3, 1), "k") == at(2, 3)
      assert key(at(2, 1), "k") == at(1, 1)
      assert key(at(1, 1), "k") == at(1, 1)
    end

    test "the arrow keys, the space bar and the page keys move as j and k do" do
      for key <- ["ArrowRight", "ArrowDown", "PageDown", " "] do
        assert key(at(2, 3), key) == at(3, 1), key
      end

      for key <- ["ArrowLeft", "ArrowUp", "PageUp"] do
        assert key(at(3, 1), key) == at(2, 3), key
      end
    end

    test "Home goes to the first slide, and End goes to step 1 of the last slide" do
      assert key(at(2, 2), "Home") == at(1, 1)
      assert key(at(2, 2), "End") == at(3, 1)
      assert effects(at(1, 1), "Home") == {at(1, 1), [], false}
    end

    test "a deck with no slide stays at the first state" do
      empty = program([])
      state = Interpreter.initial(empty)

      for key <- ["j", "k", "Home", "End"] do
        assert key(state, key, empty) == state, key
      end
    end

    test "an unknown key gives the same state" do
      assert effects(at(2, 2), "x") == {at(2, 2), [], false}
    end

    test "upcoming gives the next step, and nil at the end of the deck" do
      assert @three |> Interpreter.upcoming(at(2, 2)) == at(2, 3)
      assert @three |> Interpreter.upcoming(at(2, 3)) == at(3, 1)
      assert @three |> Interpreter.upcoming(at(3, 2)) == nil
    end
  end

  describe "the views" do
    test "p changes to the handout view, and p again changes back" do
      handout = key(at(2, 2), "p")
      assert handout == at(2, 2, :handout)
      assert key(handout, "p") == at(2, 2)
    end

    test "j and k keep the handout view" do
      assert key(at(2, 1, :handout), "j") == at(2, 2, :handout)
      assert key(at(2, 2, :handout), "k") == at(2, 1, :handout)
    end

    test "the handout view does not know the other keys of the present view" do
      state = at(2, 2, :handout)

      for key <- ["ArrowRight", " ", "PageDown", "Home", "End", "b", "3", "Enter", "f", "o"] do
        assert effects(state, key) == {state, [], false}, key
      end
    end

    test "the speaker view knows the keys of the present view, but not p" do
      state = at(2, 2, :speaker)
      assert key(state, "j") == at(2, 3, :speaker)
      assert key(state, "b") == %{state | blank: true}
      assert key(state, "p") == state
    end

    test "g hides the progress bar in the present view, and g again shows it" do
      hidden = key(at(2, 2), "g")
      assert hidden == %{at(2, 2) | progress: false}
      assert key(hidden, "g") == at(2, 2)

      for view <- [:handout, :speaker] do
        assert key(at(2, 2, view), "g") == at(2, 2, view), inspect(view)
      end
    end

    test "a in the handout view shows every step, and a again shows the selection" do
      every = key(at(2, 2, :handout), "a")
      assert every == %{at(2, 2, :handout) | every: true}
      assert key(every, "a") == at(2, 2, :handout)

      for view <- [:present, :speaker] do
        assert key(at(2, 2, view), "a") == at(2, 2, view), inspect(view)
      end
    end
  end

  describe "the digits" do
    test "digits and Enter go to step 1 of that slide" do
      assert keys(at(1, 1), ["3", "Enter"]) == at(3, 1)
      assert keys(at(3, 2), ["0", "2", "Enter"]) == at(2, 1)
    end

    test "a digit adds to the digits, and does not move" do
      assert keys(at(1, 1), ["1", "2"]) == %{at(1, 1) | digits: "12"}
    end

    test "a number that is not a slide removes the digits, and the slide stays" do
      assert keys(at(2, 2), ["9", "Enter"]) == at(2, 2)
      assert keys(at(2, 2), ["0", "Enter"]) == at(2, 2)
    end

    test "Enter without digits gives the same state, and the key goes to the browser" do
      assert effects(at(2, 2), "Enter") == {at(2, 2), [], false}
    end

    test "a key that is not a digit removes the digits, also a key with no binding" do
      assert keys(at(1, 1), ["3", "j"]) == at(2, 1)
      assert keys(at(1, 1), ["3", "x"]) == at(1, 1)
      assert effects(%{at(1, 1) | digits: "3"}, "x") == {at(1, 1), [], true}
    end
  end

  describe "the black screen and the list of keys" do
    test "b gives a black screen, and the next key shows the slide again and does no more" do
      blank = key(at(2, 2), "b")
      assert blank == %{at(2, 2) | blank: true}

      for key <- ["b", "j", "p", "s", "f"] do
        assert effects(blank, key) == {at(2, 2), [], true}, key
      end
    end

    test "? opens the list of keys in each view, and removes the digits" do
      for view <- [:present, :handout, :speaker] do
        assert key(at(2, 2, view), "?") == %{at(2, 2, view) | help: true}, inspect(view)
      end

      assert keys(at(1, 1), ["3", "?"]) == %{at(1, 1) | help: true}
    end

    test "the next key closes the list of keys, and does nothing more" do
      open = %{at(2, 2) | help: true}

      for key <- ["j", "?", "x", "r"] do
        assert key(open, key) == at(2, 2), key
      end
    end
  end

  describe "the built-in functions" do
    test "s opens the speaker view from the present view only, and removes the digits" do
      typed = %{at(1, 1) | digits: "3"}
      assert effects(typed, "s") == {at(1, 1), [:open_speaker], true}
      assert effects(at(1, 1, :speaker), "s") == {at(1, 1, :speaker), [], false}
    end

    test "f is full screen in the present view and the speaker view only" do
      assert effects(at(1, 1), "f") == {at(1, 1), [:fullscreen], true}
      assert effects(at(1, 1, :speaker), "f") == {at(1, 1, :speaker), [:fullscreen], true}
      assert effects(at(1, 1, :handout), "f") == {at(1, 1, :handout), [], false}
    end

    # The key `r` keeps the digits today. `docs/research/elixir-presenter-report.md`
    # asks the maintainer about this difference from `s` and `f`.
    test "r sets the timer in the speaker view only, and keeps the digits" do
      typed = %{at(1, 1, :speaker) | digits: "3"}
      assert effects(typed, "r") == {typed, [:reset_timer], true}
      assert effects(at(1, 1), "r") == {at(1, 1), [], false}
    end
  end

  describe "the clicks and the swipes" do
    test "a click or a swipe moves one step, as j and k do" do
      assert run(@three, at(1, 1), {:click, :right}) == at(2, 1)
      assert run(@three, at(2, 1), {:click, :left_third}) == at(1, 1)
      assert run(@three, at(1, 1, :speaker), {:swipe, :left}) == at(2, 1, :speaker)
      assert run(@three, at(2, 1), {:swipe, :right}) == at(1, 1)
      assert run(@three, at(3, 2), {:click, :right}) == at(3, 2)
    end

    test "a click removes the digits" do
      assert run(@three, %{at(1, 1) | digits: "3"}, {:click, :right}) == at(2, 1)
    end

    test "a click closes a black screen or the list of keys, and does nothing more" do
      assert run(@three, %{at(2, 2) | blank: true}, {:click, :right}) == at(2, 2)

      assert run(@three, %{at(2, 2, :handout) | help: true}, {:swipe, :right}) ==
               at(2, 2, :handout)
    end

    test "a click or a swipe has no other function in the handout view" do
      handout = at(2, 2, :handout)

      for event <- [{:click, :right}, {:click, :left_third}, {:swipe, :left}, {:swipe, :right}] do
        assert run(@three, handout, event) == handout, inspect(event)
      end
    end

    test "a click on a page outside the overview moves as a click with no page does" do
      page = Program.element(3)
      assert run(@three, at(1, 1, :speaker), {:click, :right, page}) == at(2, 1, :speaker)
    end
  end

  describe "the address" do
    test "hash gives the slide and the step, and #1.1 for a deck with no slide" do
      assert Interpreter.hash(@three, at(2, 3)) == "#2.3"
      assert Interpreter.hash(program([]), Interpreter.initial(program([]))) == "#1.1"
    end

    test "a fragment gives a slide and a step, and a slide alone is step 1" do
      assert run(@three, at(1, 1), {:hash, "#2.3"}) == at(2, 3)
      assert run(@three, at(1, 1), {:hash, "#3"}) == at(3, 1)
      assert run(@three, at(1, 1, :handout), {:hash, "#2.2"}) == at(2, 2, :handout)
    end

    test "a fragment that the deck does not have gives the same state" do
      state = at(2, 2)

      for hash <- [
            "",
            "#",
            "#0",
            "#4",
            "#2.0",
            "#2.4",
            "#1.2",
            "#x",
            "#2.2.1",
            "#slide-2",
            "#2.2"
          ] do
        assert run(@three, state, {:hash, hash}) == state, hash
      end
    end

    test "a fragment removes a black screen and the digits" do
      assert run(@three, %{at(1, 1) | blank: true, digits: "3"}, {:hash, "#2"}) == at(2, 1)
    end
  end

  describe "the messages" do
    defp message(slide, step, blank \\ false),
      do: {:message, %{slide: slide, step: step, blank: blank}}

    test "a message moves to its position, with its black screen" do
      assert run(@three, at(1, 1, :speaker), message(3, 2, true)) ==
               %{at(3, 2, :speaker) | blank: true}
    end

    test "a message for the same position or a position not in the deck gives the same state" do
      state = at(2, 2)

      for event <- [message(2, 2), message(4, 1), message(2, 4), message(0, 1)] do
        assert run(@three, state, event) == state, inspect(event)
      end
    end
  end

  describe "the overview" do
    # Seven slides of one step each give three columns.
    @seven program([1, 1, 1, 1, 1, 1, 1])

    defp grid(selected, slide \\ 4),
      do: %{Model.at(@seven, slide, 1) | overview: true, selected: selected}

    test "o opens the overview at the current slide in the present view and the speaker view" do
      assert run(@seven, Model.at(@seven, 4, 1), {:key, "o"}) == grid(4)

      assert run(@seven, Model.at(@seven, 2, 1, :speaker), {:key, "o"}) ==
               %{grid(2, 2) | view: :speaker}

      assert run(@seven, Model.at(@seven, 1, 1, :handout), {:key, "o"}) ==
               Model.at(@seven, 1, 1, :handout)
    end

    test "the keys of the overview select a slide inside the deck" do
      assert run(@seven, grid(4), {:key, "ArrowRight"}) == grid(5)
      assert run(@seven, grid(4), {:key, "k"}) == grid(3)
      assert run(@seven, grid(4), {:key, "ArrowDown"}) == grid(7)
      assert run(@seven, grid(4), {:key, "ArrowUp"}) == grid(1)
      assert run(@seven, grid(4), {:key, "End"}) == grid(7)
      assert run(@seven, grid(4), {:key, "Home"}) == grid(1)

      for {selected, key} <- [{7, "j"}, {5, "ArrowDown"}, {2, "ArrowUp"}, {1, "ArrowLeft"}] do
        assert run(@seven, grid(selected), {:key, key}) == grid(selected), key
      end
    end

    test "Enter goes to step 1 of the selected slide, and o or Escape keeps the step" do
      deck = program([1, 1, 3, 1, 1, 1, 1])
      deep = %{Model.at(deck, 3, 2) | overview: true, selected: 2}
      on = fn slide, step -> %{Model.at(deck, slide, step) | selected: 2} end

      assert run(deck, deep, {:key, "Enter"}) == on.(2, 1)
      assert run(deck, deep, {:key, "o"}) == on.(3, 2)
      assert run(deck, deep, {:key, "Escape"}) == on.(3, 2)
    end

    test "a click on a page goes to step 1 of its slide, and closes the overview" do
      on = fn slide -> %{Model.at(@seven, slide, 1) | selected: 1} end

      for {slide, expected} <- [{6, on.(6)}, {4, on.(4)}, {9, on.(4)}] do
        assert run(@seven, grid(1), {:click, :right, Program.element(slide)}) == expected
      end
    end

    test "a click between the pages of the overview does nothing" do
      assert run(@seven, grid(4), {:click, :right}) == grid(4)
      assert run(@seven, grid(4), {:swipe, :left}) == grid(4)
    end

    test "the overview knows ?, and no key of the present view" do
      assert run(@seven, grid(4), {:key, "?"}) == %{grid(4) | help: true}

      for key <- ["b", "p", "s", "g", "f", "5"] do
        assert Interpreter.run(@seven, grid(4), {:key, key}) == {grid(4), []}, key
      end
    end

    test "a click under the list of keys of the overview closes only the list" do
      help = %{grid(4) | help: true}
      assert run(@seven, help, {:click, :right, Program.element(6)}) == grid(4)
    end

    test "a message of the other window keeps the overview" do
      assert run(@seven, grid(2), message(6, 1)) == grid(2, 6)
    end
  end

  describe "the transitions" do
    # Four slides: the kinds of slides 2 to 4 are slide, none and zoom.
    @four program([1, 2, 1, 1], [:fade, :slide, :none, :zoom])

    defp on(slide, step, view \\ :present), do: Model.at(@four, slide, step, view)
    defp transition(before, after_event), do: Interpreter.transition(@four, before, after_event)

    test "a move forward uses the kind of the slide that it goes to" do
      assert transition(on(1, 1), on(2, 1)) == %{kind: "slide", direction: :forward}
      assert transition(on(3, 1), on(4, 1)) == %{kind: "zoom", direction: :forward}
    end

    test "a move back uses the kind of the slide that it leaves" do
      assert transition(on(2, 2), on(1, 1)) == %{kind: "slide", direction: :back}
      # Home from slide 4 to slide 1 uses the kind of slide 4.
      assert transition(on(4, 1), on(1, 1)) == %{kind: "zoom", direction: :back}
    end

    test "the kind none gives no transition in the two directions" do
      assert transition(on(2, 2), on(3, 1)) == nil
      assert transition(on(3, 1), on(2, 2)) == nil
    end

    test "a change of the step has no transition" do
      assert transition(on(2, 1), on(2, 2)) == nil
    end

    test "only the present view has a transition" do
      for view <- [:speaker, :handout] do
        assert transition(on(1, 1, view), on(2, 1, view)) == nil, inspect(view)
      end

      assert transition(on(1, 1, :handout), on(2, 1)) == nil
    end

    test "a black screen, the overview and the list of keys have no transition" do
      for field <- [:blank, :overview, :help] do
        assert transition(%{on(1, 1) | field => true}, on(2, 1)) == nil, inspect(field)
        assert transition(on(1, 1), %{on(2, 1) | field => true}) == nil, inspect(field)
      end
    end
  end
end
