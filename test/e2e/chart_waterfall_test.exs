defmodule Expresso.E2E.ChartWaterfallTest do
  use Expresso.E2E, async: false

  # The start and the two totals show alone at the first step. Each change
  # shows at its own step, from step 2.
  defmodule RevealDeck do
    use Expresso

    slide "cash" do
      chart :waterfall do
        title "Cash"

        categories [
          "Start",
          "Sales",
          "Services",
          "Mid year",
          "Grants",
          "Interest",
          "Costs",
          "End"
        ]

        series "Cash", [50, 40, 30, :total, 10, 20, -50, :total]
        reveal true
      end
    end
  end

  # The total "Mid year" shows with "Services" at step 3, and "End" with
  # "Costs" at step 6.
  defmodule CompleteDeck do
    use Expresso

    slide "cash" do
      chart :waterfall do
        title "Cash"

        categories [
          "Start",
          "Sales",
          "Services",
          "Mid year",
          "Grants",
          "Interest",
          "Costs",
          "End"
        ]

        series "Cash", [50, 40, 30, :total, 10, 20, -50, :total]
        reveal true
        totals :complete
      end
    end
  end

  # The change "Costs" is in focus at step 1, and the three totals at step 2.
  defmodule HighlightDeck do
    use Expresso

    slide "cash" do
      chart :waterfall do
        title "Cash"
        categories ["Start", "Sales", "Costs", "End"]
        series "Cash", [50, 40, -30, :total]
        highlight ["Costs", ["Start", "End"]]
      end
    end
  end

  # The total "End" grows from 60 in 2024 to 70 in 2025 at step 2.
  defmodule FramesDeck do
    use Expresso

    slide "cash" do
      chart :waterfall do
        title "Cash"
        categories ["Start", "Sales", "Costs", "End"]

        frame "2024" do
          series "Cash", [50, 40, -30, :total]
        end

        frame "2025" do
          series "Cash", [60, 50, -40, :total]
        end
      end
    end
  end

  # The fill opacity of each column of the present view, in the order of the
  # document.
  @opacities """
  Array.from(document.querySelectorAll(".screen .chart .chart-waterfall-bar"))
    .map((column) => getComputedStyle(column).fillOpacity).join(" ")
  """

  # The text of the total "End" of the frames deck, and its value from its
  # height and the height and the text of the start.
  @frame_end """
  (() => {
    const totals = document.querySelectorAll(".screen .chart > svg .chart-waterfall-total");
    const labels = document.querySelectorAll(".screen .chart > svg .chart-value");
    const height = (rect) => rect.getBoundingClientRect().height;
    const start = Number(labels[0].textContent);
    return labels[labels.length - 1].textContent + " " +
      Math.round((height(totals[1]) / height(totals[0])) * start);
  })()
  """

  # The text of the total "End" in the present view, and its height in the
  # units of the start, which is 50.
  @last """
  (() => {
    const totals = document.querySelectorAll(".screen .chart .chart-waterfall-total");
    const height = (rect) => rect.getBoundingClientRect().height;
    const label = document.querySelectorAll(".screen .chart .chart-value")[2].textContent;
    return label + " " + Math.round((height(totals[2]) / height(totals[0])) * 50);
  })()
  """

  # The visibility of each total of the present view, in the order of the
  # document.
  @shown """
  Array.from(document.querySelectorAll(".screen .chart .chart-waterfall-total"))
    .map((total) => getComputedStyle(total).visibility).join(" ")
  """

  test "each later total grows and counts at the step of each change", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(RevealDeck, tmp_dir))
    wait_for(page, "(#{@last}) === '50 50'")

    for value <- [90, 120, 130, 150, 100] do
      press(page, "ArrowRight")
      wait_for(page, "(#{@last}) === '#{value} #{value}'")
    end
  end

  test "totals :complete shows each later total at the step of the change before it", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(CompleteDeck, tmp_dir))
    wait_for(page, "(#{@shown}) === 'visible hidden hidden'")

    for {steps, shown} <- [{2, "visible visible hidden"}, {3, "visible visible visible"}] do
      for _step <- 1..steps, do: press(page, "ArrowRight")
      wait_for(page, "(#{@shown}) === '#{shown}'")
    end
  end

  test "each group of highlight dims the other columns", %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(HighlightDeck, tmp_dir))

    wait_for(page, "(#{@opacities}) === '0.3 0.3 1 0.3'")
    press(page, "ArrowRight")
    wait_for(page, "(#{@opacities}) === '1 0.3 0.3 1'")
  end

  test "each frame moves the columns, and the totals count to the next frame", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(FramesDeck, tmp_dir))

    # The total "End" is the second total, and the start is the first.
    wait_for(page, "(#{@frame_end}) === '60 60'")
    press(page, "ArrowRight")
    wait_for(page, "(#{@frame_end}) === '70 70'")
  end
end
