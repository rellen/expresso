defmodule GifEncoder.Vix do
  @moduledoc """
  Encodes a GIF with libvips through Vix

  libvips writes a GIF with cgif, and it makes the palettes with
  libimagequant. The encoder joins the frames into one tall image, and it
  sets the height of a page, the delay of each page and the loop count. The
  options are those of `Vix.Vips.Operation.gifsave_buffer/2`. The defaults
  give each frame its own palette and no dithering.
  """

  @behaviour GifEncoder

  alias Vix.Vips.{Image, MutableImage, Operation}

  @defaults [effort: 7, dither: 0.0, bitdepth: 8, reuse: false]

  @impl GifEncoder
  def encode([first | _rest] = frames, opts) do
    with {:ok, images} <- load(frames),
         {:ok, joined} <- Operation.arrayjoin(images, across: 1),
         {:ok, gif} <- metadata(joined, Image.height(hd(images)), Enum.map(frames, & &1.delay)) do
      _ = first
      Operation.gifsave_buffer(gif, Keyword.merge(@defaults, opts))
    end
  end

  defp load(frames) do
    Enum.reduce_while(frames, {:ok, []}, fn frame, {:ok, images} ->
      case Image.new_from_buffer(frame.png) do
        {:ok, image} -> {:cont, {:ok, [image | images]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, images} -> {:ok, Enum.reverse(images)}
      error -> error
    end
  end

  defp metadata(image, page_height, delays) do
    Image.mutate(image, fn mutable ->
      :ok = MutableImage.set(mutable, "page-height", :gint, page_height)
      :ok = MutableImage.set(mutable, "delay", :VipsArrayInt, delays)
      :ok = MutableImage.set(mutable, "loop", :gint, 0)
    end)
  end
end
