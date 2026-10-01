defmodule Expresso.Gif do
  @moduledoc """
  Encodes the frames of a recording as one GIF that repeats with no end

  A frame is a PNG image of 8-bit RGB, the format of a screenshot of Chromium,
  and the time that the GIF shows it, in milliseconds. `encode/1` does these
  steps:

  1. `Expresso.Gif.Png` inflates each PNG image, and the NIF
     `Expresso.Gif.Nif` removes the PNG filters. The frames run in parallel.
  2. A frame that is the same as the frame before it adds its delay to that
     frame, and it makes no frame of its own.
  3. The NIF encodes each frame in parallel. The first frame holds each pixel.
     Each later frame holds only the rectangle of the pixels that change, and
     a pixel in it that does not change is transparent. Each frame has its own
     palette, which median cut makes from its exact colors.
  4. `Expresso.Gif.Container` writes the GIF around the frames.

  `prototypes/gif_encoder` compares this encoder with others, and its README
  gives the reasons for this design.
  """

  alias Expresso.Gif.{Container, Nif, Png}

  @typedoc "A PNG image and the time that the GIF shows it, in milliseconds"
  @type frame :: %{png: binary(), delay: non_neg_integer()}

  @doc "Encode the frames as one GIF"
  @spec encode([frame(), ...]) :: {:ok, binary()} | {:error, String.t()}
  def encode(frames) do
    with {:ok, decoded} <- decode(frames),
         {:ok, {width, height}} <- same_size(decoded) do
      merged = merge(decoded)
      previous = [nil | Enum.map(Enum.drop(merged, -1), & &1.rgb)]

      images =
        merged
        |> Enum.zip(previous)
        |> parallel(fn {frame, previous} ->
          image = Nif.encode_frame(frame.rgb, previous || <<>>, width, height)
          Map.put(image, :delay, frame.delay)
        end)

      {:ok, Container.gif(width, height, images)}
    end
  end

  defp decode(frames) do
    frames
    |> parallel(fn frame ->
      with {:ok, {width, height, rows}} <- Png.inflate(frame.png) do
        {:ok,
         %{
           width: width,
           height: height,
           rgb: Nif.unfilter(rows, width, height),
           delay: frame.delay
         }}
      end
    end)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, frame}, {:ok, acc} -> {:cont, {:ok, [frame | acc]}}
      error, _acc -> {:halt, error}
    end)
    |> case do
      {:ok, decoded} -> {:ok, Enum.reverse(decoded)}
      error -> error
    end
  end

  defp same_size([first | rest]) do
    if Enum.all?(rest, &(&1.width == first.width and &1.height == first.height)),
      do: {:ok, {first.width, first.height}},
      else: {:error, "the frames have different sizes"}
  end

  defp merge(frames) do
    frames
    |> Enum.chunk_while(
      nil,
      fn
        frame, nil ->
          {:cont, frame}

        %{rgb: rgb} = frame, %{rgb: rgb} = last ->
          {:cont, %{last | delay: last.delay + frame.delay}}

        frame, last ->
          {:cont, last, frame}
      end,
      fn last -> {:cont, last, nil} end
    )
  end

  # The NIFs run on dirty CPU schedulers, so one task for each scheduler
  # keeps each core busy.
  defp parallel(enumerable, fun) do
    enumerable
    |> Task.async_stream(fun, timeout: :infinity, max_concurrency: System.schedulers_online())
    |> Enum.map(fn {:ok, result} -> result end)
  end
end
