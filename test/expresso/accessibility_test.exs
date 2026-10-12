defmodule Expresso.AccessibilityTest do
  use ExUnit.Case, async: true

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
    |> Floki.parse_document!()
  end

  test "the two views, the progress bar and the live region are in the main landmark" do
    document = document()

    assert [_main] = Floki.find(document, "body > main.views")
    assert [_screen] = Floki.find(document, "main.views > .screen")
    assert [_handout] = Floki.find(document, "main.views > .handout")
    assert [_progress] = Floki.find(document, "main.views > #progress")
    assert [_announce] = Floki.find(document, "main.views > #announce")
    assert Floki.find(document, "main #menu, main #help") == []
  end

  test "each slide is a group with the role description slide and a name" do
    document = document()
    [first, second] = Floki.find(document, ".screen > section.slide")

    for slide <- [first, second] do
      assert Floki.attribute(slide, "role") == ["group"]
      assert Floki.attribute(slide, "aria-roledescription") == ["slide"]
    end

    assert Floki.attribute(first, "aria-label") == ["Slide 1 of 2: Hello"]
    assert Floki.attribute(second, "aria-label") == ["Slide 2 of 2: detail"]
  end

  test "a page of the handout view also gives its step, when its slide has more than one" do
    labels =
      document()
      |> Floki.find(".handout > section.handout-page")
      |> Enum.flat_map(&Floki.attribute(&1, "aria-label"))

    assert labels == [
             "Slide 1 of 2: Hello",
             "Slide 2 of 2, step 1 of 2: detail",
             "Slide 2 of 2, step 2 of 2: detail"
           ]
  end

  test "the progress bar is a progressbar, and the live region is a status" do
    document = document()
    [progress] = Floki.find(document, "#progress")

    assert Floki.attribute(progress, "role") == ["progressbar"]
    assert Floki.attribute(progress, "aria-label") == ["Progress"]
    assert Floki.attribute(progress, "aria-valuemin") == ["0"]
    assert Floki.attribute(progress, "aria-valuemax") == ["100"]
    assert document |> Floki.find("#announce") |> Floki.attribute("role") == ["status"]
  end

  test "the menu is a listbox of groups of options, with a name for each option" do
    document = document()
    [list] = Floki.find(document, "#menu > ol")

    assert Floki.attribute(list, "role") == ["listbox"]
    assert Floki.attribute(list, "tabindex") == ["0"]

    assert document
           |> Floki.find("#menu li.menu-group")
           |> Enum.flat_map(&Floki.attribute(&1, "role")) ==
             ["none", "none"]

    groups = Floki.find(document, "#menu ol.menu-steps")
    assert Enum.flat_map(groups, &Floki.attribute(&1, "role")) == ["group", "group"]

    assert Enum.flat_map(groups, &Floki.attribute(&1, "aria-labelledby")) ==
             ["menu-name-1", "menu-name-2"]

    options = Floki.find(document, "#menu li.menu-step")
    assert Enum.flat_map(options, &Floki.attribute(&1, "role")) == ~w(option option option)

    assert Enum.flat_map(options, &Floki.attribute(&1, "id")) ==
             ~w(menu-step-0 menu-step-1 menu-step-2)

    # The name of an option comes from its text, with a hidden word in front of
    # the number, so the visible text is a part of the name.
    assert Enum.map(options, &(&1 |> Floki.text(sep: " ") |> String.split() |> Enum.join(" "))) ==
             ["Step 1", "Step 1", "Step 2 The answer"]

    # A slide with one step and no label shows the row of its step in the place
    # of the row of the slide, so the option takes the name of the slide.
    assert Enum.map(options, &Floki.attribute(&1, "aria-labelledby")) == [["menu-name-1"], [], []]
  end
end
