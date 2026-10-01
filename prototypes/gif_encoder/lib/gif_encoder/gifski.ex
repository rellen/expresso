defmodule GifEncoder.Gifski do
  @moduledoc """
  Encodes a GIF with the `gifski` command

  gifski makes the palettes with libimagequant. Its command takes a constant
  frame rate, so the encoder writes each frame to a temporary directory as
  many times as its delay needs, at the frame rate of the option `:fps`. The
  default is 50, a step of 20 milliseconds. gifski then merges the identical
  frames into one frame with a longer delay. The options:

    * `:command` - the path of the command. The default is the environment
      variable `GIFSKI`, or `gifski`.
    * `:fps` - the frame rate. A delay rounds to a whole number of frames.
    * `:quality` - the quality of gifski, from 1 to 100. The default is 90.

  The license of gifski is AGPL 3.0, so Expresso can run the command, but a
  NIF must not link the library.
  """

  @behaviour GifEncoder

  @impl GifEncoder
  def encode(frames, opts) do
    directory = Path.join(System.tmp_dir!(), "gif_encoder_#{System.unique_integer([:positive])}")
    File.mkdir_p!(directory)
    fps = Keyword.get(opts, :fps, 50)

    try do
      files =
        frames
        |> Enum.with_index()
        |> Enum.flat_map(fn {frame, index} ->
          source = Path.join(directory, "frame#{index}.png")
          File.write!(source, frame.png)
          List.duplicate(source, max(1, round(frame.delay * fps / 1000)))
        end)
        |> Enum.with_index()
        |> Enum.map(fn {source, index} ->
          path = Path.join(directory, String.pad_leading("#{index}", 6, "0") <> ".png")
          :ok = File.ln(source, path)
          path
        end)

      output = Path.join(directory, "out.gif")

      args =
        ["--quiet", "--fps", "#{fps}", "--quality", "#{Keyword.get(opts, :quality, 90)}"] ++
          ["--output", output | files]

      command = Keyword.get(opts, :command, System.get_env("GIFSKI", "gifski"))

      case System.cmd(command, args, stderr_to_stdout: true) do
        {_output, 0} -> {:ok, File.read!(output)}
        {output, status} -> {:error, "gifski stopped with the status #{status}: #{output}"}
      end
    after
      File.rm_rf!(directory)
    end
  end
end
