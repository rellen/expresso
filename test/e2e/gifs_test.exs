defmodule Expresso.E2E.GifsTest do
  use Expresso.E2E, async: false

  import ExUnit.CaptureIO

  # The number of frames of a GIF: one graphic control extension for each
  # frame.
  defp frames(gif), do: gif |> :binary.matches(<<0x21, 0xF9, 0x04>>) |> length()

  test "mix expresso.gifs records a GIF of an example", %{tmp_dir: tmp_dir} do
    output = capture_io(fn -> Mix.Tasks.Expresso.Gifs.run([tmp_dir, "overlay-at"]) end)

    assert output =~ "overlay-at.gif"
    assert [gif] = tmp_dir |> Path.join("*.gif") |> Path.wildcard()

    bytes = File.read!(gif)
    assert <<"GIF89a", width::little-16, height::little-16, _rest::binary>> = bytes
    assert {width, height} == {800, 450}

    # The first frame, then for each of the two keys the 8 frames of a fade of
    # 300 ms and one frame that holds the result.
    assert frames(bytes) == 1 + 2 * (8 + 1)
  end

  test "mix expresso.gifs refuses a name that is not an example", %{tmp_dir: tmp_dir} do
    assert_raise Mix.Error, ~r/unknown example: no-such-example/, fn ->
      Mix.Tasks.Expresso.Gifs.run([tmp_dir, "no-such-example"])
    end
  end
end
