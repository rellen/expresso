defmodule Expresso.Recorder.FramesTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Expresso.Recorder.Frames

  test "times returns one frame each 40 ms, and a last frame at the end" do
    assert Frames.times(200) == [40, 80, 120, 160, 200]
    assert Frames.times(300) == [40, 80, 120, 160, 200, 240, 280, 300]
  end

  test "times returns no frame for an animation of no time" do
    assert Frames.times(0) == []
    assert Frames.times(-5) == []
    assert Frames.times(nil) == []
  end

  test "times takes a number of frames per second" do
    assert Frames.times(100, 10) == [100]
    assert Frames.times(250, 10) == [100, 200, 250]
  end

  test "the last key of an example holds its frame longer" do
    assert Frames.hold(true) > Frames.hold(false)
  end

  property "times rise, end at the end of the animation, and skip no frame" do
    check all finish <- integer(1..5000), fps <- integer(1..60), max_runs: 2000 do
      all = Frames.times(finish, fps)
      step = 1000 / fps

      assert List.last(all) == finish
      assert hd(all) > 0

      for [before, next] <- Enum.chunk_every(all, 2, 1, :discard) do
        assert next > before
        assert next - before <= Float.ceil(step) + 1
      end
    end
  end
end
