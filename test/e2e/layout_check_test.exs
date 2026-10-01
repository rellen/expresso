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
end
