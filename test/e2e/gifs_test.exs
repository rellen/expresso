defmodule Expresso.E2E.GifsTest do
  use Expresso.E2E, async: false

  import ExUnit.CaptureIO

  alias Expresso.Test.GifDecoder

  test "mix expresso.gifs records a GIF of an example", %{tmp_dir: tmp_dir} do
    output = capture_io(fn -> Mix.Tasks.Expresso.Gifs.run([tmp_dir, "overlay-at"]) end)

    assert output =~ "overlay-at.gif"
    assert [gif] = tmp_dir |> Path.join("*.gif") |> Path.wildcard()

    decoded = gif |> File.read!() |> GifDecoder.decode()
    assert {decoded.width, decoded.height} == {800, 450}

    # The first frame, then for each of the two keys the 8 frames of a fade of
    # 300 ms and one frame that holds the result. The last frame of a fade
    # shows the result, so the frame that holds the result adds its delay to it.
    fade = List.duplicate(40, 7)
    assert Enum.map(decoded.frames, & &1.delay) == [1200] ++ fade ++ [940] ++ fade ++ [1640]
  end

  test "mix expresso.gifs refuses a name that is not an example", %{tmp_dir: tmp_dir} do
    assert_raise Mix.Error, ~r/unknown example: no-such-example/, fn ->
      Mix.Tasks.Expresso.Gifs.run([tmp_dir, "no-such-example"])
    end
  end
end
