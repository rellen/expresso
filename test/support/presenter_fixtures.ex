defmodule Expresso.Test.PresenterFixtures do
  @moduledoc """
  Makes the fixtures of the TypeScript tests of the presenter

  The TypeScript tests run the interpreter of the script, and they need the
  programs that `Expresso.Presenter.Program` makes. Node cannot run Elixir, so
  Git holds the fixtures in `assets/test/fixtures/presenter.json`. The test
  `Expresso.Presenter.FixturesTest` fails when the file does not agree with
  `json/0`. This command writes the file again:

      EXPRESSO_FIXTURES=write mix test test/expresso/presenter/fixtures_test.exs

  The file holds four keys:

    * `"fields"` - the fields of the state, in the order of each state array.
    * `"help"` - the rows of the list of keys of each mode.
    * `"decks"` - the list of the steps and the program of each deck that a test
      uses. The key of a deck is the number of steps of each slide, such as
      `"1,3,2"`, and the kinds of its transitions after a space when it has them.
    * `"cases"` - random events on random decks, and the result of the Elixir
      interpreter after each event.

  An event is one of these arrays: `["key", key]`, `["click", region,
  commands]`, `["swipe", direction]`, `["hash", fragment]` and `["message",
  slide, step, fields]`. The fields of a message are an object with a value
  for each field of the option `sync`. The commands of a click are the
  commands of the page of the overview or of the link under the click, or
  `null`. A result is `[state, prevented, effects, transition]`.
  """

  alias Expresso.Builder
  alias Expresso.Presenter.{Definition, Help, Interpreter, Program, Schema}

  @path "assets/test/fixtures/presenter.json"

  # The fields of the state, in the order of each state array.
  @fields Keyword.keys(Schema.fields())

  # The decks of the tests of `main.ts`.
  @decks [
    {[1, 2], []},
    {[1, 1], []},
    {[2, 1], []},
    {[1, 1, 1], []},
    {[1, 1, 1, 1], []},
    {[1, 3, 2, 1, 1], []},
    {[1, 2, 1, 1], [:fade, :slide, :none, :zoom]}
  ]

  @keys ~w(j k ArrowRight ArrowLeft ArrowUp ArrowDown PageDown PageUp Home End Enter b w d m p s r f g a o ? / Escape x Tab) ++
          [" "] ++ Enum.map(0..9, &Integer.to_string/1)

  @kinds [:none, :fade, :slide, :zoom]

  # The number of random decks, the sequences of events for each deck, and the
  # events in each sequence.
  @random_decks 16
  @sequences 2
  @events 30

  @doc "Return the path of the fixture file"
  @spec path() :: Path.t()
  def path, do: @path

  @doc """
  Return the text of the fixture file. The same seed returns the same text.

  The generator keeps its random state in a variable, and not in the process
  dictionary, so no other code in the process can change the numbers.
  """
  @spec json() :: String.t()
  def json do
    seed = :rand.seed_s(:exsss, {20, 26, 9})
    {random, seed} = Enum.map_reduce(1..@random_decks, seed, fn _deck, r -> random_deck(r) end)
    decks = Enum.uniq(@decks ++ random)

    {cases, _seed} =
      Enum.flat_map_reduce(random, seed, fn deck, r ->
        Enum.map_reduce(1..@sequences, r, fn _sequence, r -> plan(deck, r) end)
      end)

    parts = [
      ~s("fields":) <> JSON.encode!(Enum.map(@fields, &Atom.to_string/1)),
      ~s("help":) <> JSON.encode!(help()),
      ~s("decks":{\n) <> Enum.map_join(decks, ",\n", &deck_json/1) <> "\n}",
      ~s("cases":[\n) <>
        Enum.map_join(cases, ",\n", &JSON.encode!(case_of(&1))) <> "\n]"
    ]

    "{\n" <> Enum.join(parts, ",\n") <> "\n}\n"
  end

  defp help do
    for {mode, rows} <- Help.rows(Definition.presenter()),
        do: [Atom.to_string(mode), Enum.map(rows, &Tuple.to_list/1)]
  end

  # A deck of 0 to 8 slides with 1 to 5 steps each, and a kind for each slide.
  defp random_deck(r) do
    {size, r} = uniform(9, r)
    {counts, r} = Enum.map_reduce(1..(size - 1)//1, r, fn _slide, r -> uniform(5, r) end)
    {kinds, r} = Enum.map_reduce(counts, r, fn _count, r -> pick(@kinds, r) end)
    {{counts, kinds}, r}
  end

  @doc "Return the key of a deck in the fixture file"
  @spec key({[pos_integer()], [atom()]}) :: String.t()
  def key({counts, []}), do: Enum.join(counts, ",")
  def key({counts, kinds}), do: Enum.join(counts, ",") <> " " <> Enum.join(kinds, ",")

  defp deck_json({counts, kinds} = shape) do
    deck = deck(counts, kinds)
    program = Program.compile(Definition.presenter(), deck)

    JSON.encode!(key(shape)) <>
      ":" <>
      JSON.encode!(%{
        "deck" => JSON.decode!(Expresso.Steps.json(deck)),
        "program" => JSON.decode!(Program.json(program))
      })
  end

  defp deck(counts, kinds) do
    counts
    |> Enum.with_index(1)
    |> Enum.map(fn {steps, number} ->
      transition = for kind <- [Enum.at(kinds, number - 1)], kind, do: {:transition, kind}
      Builder.slide("slide #{number}", [steps: steps] ++ transition)
    end)
    |> Builder.deck(name: "deck")
  end

  # The random part of a case: the options of the start, and the events.
  defp plan({counts, _kinds} = shape, r) do
    {view, r} = pick([:present, :speaker], r)
    {progress, r} = pick([true, false], r)
    {every, r} = pick([true, false], r)
    {events, r} = Enum.map_reduce(1..@events, r, fn _event, r -> event(length(counts), r) end)
    {{shape, %{view: view, progress: progress, every: every}, events}, r}
  end

  defp case_of({{counts, kinds} = shape, options, events}) do
    program = Program.compile(Definition.presenter(), deck(counts, kinds))
    start = Interpreter.initial(program, options)

    {results, _state} =
      Enum.map_reduce(events, start, fn {event, model}, state ->
        {after_event, effects} = Interpreter.run(program, state, model)

        transition =
          case Interpreter.transition(program, state, after_event) do
            nil -> nil
            %{kind: kind, direction: direction} -> [kind, Atom.to_string(direction)]
          end

        result = [
          state_json(after_event),
          Interpreter.prevented?(state, after_event, effects),
          Enum.map(effects, &Atom.to_string/1),
          transition
        ]

        {{event, result}, after_event}
      end)

    %{
      "deck" => key(shape),
      "start" => state_json(start),
      "events" => Enum.map(results, &elem(&1, 0)),
      "results" => Enum.map(results, &elem(&1, 1))
    }
  end

  # An event in the fixture file, and the same event for the Elixir interpreter.
  defp event(slides, r) do
    case uniform(20, r) do
      {n, r} when n <= 14 ->
        {key, r} = pick(@keys, r)
        {{["key", key], {:key, key}}, r}

      {15, r} ->
        {region, r} = pick([:right, :left_third], r)
        {{["click", Atom.to_string(region), nil], {:click, region}}, r}

      # A click on a page of the overview, on a link of `Expresso.Goto`, or on
      # a row of the menu.
      {16, r} ->
        {region, r} = pick([:right, :left_third], r)
        {link, r} = uniform(slides * 3 + 1, r)
        {row, r} = uniform(slides * 3 + 1, r)
        {element, r} = near(slides, r)

        {commands, r} =
          pick([Program.element(element), Program.link(link - 1), Program.menu(row - 1)], r)

        json = commands |> Program.json_commands() |> JSON.decode!()
        {{["click", Atom.to_string(region), json], {:click, region, commands}}, r}

      {17, r} ->
        {direction, r} = pick([:left, :right], r)
        {{["swipe", Atom.to_string(direction)], {:swipe, direction}}, r}

      {18, r} ->
        {a, r} = near(slides, r)
        {b, r} = near(slides, r)
        {c, r} = near(6, r)
        {hash, r} = pick(["#", "#x", "#2.2.1", "##{a}", "##{b}.#{c}"], r)
        {{["hash", hash], {:hash, hash}}, r}

      {_message, r} ->
        {slide, r} = near(slides, r)
        {step, r} = near(6, r)

        # Each field of the option `sync` holds true or false.
        {fields, r} =
          Enum.map_reduce(Definition.presenter().sync, r, fn field, r ->
            {value, r} = pick([true, false], r)
            {{field, value}, r}
          end)

        # The JSON object has string keys. A map with atom keys encodes them in
        # the order that the atoms were made, and that order changes with the
        # order in which the modules load.
        json = Map.new(fields, fn {field, value} -> {Atom.to_string(field), value} end)

        {{["message", slide, step, json],
          {:message, %{slide: slide, step: step, fields: Map.new(fields)}}}, r}
    end
  end

  defp state_json(state) do
    Enum.map(@fields, fn
      :view -> Atom.to_string(state.view)
      field -> Map.fetch!(state, field)
    end)
  end

  defp uniform(n, r), do: :rand.uniform_s(n, r)

  defp pick(list, r) do
    {n, r} = uniform(length(list), r)
    {Enum.at(list, n - 1), r}
  end

  # A number of a slide or a step, inside and outside the deck.
  defp near(maximum, r) do
    {n, r} = uniform(maximum + 4, r)
    {n - 2, r}
  end
end
