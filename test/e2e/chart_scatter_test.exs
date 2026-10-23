defmodule Expresso.E2E.ChartScatterTest do
  use Expresso.E2E, async: false

  # The group "EU" shows at step 1, and the group "US" at step 2.
  defmodule RevealDeck do
    use Expresso

    slide "services" do
      chart :scatter do
        title "Services"
        reveal true
        point "api", x: 1200, y: 840, color: "EU"
        point "web", x: 400, y: 2100, color: "US"
        point "jobs", x: 900, y: 150, color: "EU"
      end
    end
  end

  # The point "web" is in focus at step 1, and the category "EU" at step 2.
  defmodule HighlightDeck do
    use Expresso

    slide "services" do
      chart :scatter do
        title "Services"
        labels :all
        highlight ["web", "EU"]
        point "api", x: 1200, y: 840, color: "EU"
        point "web", x: 400, y: 2100, color: "US"
        point "jobs", x: 900, y: 150, color: "EU"
      end
    end
  end

  # The point "Japan" moves from its place in 2000 to its place in 2020 at
  # step 2.
  defmodule FramesDeck do
    use Expresso

    slide "income" do
      chart :scatter do
        title "Income and life"
        labels :all

        frame "2000" do
          point "Japan", x: 30, y: 81, size: 127
          point "Chile", x: 10, y: 77, size: 15
        end

        frame "2020" do
          point "Japan", x: 40, y: 84, size: 126
          point "Chile", x: 15, y: 80, size: 19
        end
      end
    end
  end

  # The visibility of each mark of the present view, by the name of its
  # point, in the order of the document.
  @shown """
  Array.from(document.querySelectorAll(".screen .chart .chart-point"))
    .map((mark) => getComputedStyle(mark).visibility).join(" ")
  """

  # The fill opacity of each mark of the present view, in the order of the
  # document.
  @opacities """
  Array.from(document.querySelectorAll(".screen .chart .chart-point"))
    .map((mark) => getComputedStyle(mark).fillOpacity).join(" ")
  """

  test "reveal shows each category of the color at its own step", %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(RevealDeck, tmp_dir))

    # The order of the document: the group EU with api and jobs, then the
    # group US with web.
    wait_for(page, "(#{@shown}) === 'visible visible hidden'")
    press(page, "ArrowRight")
    wait_for(page, "(#{@shown}) === 'visible visible visible'")
  end

  test "each mark moves to its place in the next frame", %{page: page, tmp_dir: tmp_dir} do
    url = render(FramesDeck, tmp_dir)
    html = File.read!(String.replace_prefix(url, "file://", ""))

    # The place of Japan in 2000 is the fallback of its style, and its place
    # in 2020 is the value of the rule of step 2.
    [first] = Regex.run(~r/--chart-u: var\(--x1, ([\d.]+)\)/, html, capture: :all_but_first)

    [second] =
      Regex.run(~r/data-step="2"\][^{]*\{[^}]*--x1: ([\d.]+);/, html, capture: :all_but_first)

    assert first != second

    place = """
    getComputedStyle(document.querySelector(".screen .chart .chart-point"))
      .getPropertyValue("--chart-u").trim()
    """

    page = open(page, url)
    wait_for(page, "Math.abs(Number(#{place}) - #{first}) < 0.5")
    press(page, "ArrowRight")
    wait_for(page, "Math.abs(Number(#{place}) - #{second}) < 0.5")
  end

  test "highlight puts a point, then a category in focus, and the rest dims", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(HighlightDeck, tmp_dir))

    # The order of the document: the group EU with api and jobs, then the
    # group US with web.
    wait_for(page, "(#{@opacities}) === '0.3 0.3 1'")
    press(page, "ArrowRight")
    wait_for(page, "(#{@opacities}) === '1 1 0.3'")
  end
end
