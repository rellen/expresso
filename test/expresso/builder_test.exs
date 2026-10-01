defmodule Expresso.BuilderTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import ExUnit.CaptureIO
  import Expresso.Test.DeckTree, only: [entity: 1, entity: 2, entity: 3, entity: 4]

  alias Expresso.Builder
  alias Expresso.Test.DeckTree

  # A deck with each entity and many options. The image and the diagram read
  # files of the repository.
  @options [
    name: "parity",
    progress: false,
    slide_numbers: true,
    duration: 10,
    transition: :slide,
    effect: :grow,
    speed: :slow,
    easing: :linear,
    handout: :last,
    print_notes: false,
    template: {:builtins, :default}
  ]

  @slides [
    entity(
      :slide,
      ["title"],
      [
        heading: "Hello",
        notes: "Say hello.",
        transition: :zoom,
        template: {:builtins, :default}
      ],
      elements: [
        entity(:text_box, [], [],
          elements: [
            entity(:text_area, [], text: "Go to the end", goto: [slide: 4, step: 2]),
            entity(:text_area, [], text: "Later", at: [from: 2], effect: :fly_up)
          ],
          on: [entity(:on, [3], state: :alert)]
        )
      ]
    ),
    entity(:slide, ["overlays"], [steps: 5, handout: [2, :last], effect: :wipe],
      elements: [
        entity(:text_box, [], [at: :next], elements: [entity(:text_area, [], text: "one")]),
        entity(:pause),
        entity(:list, [], [reveal: true, dim: true, ordered: true],
          elements: [
            entity(:item, ["first"], goto: [slide: 1]),
            entity(:item, ["second"], [],
              elements: [entity(:list, [], [], elements: [entity(:item, ["nested"])])]
            )
          ]
        ),
        entity(:text_box, [], [at: [2, from: 4]],
          elements: [entity(:text_area, [], text: "two")],
          on: [entity(:on, [4], set: [x: "1px"])]
        )
      ]
    ),
    entity(:slide, ["auto"], [auto_reveal: true],
      elements: [
        entity(:table, [], [header: true, reveal: true],
          elements: [entity(:row, [["a", "b"]]), entity(:row, [["c", "d"]])]
        ),
        entity(:code, ["elixir"], text: "a = 1\nb = 2\nc = 3", reveal: [1, 2..3], dim: true),
        entity(:quotation, ["A quotation"], by: "Someone"),
        entity(:math, ["<math><mi>x</mi></math>"])
      ]
    ),
    entity(:slide, ["media"], [steps: 3],
      elements: [
        entity(:columns, [], [],
          elements: [
            entity(:column, [], [width: "40%"],
              elements: [entity(:image, ["examples/animations/branch.svg"], alt: "A branch")]
            ),
            entity(:column, [], [at: [from: 2]],
              elements: [
                entity(:diagram, ["examples/flow.svg"], [width: "60%"],
                  elements: [entity(:part, ["arrow"], at: [from: 3])]
                )
              ]
            )
          ]
        ),
        entity(:spacer)
      ]
    )
  ]

  defp module, do: Module.concat(__MODULE__, "Deck#{System.unique_integer([:positive])}")

  defp html(deck), do: Expresso.Deck.render(deck)

  # The two documents, from the first character that differs, so that a
  # failure shows the difference and not the fonts. Each copy of the file of a
  # diagram gets ids with a number that is unique in the VM, so the function
  # writes N in place of that number.
  defp same(left, right) do
    left = diagram_ids(left)
    right = diagram_ids(right)

    index =
      Enum.zip(String.graphemes(left), String.graphemes(right))
      |> Enum.find_index(fn {a, b} -> a != b end)

    case index do
      nil -> assert left == right
      index -> assert String.slice(left, index - 80, 400) == String.slice(right, index - 80, 400)
    end
  end

  describe "a deck from the DSL and from the functions" do
    test "gives the same HTML for each entity and many options" do
      same(
        html(DeckTree.dsl(module(), @options, @slides)),
        html(DeckTree.builder(@options, @slides))
      )
    end

    property "gives the same HTML for a random deck" do
      check all(slides <- DeckTree.slides(), max_runs: 15) do
        same(
          html(DeckTree.dsl(module(), [name: "random"], slides)),
          html(DeckTree.builder([name: "random"], slides))
        )
      end
    end
  end

  describe "the functions" do
    test "exist for each entity of the DSL, with the required arguments" do
      [section] = Expresso.Extension.sections()
      Code.ensure_loaded!(Builder)

      for entity <- descendants(section.entities) do
        arity = Enum.count(entity.args, &is_atom/1)
        assert function_exported?(Builder, entity.name, arity + 1), inspect(entity.name)
      end
    end

    test "take an optional argument in its position, or in the keyword list" do
      assert Builder.slide().name == nil
      assert Builder.slide("first").name == "first"
      assert Builder.slide(heading: "Hello").heading == "Hello"
      assert Builder.slide("first", heading: "Hello").name == "first"
      assert Builder.code("elixir", text: "x").lang == "elixir"
      assert Builder.code(text: "x", lang: "elixir").lang == "elixir"
    end

    test "refuse an option with the message of the DSL" do
      assert_raise ArgumentError,
                   "image: invalid value for :width option: expected string, got: 200",
                   fn -> Builder.image("x.svg", width: 200) end

      assert_raise ArgumentError, ~r/^text_area: invalid value for :at option/, fn ->
        Builder.text_area(text: "x", at: [from: :later])
      end
    end

    test "refuse a value that is not a child of the DSL" do
      assert_raise ArgumentError, "list: \"text\" cannot go in elements", fn ->
        Builder.list(elements: ["text"])
      end

      assert_raise ArgumentError, "text_box: Expresso.Element.TextArea cannot go in on", fn ->
        Builder.text_box(on: [Builder.text_area(text: "x")])
      end

      assert_raise ArgumentError, "Expresso.Element.TextBox cannot go in deck", fn ->
        Builder.deck([Builder.text_box()])
      end
    end

    test "accept a text box in a column, as the DSL does" do
      box = Builder.text_box(elements: [Builder.text_area(text: "x")])
      assert %{elements: [^box]} = Builder.column(elements: [box])
    end

    test "nest a list deeper than the levels of the DSL" do
      nested =
        Enum.reduce(1..5, Builder.item("deepest"), fn _level, item ->
          Builder.item("item", elements: [Builder.list(elements: [item])])
        end)

      assert %Expresso.Element.Item{} = nested
    end
  end

  describe "deck/2" do
    test "refuses a deck option with the message of the DSL" do
      assert_raise ArgumentError, ~r/^deck: invalid value for :transition option/, fn ->
        Builder.deck([], transition: :spin)
      end
    end

    test "raises the error of a transformer" do
      slide = Builder.slide("a", steps: 2, elements: [Builder.text_box(at: 5)])

      assert_raise Spark.Error.DslError, ~r/the step 5 is more than the maximum step 2/, fn ->
        Builder.deck([slide])
      end
    end

    test "raises the error of a verifier" do
      link = Builder.text_area(text: "x", goto: [slide: 9])
      slide = Builder.slide("a", elements: [Builder.text_box(elements: [link])])

      assert_raise Spark.Error.DslError,
                   ~r/goto names the slide 9, and the deck has 1 slides/,
                   fn ->
                     Builder.deck([slide])
                   end
    end

    test "writes the warning of a verifier to the standard error" do
      slide = Builder.slide("a", elements: [Builder.text_box(at: 60)])

      assert capture_io(:stderr, fn -> Builder.deck([slide]) end) =~
               "the slide takes 60 steps, and 50 is the usual maximum"
    end

    test "makes a deck with no slide, and its document has no section and no page" do
      document = [] |> Builder.deck(name: "d") |> html() |> Floki.parse_document!()

      assert Floki.find(document, "section.slide") == []
      assert Floki.find(document, ".handout-page") == []
      assert document |> Floki.find("title") |> Floki.text() == "d"
    end

    test "numbers each slide from 1, and keeps the options of a slide in its metadata" do
      deck = Builder.deck([Builder.slide("first", heading: "Hello"), Builder.slide()])

      assert Enum.map(deck.slides, & &1.metadata.slide_number) == [1, 2]
      assert hd(deck.slides).metadata.heading == "Hello"
    end

    test "makes a deck of 2000 slides in less than 2 seconds" do
      slides =
        for n <- 1..2000 do
          Builder.slide("slide #{n}",
            elements: [Builder.text_box(elements: [Builder.text_area(text: "#{n}")])]
          )
        end

      {time, deck} = :timer.tc(fn -> Builder.deck(slides) end)

      assert length(deck.slides) == 2000
      assert time < 2_000_000
    end
  end

  defp diagram_ids(html) do
    numbers =
      for [svg] <- Regex.scan(~r/<svg.*?<\/svg>/s, html),
          [_id, number] <- Regex.scan(~r/ id="[^"]+-(\d+)"/, svg),
          uniq: true,
          do: number

    Enum.reduce(numbers, html, &String.replace(&2, ~r/-#{&1}(?=[")])/, "-N"))
  end

  defp descendants(entities) do
    Enum.flat_map(entities, fn entity ->
      [entity | entity.entities |> Keyword.values() |> List.flatten() |> descendants()]
    end)
  end
end
