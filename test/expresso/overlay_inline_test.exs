defmodule Expresso.Overlay.InlineTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.{Item, TextArea, TextPart}
  alias Expresso.Overlay.{Expand, Inline}

  doctest Expresso.Overlay.Inline

  defp area(text, opts \\ []), do: Builder.text_area([text: text] ++ opts)
  defp box(elements, opts \\ []), do: Builder.text_box([elements: List.wrap(elements)] ++ opts)

  # The parts of each text area and each item of a slide, in document order:
  # the steps of each part, and the steps and the state of each `on` entity.
  defp parts(slide) do
    for %kind{} = element <- Expresso.Element.Tree.descendants(slide.elements),
        kind in [TextArea, Item],
        %TextPart{} = part <- element.elements do
      {part.steps, Enum.map(part.on, &{&1.steps, &1.state})}
    end
  end

  defp expand(elements, opts \\ []) do
    {:ok, slide} = Expand.slide(Builder.slide("s", [elements: List.wrap(elements)] ++ opts))
    slide
  end

  describe "spec/1" do
    test "takes each form of a step specification in text" do
      forms = [
        {"2", [{2, 2}]},
        {"2-4", [{2, 4}]},
        {"2-", [{2, :max}]},
        {"+", [{:next, :next}]},
        {"+-", [{:next, :max}]},
        {"2,5-7", [{2, 2}, {5, 7}]},
        {" 2 , 5- ", [{2, 2}, {5, :max}]},
        {"12-", [{12, :max}]}
      ]

      for {text, pairs} <- forms do
        assert {:ok, spec} = Inline.spec(text)
        assert spec.pairs == pairs, text
      end
    end

    test "refuses a text that is not a step specification" do
      for text <- ["", "0", "two", "2..4", "-2", "2,,3", "+2", "2-+", "1.5", "2 3"] do
        assert {:error, message} = Inline.spec(text)
        assert message =~ "is not the steps of a part of a text", text
      end
    end

    test "refuses a range that goes down, with the message of the overlay specification" do
      assert {:error, message} = Inline.spec("4-2")
      assert message =~ "the range 4..2//1 is not valid in an overlay specification"
    end
  end

  describe "parse/1" do
    test "finds each tag with at, and keeps each other attribute and each other tag" do
      text =
        ~s(One <span class="big" at="2-" id="a">two</span> <em>three</em> ) <>
          ~s(<b at='3' state='dim'>four</b> <i state="alert" at="+">five</i>)

      assert {:ok, {html, parts}} = Inline.parse(text)

      assert html ==
               ~s(One <span class="big" data-text-part="1" id="a">two</span> <em>three</em> ) <>
                 ~s(<b data-text-part="2">four</b> <i data-text-part="3">five</i>)

      assert Enum.map(parts, & &1.index) == [1, 2, 3]
      assert [%{pairs: [{2, :max}]}, nil, nil] = Enum.map(parts, & &1.at)

      assert [[], [{[{3, 3}], :dim}], [{[{:next, :next}], :alert}]] =
               Enum.map(parts, fn part -> Enum.map(part.on, &{&1.at.pairs, &1.state}) end)
    end

    test "a different attribute that ends with at, and escaped text, are not parts" do
      text = ~s(<span data-at="2">a</span> <span format="2">b</span> &lt;b at="2"&gt;)

      assert Inline.parse(text) == {:ok, {text, []}}
    end

    test "gives the error of a wrong at, of a wrong state and of a state with no at" do
      assert {:error, message} = Inline.parse(~s(<b at="soon">a</b>))
      assert message =~ ~s("soon" is not the steps of a part of a text)

      assert {:error, message} = Inline.parse(~s(<b at="2" state="bold">a</b>))

      assert message ==
               ~s(the state "bold" of the tag <b at="2" state="bold"> of a text is not a state ) <>
                 ~s(of a part. The states are "alert" and "dim")

      assert {:error, message} = Inline.parse(~s(<b state="alert">a</b>))
      assert message =~ "has the attribute state and no attribute at"
    end
  end

  describe "the expansion" do
    test "a part gets the steps of its at, and a part with a state shows at each step" do
      slide = expand(box(area(~s(<b at="2-">a</b> <i at="3" state="alert">b</i>))))

      assert slide.metadata.max_step == 3
      assert parts(slide) == [{[2, 3], []}, {nil, [{[3], :alert}]}]
    end

    test "the counter goes through the element, then its parts in the order of the text, then the next element" do
      slide =
        expand([
          box(area(~s(<b at="+">a</b> <b at="+-">b</b>), at: :next)),
          box(area("plain", at: :next)),
          box(area(~s(<b at="+" state="dim">c</b>)))
        ])

      # The first text area takes step 1, and its parts take steps 2 and 3.
      # The second text area takes step 4, and the last part takes step 5.
      assert slide.metadata.max_step == 5
      assert parts(slide) == [{[2], []}, {[3, 4, 5], []}, {nil, [{[5], :dim}]}]

      assert [[1], [4], nil] =
               for(
                 %TextArea{steps: steps} <- Expresso.Element.Tree.descendants(slide.elements),
                 do: steps
               )
    end

    test "a part of an item reads the counter in front of the nested list of the item" do
      nested = Builder.list(elements: [Builder.item("inside", at: :next)])
      item = Builder.item(~s(An item with <b at="+">a part</b>), at: :next, elements: [nested])
      slide = expand(Builder.list(elements: [item]))

      assert parts(slide) == [{[2], []}]

      assert [[1], [3]] =
               for(
                 %Item{steps: steps} <- Expresso.Element.Tree.descendants(slide.elements),
                 do: steps
               )
    end

    test "a step that the slide does not have is an error, as for an element" do
      slide = Builder.slide("s", steps: 2, elements: [box(area(~s(<b at="3">a</b>)))])

      assert {:error, message} = Expand.slide(slide)
      assert message =~ "more than the maximum step 2"
    end

    test "a text with no part gets no child, and a second expansion changes nothing" do
      slide = expand(box([area("A <em>plain</em> text"), area(~s(<b at="2">a</b>))]))

      assert [[], [%TextPart{}]] =
               for(
                 %TextArea{elements: elements} <-
                   Expresso.Element.Tree.descendants(slide.elements),
                 do: elements
               )

      assert {:ok, again} = Expand.slide(slide)
      assert parts(again) == parts(slide)
    end
  end

  describe "the document" do
    test "a part with steps gets data-on, and a part with a state gets an identity and a rule" do
      text =
        ~s(The answer is <span at="2-">42</span>. It is <em at="3" state="alert">not</em> 41.)

      html = document(one_slide(box(area(text))))

      [answer, not_41] = html |> screen("[data-text-part]") |> Enum.to_list()

      assert LazyHTML.text(answer) == "42"
      assert LazyHTML.attribute(answer, "data-on") == ["2 3"]
      assert LazyHTML.attribute(answer, "data-el") == []
      assert LazyHTML.attribute(answer, "at") == []

      assert LazyHTML.text(not_41) == "not"
      assert LazyHTML.attribute(not_41, "data-on") == []
      assert [el] = LazyHTML.attribute(not_41, "data-el")
      assert LazyHTML.attribute(not_41, "state") == []

      style = html |> LazyHTML.query("style") |> Enum.map_join("\n", &LazyHTML.text/1)
      assert style =~ ~s(section[data-step="3"] [data-el="#{el}"] { --alert: 1; })

      assert html |> screen("section.slide") |> LazyHTML.attribute("data-max-step") == ["3"]
    end

    test "each copy of the slide has the parts: each page of the handout view and the menu" do
      html = document(one_slide(box(area(~s(<b at="2-">a</b>)))))

      assert count(html, ".screen [data-text-part][data-on]") == 1
      assert count(html, ".handout-page [data-text-part][data-on]") == 2
      assert count(html, ".menu-thumb [data-text-part][data-on]") == 1
    end

    test "an item writes its parts into its text, and it still renders its nested list" do
      nested = Builder.list(elements: [Builder.item("inside")])
      item = Builder.item(~s(An item with <code at="2-">a part</code>), elements: [nested])
      html = document(one_slide(Builder.list(elements: [item])))

      assert texts(html, ".screen .item [data-text-part][data-on='2']") == ["a part"]
      assert texts(html, ".screen .item .list .item") == ["inside"]
    end

    test "a text area with a link holds its parts in the link" do
      slides = [
        Builder.slide("one",
          elements: [box(area(~s(Go to <b at="2-">two</b>), goto: [slide: 2]))]
        ),
        Builder.slide("two", elements: [])
      ]

      html = document(Builder.deck(slides, name: "deck"))

      assert texts(html, ".screen a.goto [data-text-part][data-on='2']") == ["two"]
    end

    test "a text with no part is the same text" do
      html = document(one_slide(box(area("A <em>plain</em> text"))))

      assert count(html, "[data-text-part]") == 0
      assert texts(html, ".screen .text-area em") == ["plain"]
    end
  end

  describe "the deck" do
    test "the DSL takes a part in a text area and in an item" do
      defmodule PartDeck do
        use Expresso

        slide "parts" do
          text_box do
            text_area(text: ~s(The answer is <span at="2-">42</span>.))
          end

          list do
            item ~s(An item with <b at="+-">a part</b>)
          end
        end
      end

      {:ok, deck} = Expresso.to_deck(PartDeck)
      [slide] = deck.slides

      assert slide.metadata.max_step == 2
      assert parts(slide) == [{[2], []}, {[1, 2], []}]
    end

    test "the compiler refuses a wrong at with the path of the slide" do
      assert_raise Spark.Error.DslError, ~r/is not the steps of a part of a text/, fn ->
        Builder.deck([Builder.slide("s", elements: [box(area(~s(<b at="x">a</b>)))])],
          name: "deck"
        )
      end
    end
  end
end
