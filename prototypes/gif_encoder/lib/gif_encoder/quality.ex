defmodule GifEncoder.Quality do
  @moduledoc """
  Measures how close a GIF is to its source frames

  libvips decodes the GIF, so the measure does not depend on an encoder of
  this project. An encoder can merge two frames that are the same, as cgif
  does, so the measure compares each source frame with the page that the GIF
  shows at the start time of the frame. The result is the peak signal-to-noise
  ratio (PSNR) in decibels, for each frame. A larger value is better, and
  identical images give 99.
  """

  alias Vix.Vips.{Image, Operation}

  @doc "Return the PSNR of each source frame, and the total time of the GIF"
  @spec psnr([GifEncoder.frame()], binary()) ::
          {:ok, %{psnr: [float()], duration: non_neg_integer()}}
  def psnr(frames, gif) do
    {:ok, decoded} = Image.new_from_buffer(gif, n: -1)
    width = Image.width(decoded)
    page_height = page_height(decoded)
    {:ok, delays} = Image.header_value(decoded, "delay")
    starts = delays |> Enum.scan(&+/2) |> then(&[0 | Enum.drop(&1, -1)])

    {psnr, _time} =
      Enum.map_reduce(frames, 0, fn frame, time ->
        page = Enum.count(starts, &(&1 <= time)) - 1
        {:ok, shown} = Operation.extract_area(decoded, 0, page * page_height, width, page_height)
        {:ok, source} = Image.new_from_buffer(frame.png)
        {db(rgb(shown), rgb(source)), time + frame.delay}
      end)

    {:ok, %{psnr: psnr, duration: Enum.sum(delays)}}
  end

  defp page_height(image) do
    case Image.header_value(image, "page-height") do
      {:ok, height} -> height
      _none -> Image.height(image)
    end
  end

  defp rgb(image) do
    {:ok, rgb} = Operation.extract_band(image, 0, n: 3)
    {:ok, rgb} = Operation.cast(rgb, :VIPS_FORMAT_INT)
    rgb
  end

  defp db(a, b) do
    {:ok, difference} = Operation.subtract(a, b)
    {:ok, square} = Operation.multiply(difference, difference)
    {:ok, mse} = Operation.avg(square)
    if mse == 0, do: 99.0, else: min(99.0, 10 * :math.log10(255 * 255 / mse))
  end
end
