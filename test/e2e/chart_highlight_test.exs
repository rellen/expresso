defmodule Expresso.E2E.ChartHighlightTest do
  use Expresso.E2E, async: false

  # The series "Returns" is in focus at step 1, and the series "Orders" at
  # step 2.
  defmodule Deck do
    use Expresso

    slide "orders" do
      chart :bar do
        title "Orders and returns"
        categories ["2023", "2024"]
        highlight ["Returns", "Orders"]
        series "Orders", [180, 240]
        series "Returns", [22, 19]
      end
    end
  end

  # The first series dims at step 2, when the second series shows.
  defmodule DimDeck do
    use Expresso

    slide "orders" do
      chart :bar do
        title "Orders and returns"
        categories ["2023", "2024"]
        reveal true
        dim true
        series "Orders", [180, 240]
        series "Returns", [22, 19]
      end
    end
  end

  # The fill opacity of the first bar of each series of a chart in a scope, in
  # the order of the series.
  defp opacities(page, scope) do
    page
    |> js("""
    Array.from(document.querySelectorAll("#{scope} .chart .chart-series")).map((series) =>
      getComputedStyle(series.querySelector(".chart-bar")).fillOpacity)
    """)
    |> Enum.map(&String.to_float(if(&1 =~ ".", do: &1, else: &1 <> ".0")))
  end

  defp dim(page, scope \\ ".screen"), do: Enum.map(opacities(page, scope), &(&1 < 1))

  # The fill of the first value of each series of the present view, and the
  # computed colors of `--text` and `--text-dim`.
  defp value_fills(page) do
    page
    |> js("""
    (() => {
      const probe = (role) => {
        const span = document.createElement("span");
        span.style.color = `var(${role})`;
        document.body.append(span);
        const color = getComputedStyle(span).color;
        span.remove();
        return color;
      };
      const values = Array.from(document.querySelectorAll(".screen .chart .chart-series"))
        .map((series) => getComputedStyle(series.querySelector(".chart-value")).fill);
      return [values, probe("--text"), probe("--text-dim")];
    })()
    """)
    |> then(fn [values, text, dim] -> {Enum.map(values, &rgb/1), rgb(text), rgb(dim)} end)
  end

  test "the series in focus shows in full, and each other series dims", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))

    assert dim(page) == [true, false]

    press(page, "j")
    assert position(page) == "1.2"
    assert dim(page) == [false, true]
  end

  test "a mark fades to 0.3, and a value takes the dimmed color of the text", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))

    assert opacities(page, ".screen") == [0.3, 1.0]
    assert {[dimmed, full], text, text_dim} = value_fills(page)
    assert text != text_dim
    assert {dimmed, full} == {text_dim, text}
  end

  test "d shows each series in full until the next step, and the handout view keeps the dimming",
       %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir))

    press(page, "d")
    assert js(page, "document.body.dataset.undim") == "true"
    assert dim(page) == [false, false]

    press(page, "j")
    assert position(page) == "1.2"
    assert dim(page) == [false, true]

    press(page, "d")
    press(page, "p")
    assert dim(page, ".handout-page[data-step='1']") == [true, false]
  end

  test "dim true dims an earlier series in the same way, and d shows it in full", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(DimDeck, tmp_dir))
    assert dim(page) == [false, false]

    press(page, "j")
    assert position(page) == "1.2"
    assert opacities(page, ".screen") == [0.3, 1.0]
    assert {[dimmed, _full], _text, text_dim} = value_fills(page)
    assert dimmed == text_dim

    press(page, "d")
    assert dim(page) == [false, false]
  end
end
