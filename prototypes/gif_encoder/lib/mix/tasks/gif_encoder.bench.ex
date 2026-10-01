defmodule Mix.Tasks.GifEncoder.Bench do
  @shortdoc "Compare the encoders on a directory of animations"

  @moduledoc """
  Compares the encoders on the frames of each animation of a directory

      mix gif_encoder.bench <frames> [--gifenc <directory> --gifenc-ms <milliseconds>]

  Each subdirectory of `<frames>` holds one animation, in the form of
  `GifEncoder.Frames`. For each encoder, the task encodes each animation one
  time to warm up, then one time with each core and one time with one core.
  It prints the time, the size and the PSNR of `GifEncoder.Quality`, and it
  writes each GIF to `bench/<encoder>/`.

  `--gifenc` gives a directory of the GIFs of `scripts/gifenc.mjs`, and
  `--gifenc-ms` gives the time that the script printed. The task then adds a
  row for gifenc.
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, [frames_dir], _invalid} =
      OptionParser.parse(args, strict: [gifenc: :string, gifenc_ms: :integer])

    animations =
      for name <- frames_dir |> File.ls!() |> Enum.sort(),
          File.dir?(Path.join(frames_dir, name)),
          do: {name, GifEncoder.Frames.read(Path.join(frames_dir, name))}

    count = animations |> Enum.map(fn {_name, frames} -> length(frames) end) |> Enum.sum()

    IO.puts(
      "#{length(animations)} animations, #{count} frames, #{System.schedulers_online()} cores\n"
    )

    IO.puts("| Encoder | All cores | One core | Size | Mean PSNR | Min PSNR |")
    IO.puts("| --- | --- | --- | --- | --- | --- |")

    for encoder <- GifEncoder.encoders(), do: IO.puts(row(encoder, animations))
    if opts[:gifenc], do: IO.puts(baseline(opts[:gifenc], opts[:gifenc_ms], animations))
  end

  defp row(encoder, animations) do
    name = encoder |> Module.split() |> List.last()
    out = Path.join("bench", name)
    File.mkdir_p!(out)
    _warm = encode_all(encoder, animations, [])
    {all, gifs} = encode_all(encoder, animations, [])

    one =
      if function_exported?(encoder, :encode_frame, 2),
        do: encode_all(encoder, animations, max_concurrency: 1) |> elem(0) |> seconds(),
        else: "-"

    for {{animation, _frames}, gif} <- Enum.zip(animations, gifs),
        do: File.write!(Path.join(out, animation <> ".gif"), gif)

    cells(name, seconds(all), one, gifs, animations)
  end

  defp encode_all(encoder, animations, opts) do
    {time, gifs} =
      :timer.tc(fn ->
        for {_name, frames} <- animations do
          {:ok, gif} = GifEncoder.encode(frames, [encoder: encoder] ++ opts)
          gif
        end
      end)

    {time, gifs}
  end

  defp baseline(directory, milliseconds, animations) do
    gifs = for {name, _frames} <- animations, do: File.read!(Path.join(directory, name <> ".gif"))
    time = if milliseconds, do: seconds(milliseconds * 1000), else: "?"
    cells("gifenc (Node)", time, time, gifs, animations)
  end

  defp cells(name, all, one, gifs, animations) do
    psnr =
      for {{_name, frames}, gif} <- Enum.zip(animations, gifs) do
        {:ok, %{psnr: values}} = GifEncoder.Quality.psnr(frames, gif)
        values
      end
      |> List.flatten()

    size = gifs |> Enum.map(&byte_size/1) |> Enum.sum()
    mean = Enum.sum(psnr) / length(psnr)

    "| #{name} | #{all} | #{one} | #{Float.round(size / 1_000_000, 2)} MB | " <>
      "#{Float.round(mean, 1)} dB | #{Float.round(Enum.min(psnr), 1)} dB |"
  end

  defp seconds(microseconds), do: "#{Float.round(microseconds / 1_000_000, 2)} s"
end
