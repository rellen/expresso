defmodule Expresso.Recorder.Frames do
  @moduledoc """
  Calculates the timing of the frames of a GIF of `Expresso.Recorder`

  This module does not touch the browser, so each function has a unit test.
  """

  @fps 25
  @start 1200

  @doc "Return the frames per second of an animation in a GIF"
  @spec fps() :: pos_integer()
  def fps, do: @fps

  @doc "Return the time that a GIF shows the first frame, before the first key, in milliseconds"
  @spec start() :: pos_integer()
  def start, do: @start

  @doc """
  Return the time of each frame of an animation that lasts `finish` milliseconds

  The first frame comes one frame after the start, because the frame before
  the key already shows the start. The last frame shows the end. An animation
  of no time returns no frame.
  """
  @spec times(number(), pos_integer()) :: [number()]
  def times(finish, fps \\ @fps)

  def times(finish, fps) when is_number(finish) and finish > 0 do
    step = 1000 / fps

    step
    |> Stream.iterate(&(&1 + step))
    |> Stream.map(&round/1)
    |> Enum.take_while(&(&1 < finish))
    |> Kernel.++([finish])
  end

  def times(_finish, _fps), do: []

  @doc """
  Return the time that a GIF shows a frame after a key, in milliseconds

  The last key of an example gets a longer time, so a reader sees the result
  before the GIF starts again.
  """
  @spec hold(boolean()) :: pos_integer()
  def hold(true), do: 1600
  def hold(false), do: 900
end
