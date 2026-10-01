defmodule GifEncoder.Ffmpeg do
  @moduledoc """
  Encodes a GIF with the `ffmpeg` command

  The encoder writes the frames to a temporary directory, with a list for the
  concat demuxer that gives the delay of each frame. ffmpeg then makes a
  palette for each frame with `palettegen` and `paletteuse`, with no
  dithering, and with no color for transparency. The demuxer of each image
  and the encoder count time in hundredths of a second, the unit of a GIF
  delay, so ffmpeg does not round a delay to its default step of 40
  milliseconds. The options:

    * `:command` - the path of the command. The default is the environment
      variable `FFMPEG`, or `ffmpeg`.
    * `:dither` - the dither of `paletteuse`. The default is `none`.
  """

  @behaviour GifEncoder

  @impl GifEncoder
  def encode(frames, opts) do
    directory = Path.join(System.tmp_dir!(), "gif_encoder_#{System.unique_integer([:positive])}")
    File.mkdir_p!(directory)

    try do
      names =
        for {frame, index} <- Enum.with_index(frames) do
          name = String.pad_leading("#{index}", 3, "0") <> ".png"
          File.write!(Path.join(directory, name), frame.png)
          {name, frame.delay}
        end

      # The demuxer ignores the duration of the last file, so the option
      # `-final_delay` of the GIF muxer gives it, in hundredths of a second.
      list =
        ["ffconcat version 1.0\n"] ++
          for {name, delay} <- names do
            "file '#{name}'\noption framerate 100\nduration #{delay / 1000}\n"
          end

      File.write!(Path.join(directory, "list.txt"), list)
      output = Path.join(directory, "out.gif")
      dither = Keyword.get(opts, :dither, "none")

      filter =
        "split[a][b];[a]palettegen=stats_mode=single:max_colors=256:reserve_transparent=0[p];" <>
          "[b][p]paletteuse=new=1:dither=#{dither}"

      args =
        ~w(-v error -f concat -safe 0 -i) ++
          [Path.join(directory, "list.txt"), "-lavfi", filter] ++
          ["-final_delay", "#{div(List.last(frames).delay + 5, 10)}"] ++
          ~w(-fps_mode vfr -enc_time_base 1/100 -loop 0 -f gif) ++ [output]

      command = Keyword.get(opts, :command, System.get_env("FFMPEG", "ffmpeg"))

      case System.cmd(command, args, stderr_to_stdout: true) do
        {_output, 0} -> {:ok, File.read!(output)}
        {output, status} -> {:error, "ffmpeg stopped with the status #{status}: #{output}"}
      end
    after
      File.rm_rf!(directory)
    end
  end
end
