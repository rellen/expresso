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
  slide, step, blank, undim]`. The commands of a click are the commands of the page
  of the overview or of the link under the click, or `null`. A result is `[state, prevented, effects,
  transition]`.
  """

  alias Expresso.Builder
  alias Expresso.Presenter.{Definition, Help, Interpreter, Program}

  @path "assets/test/fixtures/presenter.json"

  # The fields of the state, in the order of each state array.
  @fields [:index, :view, :blank, :digits, :help, :progress, :every, :overview, :selected, :undim]

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

  @keys ~w(j k ArrowRight ArrowLeft ArrowUp ArrowDown PageDown PageUp Home End Enter b d p s r f g a o ? Escape x Tab) ++
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

  @doc "Return the text of the fixture file. The same seed returns the same text."
  @spec json() :: String.t()
  def json do
    :rand.seed(:exsss, {20, 26, 9})
    random = for _deck <- 1..@random_decks, do: random_deck()
    decks = Enum.uniq(@decks ++ random)

    parts = [
      ~s("fields":) <> JSON.encode!(Enum.map(@fields, &Atom.to_string/1)),
      ~s("help":) <> JSON.encode!(help()),
      ~s("decks":{\n) <> Enum.map_join(decks, ",\n", &deck_json/1) <> "\n}",
      ~s("cases":[\n) <>
        Enum.map_join(random, ",\n", fn deck ->
          Enum.map_join(1..@sequences, ",\n", fn _sequence -> JSON.encode!(case_of(deck)) end)
        end) <> "\n]"
    ]

    "{\n" <> Enum.join(parts, ",\n") <> "\n}\n"
  end

  defp help do
    for {mode, rows} <- Help.rows(Definition.presenter()),
        do: [Atom.to_string(mode), Enum.map(rows, &Tuple.to_list/1)]
  end

  # A deck of 0 to 8 slides with 1 to 5 steps each, and a kind for each slide.
  defp random_deck do
    counts = for _slide <- 1..(:rand.uniform(9) - 1)//1, do: :rand.uniform(5)
    {counts, Enum.map(counts, fn _count -> pick(@kinds) end)}
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

  defp case_of({counts, kinds} = shape) do
    program = Program.compile(Definition.presenter(), deck(counts, kinds))

    start =
      Interpreter.initial(program, %{
        view: pick([:present, :speaker]),
        progress: pick([true, false]),
        every: pick([true, false])
      })

    {results, _state} =
      Enum.map_reduce(1..@events, start, fn _event, state ->
        {event, model} = event(length(counts))
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
  defp event(slides) do
    case :rand.uniform(20) do
      n when n <= 14 ->
        key = pick(@keys)
        {["key", key], {:key, key}}

      15 ->
        region = pick([:right, :left_third])
        {["click", Atom.to_string(region), nil], {:click, region}}

      # A click on a page of the overview, or on a link of `Expresso.Goto`.
      16 ->
        region = pick([:right, :left_third])
        link = Program.link(:rand.uniform(slides * 3 + 1) - 1)
        commands = pick([Program.element(near(slides)), link])
        json = commands |> Program.json_commands() |> JSON.decode!()
        {["click", Atom.to_string(region), json], {:click, region, commands}}

      17 ->
        direction = pick([:left, :right])
        {["swipe", Atom.to_string(direction)], {:swipe, direction}}

      18 ->
        hash = pick(["#", "#x", "#2.2.1", "##{near(slides)}", "##{near(slides)}.#{near(6)}"])
        {["hash", hash], {:hash, hash}}

      _message ->
        {slide, step} = {near(slides), near(6)}
        {blank, undim} = {pick([true, false]), pick([true, false])}

        {["message", slide, step, blank, undim],
         {:message, %{slide: slide, step: step, blank: blank, undim: undim}}}
    end
  end

  defp state_json(state) do
    Enum.map(@fields, fn
      :view -> Atom.to_string(state.view)
      field -> Map.fetch!(state, field)
    end)
  end

  defp pick(list), do: Enum.at(list, :rand.uniform(length(list)) - 1)

  # A number of a slide or a step, inside and outside the deck.
  defp near(maximum), do: :rand.uniform(maximum + 4) - 2
end
