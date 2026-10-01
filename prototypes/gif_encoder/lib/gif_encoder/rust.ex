defmodule GifEncoder.Rust do
  @moduledoc """
  Encodes a GIF with a Rust NIF

  The NIF decodes the PNG image with the `png` crate, makes a palette of 256
  colors with NeuQuant of the `color_quant` crate, and compresses the indices
  with `weezl`. The `gif` crate uses the same crates. The NIF runs on a dirty
  CPU scheduler. The option `:sample` gives the sample factor of NeuQuant,
  from 1 (the best and the slowest) to 30. The default is 10.
  """

  use GifEncoder.PerFrame

  defmodule Nif do
    @moduledoc false
    use Rustler, otp_app: :gif_encoder, crate: "gif_encoder_rust"

    def encode_frame(_png, _sample), do: :erlang.nif_error(:nif_not_loaded)
  end

  @impl GifEncoder.PerFrame
  def encode_frame(png, opts) do
    case Nif.encode_frame(png, Keyword.get(opts, :sample, 10)) do
      {:ok, {width, height, palette, code_size, lzw}} ->
        {:ok, %{width: width, height: height, palette: palette, code_size: code_size, lzw: lzw}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
