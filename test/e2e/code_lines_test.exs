defmodule Expresso.E2E.CodeLinesTest do
  use Expresso.E2E, async: false

  import ExUnit.CaptureIO

  # Each code element has three lines. "toml" has no lexer, so its element
  # shows plain text, as the element with no language does.
  defmodule Deck do
    use Expresso

    slide "lines" do
      code do
        text "a = 1\n\nb = 2"
      end

      code do
        line_numbers true
        text "a = 1\n\nb = 2"
      end

      code "elixir" do
        line_numbers true
        text "a = 1\n\nb = 2"
      end
    end
  end

  # The height of each line, as a multiple of the size of its font.
  defp heights(page) do
    js(page, """
    Array.from(document.querySelectorAll(".screen .code")).map((code) =>
      Array.from(code.querySelectorAll(".line")).map((line) =>
        line.getBoundingClientRect().height / parseFloat(getComputedStyle(line).fontSize)))
    """)
  end

  test "each line of a code element takes one row, with and without line numbers", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))
    heights = heights(page)

    assert length(heights) == 3

    for {lines, index} <- Enum.with_index(heights) do
      assert length(lines) == 3
      assert Enum.all?(lines, &(&1 > 0.8 and &1 < 2)), "code #{index}: #{inspect(lines)}"
    end
  end

  test "a language with no lexer shows the same rows as no language", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    {path, _warning} = with_io(:stderr, fn -> render(toml_deck(), tmp_dir) end)
    page = open(page, path)

    assert [lines] = heights(page)
    assert Enum.all?(lines, &(&1 > 0.8 and &1 < 2)), inspect(lines)
  end

  defp toml_deck do
    [
      Expresso.Builder.slide("toml",
        elements: [Expresso.Builder.code("toml", text: "a = 1\n\nb = 2", line_numbers: true)]
      )
    ]
    |> Expresso.Builder.deck()
  end
end
