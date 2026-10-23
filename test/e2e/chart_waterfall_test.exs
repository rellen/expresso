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
end
