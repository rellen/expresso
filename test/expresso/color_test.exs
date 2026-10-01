defmodule Expresso.ColorTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Expresso.Color

  doctest Expresso.Color

  defp color do
    map(tuple({integer(0..255), integer(0..255), integer(0..255)}), fn {r, g, b} ->
      "#" <>
        Enum.map_join(
          [r, g, b],
          &(&1 |> Integer.to_string(16) |> String.pad_leading(2, "0") |> String.downcase())
        )
    end)
  end

  test "the contrast of the colors of WCAG examples" do
    assert Float.round(Color.contrast("#767676", "#ffffff"), 2) == 4.54
    assert Float.round(Color.contrast("#595959", "#ffffff"), 2) == 7.0
    assert Color.contrast("#ffffff", "#ffffff") == 1.0
  end

  property "the contrast of two colors is from 1 to 21, in either order" do
    check all a <- color(), b <- color(), max_runs: 300 do
      ratio = Color.contrast(a, b)
      assert ratio >= 1.0 and ratio <= 21.0
      assert ratio == Color.contrast(b, a)
    end
  end

  property "an adjusted color meets the minimum, or no lightness can" do
    check all foreground <- color(), background <- color(), max_runs: 300 do
      case Color.adjust(foreground, background, 4.5) do
        {:ok, color, change} ->
          assert Color.contrast(color, background) >= 4.5
          assert change >= 0.0 and change <= 1.0

        :error ->
          # Only a background near the middle has no color at 4.5:1.
          assert Color.contrast("#000000", background) < 4.6 or
                   Color.contrast("#ffffff", background) < 4.6
      end
    end
  end

  test "an adjusted color keeps a color that already meets the minimum" do
    assert Color.adjust("#000000", "#ffffff", 4.5) == {:ok, "#000000", 0.0}
  end

  test "a blend of no opacity is the background, and of full opacity the foreground" do
    assert Color.blend("#123456", "#abcdef", 0.0) == "#abcdef"
    assert Color.blend("#123456", "#abcdef", 1.0) == "#123456"
  end
end
