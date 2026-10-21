defmodule Expresso.E2E.LayoutCheckTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.{Browser, BrowserContext}

  # Slide 2 holds a formula that is wider than the window. A row of MathML
  # does not break, and the text of `mtext` does. Slide 3 holds a line of code
  # that is too long for its box, and the line shows at step 2.
  defmodule ProblemDeck do
    use Expresso

    name "problem deck"

    slide "good" do
      heading "A good slide"
      text_area(text: "This slide has no problem.")
    end

    slide "wide" do
      math "<math><mrow>#{String.duplicate("<mi>x</mi><mo>+</mo>", 80)}<mn>1</mn></mrow></math>"
    end

    slide "long" do
      code "js" do
        reveal [1, 2]
        text "const a = 1;\nconst b = [#{Enum.join(1..120, ", ")}];\n"
      end
    end
  end

  defmodule GoodDeck do
    use Expresso

    slide "one" do
      heading "One"
      text_area(text: "A short text")
    end

    slide "two" do
      code "elixir" do
        reveal [1, 2]
        text "a = 1\nb = 2\n"
      end
    end
  end

  defp report(page) do
    page
    |> wait_for("document.body.dataset.layout !== undefined")
    |> js("""
    ({
      layout: document.body.dataset.layout,
      heading: document.querySelector("#layout-check p").textContent,
      problems: Array.from(document.querySelectorAll("#layout-check li a"))
        .map((a) => [a.getAttribute("href"), a.textContent])
    })
    """)
  end

  test "?check reports an element past an edge and a line of code that breaks", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    result = page |> open(render(ProblemDeck, tmp_dir) <> "?check") |> report()

    assert result["layout"] == "problems"
    assert result["heading"] == "Layout check at 1280 × 720: 2 problems"

    assert [["#2.1", wide], ["#3.2", long]] = result["problems"]

    assert wide =~
             ~r/^Slide 2, step 1: the math “x\+x\+.*” goes \d+ px past the (left|right) edge$/

    assert long =~ ~r/^Slide 3, step 2: \d+ lines? breaks? in the code “const a = 1;/
  end

  test "?check shows the current step again, and a link of the report goes to its step", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(ProblemDeck, tmp_dir) <> "?check#1.1")
    report(page)

    assert position(page) == "1.1"
    assert js(page, ~s|document.getElementById("slide-1").style.display|) == "flex"

    js(page, ~s|document.querySelector("#layout-check li a").click()|)
    wait_for(page, ~s|location.hash === "#2.1"|)
    assert js(page, ~s|document.getElementById("slide-2").style.display|) == "flex"

    js(page, ~s|document.querySelector("#layout-check button").click()|)
    assert js(page, ~s|document.getElementById("layout-check")|) == nil
  end

  # The long line of `ProblemDeck`, with `wrap`: the line breaks on purpose.
  defmodule WrapDeck do
    use Expresso

    slide "long" do
      code "js" do
        wrap true
        line_numbers true
        text "const a = 1;\n  const b = [#{Enum.join(1..120, ", ")}];\n"
      end
    end
  end

  # A stat that the style sheet of the deck moves past the right edge.
  defmodule StatDeck do
    use Expresso

    css ".far { translate: 80vw 0; }"

    slide "stat" do
      stat 42 do
        label "cups"
        class "far"
      end
    end
  end

  test "?check reports a stat past an edge", %{page: page, tmp_dir: tmp_dir} do
    result = page |> open(render(StatDeck, tmp_dir) <> "?check") |> report()

    assert [["#1.1", stat]] = result["problems"]
    assert stat =~ ~r/^Slide 1, step 1: the stat “.*cups” goes \d+ px past the right edge$/
  end

  # A diagram from D2 holds its drawing in an `svg` inside the root `svg`. The
  # width option applies to the root only, so the inner `svg` keeps the
  # coordinates of the root.
  defmodule NestedDeck do
    use Expresso

    slide "nested" do
      diagram "test/fixtures/nested.svg" do
        width "80%"
        part "box", at: [from: 2]
      end
    end
  end

  test "?check reports no problem for a diagram with an svg inside its root svg", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(NestedDeck, tmp_dir) <> "?check")

    assert report(page)["problems"] == []

    box = &~s|document.querySelector("#slide-1 .diagram #{&1}").getBoundingClientRect()|
    assert js(page, "#{box.("svg.inner")}.left") >= js(page, "#{box.("> svg")}.left") - 1
    assert js(page, "#{box.("svg.inner")}.right") <= js(page, "#{box.("> svg")}.right") + 1
  end

  # A table with a caption, and a table with a long caption that only a screen
  # reader reads. The check measures a table by its box, and a text box by
  # each text in it, so the second table is in a text box.
  defmodule CaptionDeck do
    use Expresso

    slide "captions" do
      table do
        caption "Orders each year"
        header true
        row ["Drink", "Orders"]
        row ["Coffee", "120"]
      end

      text_box do
        table do
          caption "The orders of each drink in each month of the year, in cups"
          caption_hidden true
          row ["Tea", "40"]
        end
      end
    end
  end

  test "?check skips a hidden caption, and a caption shows above its table", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(CaptionDeck, tmp_dir) <> "?check")

    assert report(page)["problems"] == []

    hidden = ~s|document.querySelector("#slide-1 .table-caption-hidden").getBoundingClientRect()|
    assert js(page, "#{hidden}.width") <= 1
    assert js(page, "#{hidden}.height") <= 1

    shown = ~s|document.querySelector("#slide-1 .table-caption").getBoundingClientRect()|
    head = ~s|document.querySelector("#slide-1 thead").getBoundingClientRect()|
    assert js(page, "#{shown}.height") > 1
    assert js(page, "#{shown}.bottom") <= js(page, "#{head}.top")
  end

  test "?check reports no problem for a code with wrap, and a broken line is indented", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(WrapDeck, tmp_dir) <> "?check")
    result = report(page)

    assert result["problems"] == []

    # The second line breaks into rows. The rows after the first start further
    # in: the line has a padding, and the first row moves back by as much.
    line = ~s|document.querySelectorAll("#slide-1 .code .line")[1]|
    height = js(page, "#{line}.offsetHeight")

    row =
      js(
        page,
        ~s|parseFloat(getComputedStyle(document.querySelector("#slide-1 pre")).lineHeight)|
      )

    padding = js(page, "parseFloat(getComputedStyle(#{line}).paddingInlineStart)")
    indent = js(page, "parseFloat(getComputedStyle(#{line}).textIndent)")

    assert height > 2 * row
    assert padding > 0
    assert_in_delta indent, -padding, 0.5
  end

  test "?check reports no problem for a deck that fits", %{page: page, tmp_dir: tmp_dir} do
    result = page |> open(render(GoodDeck, tmp_dir) <> "?check") |> report()

    assert result["layout"] == "ok"
    assert result["heading"] == "Layout check at 1280 × 720: no problems"
    assert result["problems"] == []
  end

  test "a deck without ?check gets no report", %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(ProblemDeck, tmp_dir))

    assert js(page, ~s|document.getElementById("layout-check")|) == nil
    assert js(page, "document.body.dataset.layout") == nil
  end

  test "the talk about Line 4 fits a window of 1920 × 1080", %{
    browser: browser,
    tmp_dir: tmp_dir
  } do
    {:ok, context} =
      Browser.new_context(browser.guid,
        timeout: 10_000,
        viewport: %{width: 1920, height: 1080},
        reduced_motion: "reduce"
      )

    on_exit(fn -> BrowserContext.close(context.guid, timeout: 10_000) end)
    {:ok, page} = BrowserContext.new_page(context.guid, timeout: 10_000)

    {value, _bindings} = Code.eval_file("examples/line4/line4.exs")
    result = page |> open(render(value, tmp_dir) <> "?check") |> report()

    assert result["problems"] == []
    assert result["layout"] == "ok"
  end

  # The example of "Read a report" in docs/how-to/check-the-layout.md has two
  # problems on purpose, and the guide shows its report.
  @broken "examples/animations/layout_check.exs"

  # The size of the GIFs of the guides, of the presenter pages and of the themes.
  test "each example deck fits a window of 1280 × 720", %{browser: browser, tmp_dir: tmp_dir} do
    {:ok, context} =
      Browser.new_context(browser.guid,
        timeout: 10_000,
        viewport: %{width: 1280, height: 720},
        reduced_motion: "reduce"
      )

    on_exit(fn -> BrowserContext.close(context.guid, timeout: 10_000) end)
    {:ok, page} = BrowserContext.new_page(context.guid, timeout: 10_000)

    decks = Mix.Tasks.Expresso.Gifs.examples() |> Enum.map(& &1.deck) |> Enum.uniq()

    problems =
      for deck <- decks,
          {value, _bindings} = Code.eval_file(deck),
          problem <-
            page |> open(render(value, tmp_dir) <> "?check") |> report() |> Map.fetch!("problems"),
          do: {deck, problem}

    {broken, problems} = Enum.split_with(problems, &(elem(&1, 0) == @broken))

    assert problems == []

    assert Enum.map(broken, fn {_deck, [position, _text]} -> position end) == ["#1.1", "#2.2"]
  end
end
