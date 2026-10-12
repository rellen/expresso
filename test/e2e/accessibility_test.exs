defmodule Expresso.E2E.AccessibilityTest do
  use Expresso.E2E, async: false

  # A deck with a heading, an image, a list that builds, a table, code, a chart,
  # a callout and a stat, so axe-core reads many kinds of element.
  defmodule Deck do
    use Expresso

    name "a11y deck"

    slide "intro" do
      heading "Hello"
      text_area(text: "A deck for the accessibility test.")
    end

    slide "detail" do
      heading "The detail"

      list do
        reveal true
        item "One"
        item "Two"
      end

      table do
        row ["Name", "Value"]
        row ["a", "1"]
      end

      callout :tip do
        text_area(text: "A tip.")
      end
    end

    slide "numbers" do
      labels [nil, "The total"]

      code "elixir" do
        text "x = 1 + 2"
      end

      stat 3 do
        label "the total"
        at 2
      end
    end
  end

  @axe Path.expand("../../node_modules/axe-core/axe.min.js", __DIR__)

  # The violations of axe-core in the page, as a list of rule ids and targets.
  defp violations(page) do
    if js(page, "typeof window.axe") != "object" do
      js(page, "(() => { #{File.read!(@axe)}; window.axe = axe; return true })()")
    end

    js(page, """
    axe.run(document).then((result) =>
      result.violations.map((v) => v.id + ": " + v.nodes.map((n) => n.target.join(" ")).join(", ")))
    """)
  end

  test "axe-core finds no violation in each view", %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir))
    assert {"present view", violations(page)} == {"present view", []}

    page |> press("j") |> press("j")

    assert {"present view at a later step", violations(page)} ==
             {"present view at a later step", []}

    press(page, "m")
    assert {"menu", violations(page)} == {"menu", []}
    press(page, "Escape")

    press(page, "?")
    assert {"list of keys", violations(page)} == {"list of keys", []}
    press(page, "Escape")

    press(page, "o")
    assert {"overview", violations(page)} == {"overview", []}
    press(page, "o")

    press(page, "p")
    assert {"handout view", violations(page)} == {"handout view", []}
  end

  test "the live region tells the slide and the step after each move", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))
    announced = fn -> js(page, "document.getElementById('announce').textContent") end

    assert announced.() == ""

    press(page, "j")
    assert announced.() == "Slide 2 of 3, step 1 of 2: The detail"

    press(page, "j")
    assert announced.() == "Step 2 of 2"

    press(page, "End")
    assert announced.() == "Slide 3 of 3, step 1 of 2: numbers"
    assert js(page, "document.getElementById('progress').getAttribute('aria-valuenow')") == "75"
  end

  test "the open menu has the focus, and its cursor is the selected option", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))
    listbox = "document.querySelector('#menu [role=listbox]')"

    press(page, "m")
    assert js(page, "document.activeElement === #{listbox}")
    assert js(page, "#{listbox}.getAttribute('aria-activedescendant')") == "menu-step-0"

    assert js(page, "document.getElementById('menu-step-0').getAttribute('aria-current')") ==
             "step"

    press(page, "ArrowDown")
    assert js(page, "#{listbox}.getAttribute('aria-activedescendant')") == "menu-step-1"

    assert js(page, "document.getElementById('menu-step-1').getAttribute('aria-selected')") ==
             "true"

    assert js(page, "document.getElementById('menu-step-0').getAttribute('aria-selected')") ==
             "false"

    press(page, "Escape")
    refute js(page, "document.activeElement === #{listbox}")
  end
end
