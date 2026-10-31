defmodule Expresso.E2E.MathReduceTest do
  use Expresso.E2E, async: false

  # A β-reduction that a reduce writes. At step 2, the λ gets the color of the
  # binder and the argument gets the color of the argument. At step 3, each
  # bound f gets the color of the binder. At step 4, the kept symbols move
  # down from the first line. At step 5, a copy of g moves into the place of
  # each f, and the line shows.
  defmodule Deck do
    use Expresso

    slide "reduce" do
      math do
        reveal true

        line tex: ~S"(\lambda f.\,f\,(f\,x))\,g"

        reduce :leftmost
      end
    end
  end

  defp center(page, selector) do
    js(page, """
    (() => {
      const b = document.querySelector('.screen .math #{selector}').getBoundingClientRect();
      return [b.left + b.width / 2, b.top + b.height / 2];
    })()
    """)
  end

  defp gap([x1, y1], [x2, y2]), do: :math.sqrt(:math.pow(x1 - x2, 2) + :math.pow(y1 - y2, 2))

  defp copy(name), do: ~s(math.math-copy[data-part="#{name}"])

  defp step(page, n) do
    press(page, "j")
    wait_for(page, "document.querySelector('.screen .slide').dataset.step === '#{n}'")
  end

  defp color(page, selector),
    do: js(page, "getComputedStyle(document.querySelector('.screen .math #{selector}')).color")

  # The computed color of a role of the theme.
  defp role(page, name) do
    js(page, """
    (() => {
      const probe = document.createElement('span');
      probe.style.color = 'var(--#{name})';
      document.body.appendChild(probe);
      const color = getComputedStyle(probe).color;
      probe.remove();
      return color;
    })()
    """)
  end

  # Chromium writes a mixed color as `color(srgb …)` and a plain color as
  # `rgb(…)`, so the test compares the channels as numbers.
  defp channels(text) do
    case Regex.run(~r/^rgba?\(([^)]*)\)$/, text) do
      [_all, values] ->
        values
        |> String.split([",", " "], trim: true)
        |> Enum.take(3)
        |> Enum.map(&(num(&1) / 255))

      nil ->
        [_all, values] = Regex.run(~r/^color\(srgb ([^)]*)\)$/, text)
        values |> String.split(" ", trim: true) |> Enum.take(3) |> Enum.map(&num/1)
    end
  end

  defp num(text) do
    {value, ""} = Float.parse(text)
    value
  end

  defp same_color?(a, b) do
    channels(a) |> Enum.zip(channels(b)) |> Enum.all?(fn {x, y} -> abs(x - y) < 0.01 end)
  end

  # Wait until the element has the color, for up to 3 seconds.
  defp wait_color(page, selector, value, tries \\ 30) do
    cond do
      same_color?(color(page, selector), value) ->
        :ok

      tries == 0 ->
        flunk("#{selector} has #{color(page, selector)} and not #{value}")

      true ->
        Process.sleep(100)
        wait_color(page, selector, value, tries - 1)
    end
  end

  defp moved?(page, name, n), do: gap(center(page, copy(name)), center(page, ".link-#{n}")) < 1

  test "the λ and the argument get colors, then the bound variables, then the body moves, then the copies move",
       %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir))

    wait_for(
      page,
      "document.querySelector('.screen .math #{copy("arg-2@link-3")}').hasAttribute('data-placed')"
    )

    binder = role(page, "binder")
    argument = role(page, "argument")
    refute same_color?(binder, argument)

    black = color(page, ".hit-2")
    source = center(page, ~s([data-part="arg-2"]))

    # Step 2: the λ and the argument get their colors, and the bound
    # variables keep theirs.
    step(page, 2)
    wait_color(page, ~s([data-part="lam-2"]), binder)
    wait_color(page, ~s([data-part="arg-2"]), argument)
    assert same_color?(color(page, ".hit-2"), black)
    refute moved?(page, "keep-2-1@link-2", 2)

    # Step 3: each bound variable gets the color of the binder, and nothing
    # moves.
    step(page, 3)
    wait_color(page, ".hit-2", binder)
    refute moved?(page, "keep-2-1@link-2", 2)
    assert gap(center(page, copy("arg-2@link-1")), source) < 1

    # Step 4: the rest of the body moves, and the copies of the argument wait.
    step(page, 4)
    assert moved?(page, "keep-2-1@link-2", 2)
    assert moved?(page, "keep-2-2@link-4", 4)
    assert gap(center(page, copy("arg-2@link-1")), source) < 1

    assert js(
             page,
             "getComputedStyle(document.querySelector('.screen .math mtd [data-line=\"line2\"]')).opacity"
           ) == "0"

    # Step 5: each copy of the argument moves into the place of a bound
    # variable, and the line shows with its relation and its reason.
    step(page, 5)
    assert moved?(page, "arg-2@link-1", 1)
    assert moved?(page, "arg-2@link-3", 3)

    wait_for(
      page,
      "getComputedStyle(document.querySelector('.screen .math mtd [data-line=\"line2\"]')).opacity === '1'"
    )
  end
end
