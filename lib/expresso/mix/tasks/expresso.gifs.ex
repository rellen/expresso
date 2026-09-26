defmodule Mix.Tasks.Expresso.Gifs do
  @moduledoc """
  Record a GIF of each example deck of `examples/animations/`

      mix expresso.gifs [output] [name ...]

  The task renders each example deck to an HTML file with `Expresso.main/2`.
  It then runs the recorder `assets/gifs/record.ts` with Node, and the
  recorder writes one GIF for each example into the output directory. The
  default output directory is `_build/gifs`. A list of names records only
  those examples.

  The recorder needs `npm install` and Chromium. The environment variable
  `EXPRESSO_CHROMIUM` gives the path of a Chromium executable, as it does for
  the browser tests. `docs/development.md` gives the details.
  """

  use Mix.Task

  @shortdoc "Record a GIF of each example deck"

  # Each example has a name, a deck file and the keys that the recorder
  # presses. The GIF of an example is `<name>.gif`. The guides of `docs/`
  # show the code of each deck and its GIF.
  @examples [
    %{name: "transition-fade", deck: "transition_fade.exs", keys: ["j", "k"]},
    %{name: "transition-slide", deck: "transition_slide.exs", keys: ["j", "k"]},
    %{name: "transition-zoom", deck: "transition_zoom.exs", keys: ["j", "k"]},
    %{name: "transition-none", deck: "transition_none.exs", keys: ["j", "k"]},
    %{name: "transition-override", deck: "transition_override.exs", keys: ["j", "j"]},
    %{name: "overlay-at", deck: "overlay_at.exs", keys: ["j", "j"]},
    %{name: "overlay-alert", deck: "overlay_alert.exs", keys: ["j", "j"]},
    %{name: "overlay-move", deck: "overlay_move.exs", keys: ["j"]},
    %{name: "overlay-list", deck: "overlay_list.exs", keys: ["j", "j"]},
    %{name: "overlay-code", deck: "overlay_code.exs", keys: ["j"]}
  ]

  @directory "examples/animations"

  @doc """
  Give each example: its name, the path of its deck file and its keys
  """
  @spec examples() :: [%{name: String.t(), deck: Path.t(), keys: [String.t()]}]
  def examples do
    Enum.map(@examples, &%{&1 | deck: Path.join(@directory, &1.deck)})
  end

  @doc false
  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")
    {output, names} = parse(args)
    work = Path.join(System.tmp_dir!(), "expresso-gifs-#{System.unique_integer([:positive])}")
    File.mkdir_p!(work)

    manifest =
      for example <- selected(names) do
        html = Path.join(work, example.name <> ".html")
        :ok = Expresso.main(example.deck, html)
        %{name: example.name, html: html, actions: example.keys}
      end

    path = Path.join(work, "manifest.json")
    write(path, JSON.encode!(manifest))
    record(path, output)
  end

  defp parse([]), do: {"_build/gifs", []}
  defp parse([output | names]), do: {output, names}

  defp selected([]), do: examples()

  defp selected(names) do
    case Enum.reject(names, fn name -> Enum.any?(examples(), &(&1.name == name)) end) do
      [] -> Enum.filter(examples(), &(&1.name in names))
      unknown -> Mix.raise("unknown example: #{Enum.join(unknown, ", ")}")
    end
  end

  # The path is a file in the temporary directory of this task.
  # sobelow_skip ["Traversal.FileModule"]
  defp write(path, contents), do: File.write!(path, contents)

  # The command and its first argument are fixed. The other arguments are the
  # manifest of this task and the output directory of the person who runs it.
  # sobelow_skip ["CI.System"]
  defp record(manifest, output) do
    case System.cmd("node", ["assets/gifs/record.ts", manifest, output],
           into: IO.stream(),
           stderr_to_stdout: true
         ) do
      {_output, 0} -> :ok
      {_output, status} -> Mix.raise("the recorder stopped with the status #{status}")
    end
  end
end
