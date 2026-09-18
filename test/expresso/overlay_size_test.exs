defmodule Expresso.Overlay.SizeTest do
  use ExUnit.Case, async: true

  alias Expresso.Overlay.Size
  alias Expresso.Slide

  defp warnings(fields) do
    %Slide{} |> struct!(fields) |> Size.slide() |> Enum.map(&message/1)
  end

  defp message({text, _anno}), do: text
  defp message(text), do: text

  test "gives no warning for a slide of few steps" do
    assert warnings(name: "s", metadata: %{max_step: Size.maximum()}) == []
    assert warnings(name: "s", metadata: %{max_step: 1}) == []
  end

  test "gives no warning for a slide with no metadata" do
    assert warnings(name: "s") == []
    assert Size.slide(%Slide{}) == []
  end

  test "gives a warning above the maximum" do
    [message] = warnings(name: "typo", metadata: %{max_step: Size.maximum() + 1})

    assert message =~ "deck -> slide -> typo"
    assert message =~ "the slide takes #{Size.maximum() + 1} steps"
    assert message =~ "#{Size.maximum()} is the usual maximum"
    assert message =~ "handout pages"
  end

  test "gives no warning for a slide with a steps option" do
    assert warnings(name: "s", steps: 200, metadata: %{max_step: 200}) == []
  end

  test "writes the path of a slide with no name" do
    [message] = warnings(metadata: %{max_step: 1000})

    assert message =~ "deck -> slide: "
  end
end
