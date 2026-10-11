defmodule Expresso.E2E.TocTest do
  use Expresso.E2E, async: false

  # An agenda that builds, then three sections. The first slide of the third
  # section has a recap.
  defmodule Deck do
    use Expresso

    name "toc deck"

    slide "agenda" do
      toc do
        reveal true
        dim true
      end
    end

    slide "why" do
      section "Why"
    end

    slide "how" do
      section "How"
    end

    slide "end" do
      section "End"
      toc()
    end
  end

  setup %{page: page, tmp_dir: tmp_dir} do
    %{page: open(page, render(Deck, tmp_dir))}
  end

  # The opacity and the color of each entry of the toc of a slide.
  defp entries(page, slide) do
    js(page, """
    Array.from(
      document.querySelectorAll(".screen #slide-#{slide} .toc-entry"),
      (entry) => [Number(getComputedStyle(entry).opacity), getComputedStyle(entry).color]
    )
    """)
    |> Enum.map(fn [opacity, color] -> {opacity, rgb(color)} end)
  end

  defp color(page, name) do
    js(page, """
    (() => {
      const probe = document.createElement("span");
      probe.style.color = "var(#{name})";
      document.body.append(probe);
      const color = getComputedStyle(probe).color;
      probe.remove();
      return color;
    })()
    """)
  end

  defp center(page, selector) do
    js(page, """
    (() => {
      const box = [...document.querySelectorAll('#{selector}')]
        .map((element) => element.getBoundingClientRect())
        .find((box) => box.width > 0);
      return { x: box.x + box.width / 2, y: box.y + box.height / 2 };
    })()
    """)
  end

  test "the agenda shows one entry at each step, and dims each earlier entry", %{page: page} do
    text = color(page, "--text")
    dim = color(page, "--text-dim")

    assert entries(page, 1) == [{1, text}, {0, text}, {0, text}]

    press(page, "j")
    assert entries(page, 1) == [{1, dim}, {1, text}, {0, text}]

    press(page, "j")
    assert entries(page, 1) == [{1, dim}, {1, dim}, {1, text}]
    assert position(page) == "1.3"
  end

  test "the recap gives the current section the accent color, and dims the rest", %{page: page} do
    page =
      open(page, page |> js("location.href") |> String.replace(~r/#.*$/, "") |> Kernel.<>("#4"))

    accent = color(page, "--accent")
    dim = color(page, "--text-dim")

    assert entries(page, 4) == [{1, dim}, {1, dim}, {1, accent}]
  end

  test "a click on an entry goes to the first slide of its section", %{page: page} do
    press(page, "j")
    %{"x" => x, "y" => y} = center(page, ".screen #slide-1 .toc-entry:nth-child(2) a")

    click(page, x, y)
    assert position(page) == "3.1"
  end
end
