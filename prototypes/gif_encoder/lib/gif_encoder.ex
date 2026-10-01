defmodule GifEncoder do
  @moduledoc """
  Encodes the frames of an animation as one GIF, with a choice of encoder

  A frame is a PNG image from Chromium and the time that the GIF shows it, in
  milliseconds. Each encoder implements this behaviour, so the recorder of
  Expresso can use any of them:

  | Module | Method |
  | --- | --- |
  | `GifEncoder.Elixir` | Pure Elixir: median cut, then LZW. |
  | `GifEncoder.Zig` | The same algorithm as `GifEncoder.Elixir`, in a Zig NIF (Zigler). |
  | `GifEncoder.Rust` | A Rust NIF (Rustler) with the `png`, `color_quant` and `weezl` crates. |
  | `GifEncoder.Vix` | libvips through Vix: cgif and libimagequant. |
  | `GifEncoder.Ffmpeg` | The `ffmpeg` command: `palettegen` and `paletteuse`. |
  | `GifEncoder.Gifski` | The `gifski` command: libimagequant. |

  The first three encode one frame at a time with `GifEncoder.PerFrame`, and
  `GifEncoder.Container` writes the GIF around the frames. The other three
  write the whole GIF.

  Each GIF repeats with no end, and each frame has its own palette.
  """

  @typedoc "A PNG image and the time that the GIF shows it, in milliseconds"
  @type frame :: %{png: binary(), delay: non_neg_integer()}

  @doc "Encode the frames as one GIF"
  @callback encode([frame()], keyword()) :: {:ok, binary()} | {:error, term()}

  @doc """
  Encode the frames with an encoder

  The option `:encoder` gives the module. The default is `GifEncoder.Elixir`.
  The other options go to the encoder.
  """
  @spec encode([frame()], keyword()) :: {:ok, binary()} | {:error, term()}
  def encode(frames, opts \\ []) do
    {encoder, opts} = Keyword.pop(opts, :encoder, GifEncoder.Elixir)
    encoder.encode(frames, opts)
  end

  @doc "The encoders of this project"
  @spec encoders() :: [module()]
  def encoders,
    do: [
      GifEncoder.Elixir,
      GifEncoder.Zig,
      GifEncoder.Rust,
      GifEncoder.Vix,
      GifEncoder.Ffmpeg,
      GifEncoder.Gifski
    ]
end
