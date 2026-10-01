defmodule GifEncoder.Frames do
  @moduledoc """
  Reads the frames of an animation from a directory

  The directory holds `000.png`, `001.png` and the next files, and
  `delays.json`, a JSON list of the delay of each frame in milliseconds.
  """

  @doc "Return the frames of a directory, in order"
  @spec read(Path.t()) :: [GifEncoder.frame()]
  def read(directory) do
    directory
    |> Path.join("delays.json")
    |> File.read!()
    |> JSON.decode!()
    |> Enum.with_index()
    |> Enum.map(fn {delay, index} ->
      name = index |> Integer.to_string() |> String.pad_leading(3, "0")
      %{png: File.read!(Path.join(directory, name <> ".png")), delay: delay}
    end)
  end
end
