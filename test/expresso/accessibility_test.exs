defmodule Expresso.AccessibilityTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder

  # A deck of a slide with a heading and one step, and a slide with no heading
  # and two steps, with a label on step 2.
  defp document do
    [
      Builder.slide("intro", heading: "Hello"),
      Builder.slide("detail",
        labels: [nil, "The answer"],
        elements: [Builder.text_area(text: "a"), Builder.text_area(text: "b", at: 2)]
      )
    ]
    |> Builder.deck(name: "a11y")
    |> Expresso.Deck.render()
    |> LazyHTML.from_document()
  end

  # The words of the text nodes of a node, with one space between two words.
  # `LazyHTML.text/1` joins two text nodes with no space, such as "2" and
  # "The answer". Floki took the option `sep: " "` for this.
  defp words(node) do
    node
    |> LazyHTML.to_tree()
    |> text_nodes()
    |> Enum.join(" ")
    |> String.split()
    |> Enum.join(" ")
  end

  defp text_nodes(nodes) when is_list(nodes), do: Enum.flat_map(nodes, &text_nodes/1)
  defp text_nodes({_tag, _attributes, children}), do: text_nodes(children)
  defp text_nodes({:comment, _text}), do: []
  defp text_nodes(text) when is_binary(text), do: [text]

  test "the two views, the progress bar and the live region are in the main landmark" do
    document = document()

    assert count(document, "body > main.views") == 1
    assert count(document, "main.views > .screen") == 1
    assert count(document, "main.views > .handout") == 1
    assert count(document, "main.views > #progress") == 1
    assert count(document, "main.views > #announce") == 1
    assert count(document, "main.views:not(:has(#menu)):not(:has(#help))") == 1
    assert count(document, "#menu") == 1
    assert count(document, "#help") == 1
  end

  test "each slide is a group with the role description slide and a name" do
    document = document()
    [first, second] = LazyHTML.query(document, ".screen > section.slide") |> Enum.to_list()

    for slide <- [first, second] do
      assert LazyHTML.attribute(slide, "role") == ["group"]
      assert LazyHTML.attribute(slide, "aria-roledescription") == ["slide"]
    end

    assert LazyHTML.attribute(first, "aria-label") == ["Slide 1 of 2: Hello"]
    assert LazyHTML.attribute(second, "aria-label") == ["Slide 2 of 2: detail"]
  end

  test "a page of the handout view also gives its step, when its slide has more than one" do
    labels =
      document()
      |> LazyHTML.query(".handout > section.handout-page")
      |> Enum.flat_map(&LazyHTML.attribute(&1, "aria-label"))

    assert labels == [
             "Slide 1 of 2: Hello",
             "Slide 2 of 2, step 1 of 2: detail",
             "Slide 2 of 2, step 2 of 2: detail"
           ]
  end

  test "the progress bar is a progressbar, and the live region is a status" do
    document = document()
    [progress] = LazyHTML.query(document, "#progress") |> Enum.to_list()

    assert LazyHTML.attribute(progress, "role") == ["progressbar"]
    assert LazyHTML.attribute(progress, "aria-label") == ["Progress"]
    assert LazyHTML.attribute(progress, "aria-valuemin") == ["0"]
    assert LazyHTML.attribute(progress, "aria-valuemax") == ["100"]
    assert document |> LazyHTML.query("#announce") |> LazyHTML.attribute("role") == ["status"]
  end

  test "the menu is a listbox of groups of options, with a name for each option" do
    document = document()
    [list] = LazyHTML.query(document, "#menu > ol") |> Enum.to_list()

    assert LazyHTML.attribute(list, "role") == ["listbox"]
    assert LazyHTML.attribute(list, "tabindex") == ["0"]

    assert document
           |> LazyHTML.query("#menu li.menu-group")
           |> Enum.flat_map(&LazyHTML.attribute(&1, "role")) ==
             ["none", "none"]

    groups = LazyHTML.query(document, "#menu ol.menu-steps")
    assert Enum.flat_map(groups, &LazyHTML.attribute(&1, "role")) == ["group", "group"]

    assert Enum.flat_map(groups, &LazyHTML.attribute(&1, "aria-labelledby")) ==
             ["menu-name-1", "menu-name-2"]

    options = LazyHTML.query(document, "#menu li.menu-step")
    assert Enum.flat_map(options, &LazyHTML.attribute(&1, "role")) == ~w(option option option)

    assert Enum.flat_map(options, &LazyHTML.attribute(&1, "id")) ==
             ~w(menu-step-0 menu-step-1 menu-step-2)

    # The name of an option comes from its text, with a hidden word in front of
    # the number, so the visible text is a part of the name.
    assert Enum.map(options, &words/1) == ["Step 1", "Step 1", "Step 2 The answer"]

    # A slide with one step and no label shows the row of its step in the place
    # of the row of the slide, so the option takes the name of the slide.
    assert Enum.map(options, &LazyHTML.attribute(&1, "aria-labelledby")) == [
             ["menu-name-1"],
             [],
             []
           ]
  end
end
