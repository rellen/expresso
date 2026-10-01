defmodule GifEncoder.PerFrame do
  @moduledoc """
  Makes `encode/2` for an encoder that encodes one frame at a time

  The module that calls `use GifEncoder.PerFrame` defines `encode_frame/2`. It
  takes a PNG image and the options, and it returns the size, the palette, the
  minimum code size and the LZW data of the frame. `encode/2` encodes the
  frames in parallel, one task for each frame, then `GifEncoder.Container`
  writes the GIF. The option `:max_concurrency` gives the number of tasks at
  the same time. The default is the number of schedulers.
  """

  @doc "Encode one PNG frame"
  @callback encode_frame(binary(), keyword()) ::
              {:ok, Map.t()} | {:error, term()}

  defmacro __using__(_opts) do
    quote do
      @behaviour GifEncoder
      @behaviour GifEncoder.PerFrame

      @impl GifEncoder
      def encode(frames, opts \\ []),
        do: GifEncoder.PerFrame.encode(__MODULE__, frames, opts)
    end
  end

  @doc false
  def encode(module, frames, opts) do
    concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())

    frames
    |> Task.async_stream(
      fn frame ->
        with {:ok, image} <- module.encode_frame(frame.png, opts),
             do: {:ok, Map.put(image, :delay, frame.delay)}
      end,
      max_concurrency: concurrency,
      timeout: :infinity,
      ordered: true
    )
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, {:ok, image}}, {:ok, images} -> {:cont, {:ok, [image | images]}}
      {:ok, {:error, reason}}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, images} -> {:ok, GifEncoder.Container.gif(Enum.reverse(images))}
      error -> error
    end
  end
end
