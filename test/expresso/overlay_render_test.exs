defmodule Expresso.Overlay.RenderTest do
  use ExUnit.Case, async: true

  alias Expresso.Deck
  alias Expresso.Element.{On, Pause, TextArea, TextBox}
  alias Expresso.Overlay.Render
  alias Expresso.Slide

  defmodule RenderDeck do
    use Expresso

    name "render deck"

    slide "one" do
      text_box do
        at from: :next
        on :next, state: :alert

        text_area do
          text "first"
        end
      end

      pause()

      text_box do
        at 2..3
        on 3, set: [x: "400px", y: "100px"]

        text_area do
          at 3
          on 3, state: :alert
          text "second"
        end
      end
    end

    slide do
      text_box do
        text_area do
          text "plain"
        end
      end
    end
  end

  defp deck(slides) do
    slides
    |> Enum.with_index(1)
    |> Enum.map(fn {elements, number} ->
      %Slide{elements: elements, metadata: %{slide_number: number, max_step: 3}}
    end)
    |> then(&%Deck{name: "d", metadata: %{}, slides: &1})
  end

  describe "max_step/1" do
    test "reads the metadata, and gives 1 without the key" do
      assert Render.max_step(%Slide{metadata: %{max_step: 4}}) == 4
      assert Render.max_step(%Slide{metadata: %{}}) == 1
      assert Render.max_step(%Slide{}) == 1
    end
  end

  describe "identify/1" do
    test "numbers each element in document order, and a parent comes before its children" do
      box = %TextBox{on: [%On{}], elements: [%TextArea{on: [%On{}]}, %TextArea{on: [%On{}]}]}
      elements = [box, %TextBox{on: [%On{}]}]

      [slide] = Render.identify(deck([elements])).slides

      assert [%TextBox{el: "s1-e1", elements: [%{el: "s1-e2"}, %{el: "s1-e3"}]}, %{el: "s1-e4"}] =
               slide.elements
    end

    test "gives nil to an element without an on entity, and counts it" do
      [slide] = Render.identify(deck([[%TextBox{}, %TextBox{on: [%On{}]}]])).slides

      assert [%TextBox{el: nil}, %TextBox{el: "s1-e2"}] = slide.elements
    end

    test "uses the number of the slide, and skips a pause" do
      [_, slide] = Render.identify(deck([[], [%Pause{}, %TextBox{on: [%On{}]}]])).slides

      assert [%Pause{}, %TextBox{el: "s2-e1"}] = slide.elements
    end
  end

  describe "attributes/1" do
    test "is empty for an element without steps and without an identity" do
      assert Render.attributes(%TextBox{}) == []
    end

    test "writes data-on with a space between the steps" do
      assert Render.attributes(%TextArea{steps: [2, 3, 5]}) == [{"data-on", "2 3 5"}]
    end

    test "writes data-el from the identity" do
      assert Render.attributes(%TextBox{el: "s1-e2"}) == [{"data-el", "s1-e2"}]
    end

    test "writes both" do
      assert Render.attributes(%TextBox{steps: [1], el: "s1-e1"}) ==
               [{"data-on", "1"}, {"data-el", "s1-e1"}]
    end
  end

  describe "style/1" do
    test "registers each state one time" do
      elements = [
        %TextBox{el: "s1-e1", on: [%On{steps: [1], state: :alert}, %On{steps: [2], state: :dim}]},
        %TextBox{el: "s1-e2", on: [%On{steps: [1], state: :alert}]}
      ]

      style = Render.style(deck([elements]))

      assert style =~
               ~s(@property --alert { syntax: "<number>"; inherits: false; initial-value: 0; })

      assert style =~ "@property --dim {"
      assert length(Regex.scan(~r/@property/, style)) == 2
    end

    test "writes one reveal rule for each step number of the deck" do
      slides = [
        %Slide{elements: [], metadata: %{slide_number: 1, max_step: 2}},
        %Slide{elements: [], metadata: %{slide_number: 2, max_step: 4}}
      ]

      style = Render.style(%Deck{name: "d", metadata: %{}, slides: slides})

      rules = Regex.scan(~r/section\[data-step="(\d)"\] \[data-on~="(\d)"\]/, style)

      assert Enum.map(rules, fn [_, a, b] -> {a, b} end) ==
               [{"1", "1"}, {"2", "2"}, {"3", "3"}, {"4", "4"}]

      assert style =~
               ~s([data-on~="1"] { opacity: 1; visibility: visible; transition-delay: 0s; })
    end

    test "writes one rule for each on entity, in document order, with a selector for each step" do
      elements = [
        %TextBox{
          el: "s1-e1",
          on: [%On{steps: [2, 3], state: :alert}],
          elements: [%TextArea{el: "s1-e2", on: [%On{steps: [3], set: [x: "400px", dim: 0.3]}]}]
        },
        %TextBox{el: "s1-e3", on: [%On{steps: [1], state: :alert, set: [x: "1px"]}]}
      ]

      style = Render.style(deck([elements]))

      assert style =~
               ~s(section[data-step="2"] [data-el="s1-e1"], section[data-step="3"] [data-el="s1-e1"] { --alert: 1; })

      assert style =~ ~s(section[data-step="3"] [data-el="s1-e2"] { --x: 400px; --dim: 0.3; })
      assert style =~ ~s(section[data-step="1"] [data-el="s1-e3"] { --alert: 1; --x: 1px; })

      [first, second, third] = Regex.scan(~r/\[data-el="(s1-e\d)"\] \{/, style)
      assert [first, second, third] |> Enum.map(&List.last/1) == ["s1-e1", "s1-e2", "s1-e3"]
    end

    test "escapes < in a value, so a value cannot close the style element" do
      elements = [%TextBox{el: "s1-e1", on: [%On{steps: [1], set: [x: "</style><b>"]}]}]

      style = Render.style(deck([elements]))

      refute style =~ "</style>"
      assert style =~ ~s(--x: \\3c /style>\\3c b>;)
    end

    test "writes no on rule for an entity without steps" do
      elements = [%TextBox{el: "s1-e1", on: [%On{steps: nil, state: :alert}]}]

      refute Render.style(deck([elements])) =~ "data-el"
    end
  end

  describe "the document" do
    setup do
      html = RenderDeck |> Expresso.parse() |> Expresso.Deck.render()
      {:ok, html: html, document: Floki.parse_document!(html)}
    end

    test "writes data-step 1 and data-max-step on each section", %{document: document} do
      [first, second] = Floki.find(document, "section.slide")

      assert Floki.attribute(first, "data-step") == ["1"]
      assert Floki.attribute(first, "data-max-step") == ["3"]
      assert Floki.attribute(second, "data-step") == ["1"]
      assert Floki.attribute(second, "data-max-step") == ["1"]
    end

    test "writes data-on and data-el on the root tag of an element", %{document: document} do
      [first, second] = Floki.find(document, "#slide-1 .text-box")

      assert Floki.attribute(first, "data-on") == ["1 2 3"]
      assert Floki.attribute(first, "data-el") == ["s1-e1"]
      assert Floki.attribute(second, "data-on") == ["2 3"]
      assert Floki.attribute(second, "data-el") == ["s1-e3"]
    end

    test "writes the attributes on a nested text area", %{document: document} do
      [_, area] = Floki.find(document, "#slide-1 .text-area")

      assert Floki.attribute(area, "data-on") == ["3"]
      assert Floki.attribute(area, "data-el") == ["s1-e4"]
    end

    test "writes no attribute on an element without an overlay", %{document: document} do
      [box] = Floki.find(document, "#slide-2 .text-box")

      assert Floki.attribute(box, "data-on") == []
      assert Floki.attribute(box, "data-el") == []
    end

    test "writes data-view present on the body", %{document: document} do
      assert document |> Floki.find("body") |> Floki.attribute("data-view") == ["present"]
    end

    test "writes one handout page for each step of each slide, in order", %{document: document} do
      pages = Floki.find(document, ".handout .handout-page")

      assert pages
             |> Enum.map(fn page ->
               {Floki.attribute([page], "data-slide"), Floki.attribute([page], "data-step")}
             end) == [{["1"], ["1"]}, {["1"], ["2"]}, {["1"], ["3"]}, {["2"], ["1"]}]
    end

    test "gives a handout page no identifier and not the class of a slide", %{document: document} do
      pages = Floki.find(document, ".handout-page")

      assert Floki.attribute(pages, "id") == []
      assert Floki.find(document, "section.slide") |> length() == 2
    end

    test "writes the same elements in a handout page", %{document: document} do
      [page | _] = Floki.find(document, ".handout .handout-page")
      boxes = Floki.find([page], ".text-box")

      assert Floki.attribute(boxes, "data-on") == ["1 2 3", "2 3"]
      assert Floki.attribute(boxes, "data-el") == ["s1-e1", "s1-e3"]
    end

    test "writes the generated rules into a third style element", %{document: document} do
      [_fonts, _theme, generated] =
        document |> Floki.find("head style") |> Enum.map(&Floki.text/1)

      assert generated =~ "@property --alert"
      assert generated =~ ~s(section[data-step="3"] [data-on~="3"])
      refute generated =~ ~s(section[data-step="4"])
      assert generated =~ ~s(section[data-step="2"] [data-el="s1-e1"] { --alert: 1; })
      assert generated =~ ~s(section[data-step="3"] [data-el="s1-e3"] { --x: 400px; --y: 100px; })
    end
  end
end
