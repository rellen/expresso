defmodule Mix.Tasks.Expresso.Gifs do
  @moduledoc """
  Record a GIF or a PNG of each example deck of `examples/`

      mix expresso.gifs [output] [name ...]

  The task renders each example deck to an HTML file with `Expresso.main/2`.
  `Expresso.Recorder` then opens each HTML file in Chromium, does the actions
  of the example, and returns the frames. The task writes one GIF for each
  example into the output directory, with `Expresso.Gif`, or one PNG for a
  still. The default output directory is `_build/gifs`. A list of names
  records only those examples.

  The decks of `examples/animations/` give the GIFs of the guides of `docs/`.
  The decks of `examples/presenter/` give the GIFs and the stills of
  `README.md`.

  The task is in `tools/`, so it is available in dev and in test only. The
  recorder needs the Playwright driver of `npm install` and Chromium. The
  environment variable `EXPRESSO_CHROMIUM` gives the path of a Chromium
  executable, as it does for the browser tests. `Expresso.Gif` needs Zig to
  compile. `docs/development.md` gives the details.
  """

  use Mix.Task

  alias Expresso.{Gif, Recorder}

  @shortdoc "Record a GIF or a PNG of each example deck"

  @typedoc """
  An example: its name, the path of its deck file, the address after the path
  of the HTML file, its actions, whether it is a still, and the page that
  shows it

  An action is a key, or `{:advance, milliseconds}`, which moves the clock of
  the page. The speaker view then shows a later time. A still gives one PNG
  after the actions, and each other example gives a GIF of each action. The
  height is the height of the picture, in the layout of a window of 1280 by
  720 pixels. A still of the handout view can then show several pages.
  """
  @type example :: %{
          name: String.t(),
          deck: Path.t(),
          address: String.t(),
          actions: [String.t() | {:advance, pos_integer()}],
          still: boolean(),
          height: pos_integer(),
          page: :guides | :readme
        }

  # The examples of the guides. Each guide shows the code of its decks and the
  # GIF of each one, so an example here has only keys.
  @guides [
    %{name: "transition-fade", deck: "transition_fade.exs", actions: ["j", "k"]},
    %{name: "transition-slide", deck: "transition_slide.exs", actions: ["j", "k"]},
    %{name: "transition-zoom", deck: "transition_zoom.exs", actions: ["j", "k"]},
    %{name: "transition-none", deck: "transition_none.exs", actions: ["j", "k"]},
    %{name: "transition-override", deck: "transition_override.exs", actions: ["j", "j"]},
    %{name: "overlay-at", deck: "overlay_at.exs", actions: ["j", "j"]},
    %{name: "overlay-alert", deck: "overlay_alert.exs", actions: ["j", "j"]},
    %{name: "overlay-move", deck: "overlay_move.exs", actions: ["j"]},
    %{name: "overlay-list", deck: "overlay_list.exs", actions: ["j", "j"]},
    %{name: "overlay-code", deck: "overlay_code.exs", actions: ["j"]},
    %{name: "overlay-scale", deck: "overlay_scale.exs", actions: ["j", "j"]},
    %{name: "overlay-color", deck: "overlay_color.exs", actions: ["j", "j"]},
    %{name: "overlay-dim", deck: "overlay_dim.exs", actions: ["j", "j"]},
    %{name: "overlay-dim-code", deck: "overlay_dim_code.exs", actions: ["j", "j"]},
    %{name: "overlay-row", deck: "overlay_row.exs", actions: ["j", "j"]},
    %{name: "overlay-diagram", deck: "overlay_diagram.exs", actions: ["j", "j"]},
    %{name: "overlay-effects", deck: "overlay_effects.exs", actions: ["j", "j", "j", "j", "j"]},
    %{name: "overlay-effect-list", deck: "overlay_effect_list.exs", actions: ["j", "j", "k"]},
    %{name: "overlay-speed", deck: "overlay_speed.exs", actions: ["j"]},
    %{name: "overlay-easing", deck: "overlay_easing.exs", actions: ["j"]},
    %{name: "overlay-custom", deck: "overlay_custom.exs", actions: ["j", "j", "j"]}
  ]

  # The examples of "Present a deck" in README.md. The tour deck has ten
  # steps and a talk of ten minutes, so the pace of the speaker view changes
  # at the times below: it is behind from three minutes, and over from ten.
  @readme [
    %{name: "present-keys", deck: "tour.exs", actions: ["j", "j", "j", "k", "b", "b", "End"]},
    %{
      name: "present-overview",
      deck: "tour.exs",
      address: "#2",
      actions: ["o", "j", "j", "Enter"]
    },
    %{
      name: "present-speaker",
      deck: "tour.exs",
      address: "?speaker&duration=10#2.1",
      still: true
    },
    %{
      name: "present-pace",
      deck: "tour.exs",
      address: "?speaker&duration=10#2.1",
      actions: ["j", {:advance, 90_000}, {:advance, 150_000}, {:advance, 420_000}]
    },
    %{name: "present-progress", deck: "short.exs", actions: ["j", "j", "j"]},
    %{name: "present-slide-numbers", deck: "tour.exs", address: "#3", still: true},
    %{name: "present-handout", deck: "tour.exs", actions: ["p"], still: true, height: 2160}
  ]

  @defaults %{address: "", actions: [], still: false, height: 720}

  @doc """
  Return each example, with the path of its deck file
  """
  @spec examples() :: [example()]
  def examples do
    Enum.map(@guides, &example(&1, :guides, "examples/animations")) ++
      Enum.map(@readme, &example(&1, :readme, "examples/presenter"))
  end

  @doc """
  Return the name of the file of an example in the output directory
  """
  @spec file(example()) :: String.t()
  def file(%{name: name, still: true}), do: name <> ".png"
  def file(%{name: name}), do: name <> ".gif"

  defp example(example, page, directory) do
    @defaults
    |> Map.merge(example)
    |> Map.put(:page, page)
    |> Map.update!(:deck, &Path.join(directory, &1))
  end

  @doc false
  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")
    {:ok, _apps} = Application.ensure_all_started(:playwright_ex)
    {output, names} = parse(args)
    work = Path.join(System.tmp_dir!(), "expresso-gifs-#{System.unique_integer([:positive])}")
    File.mkdir_p!(work)
    File.mkdir_p!(output)

    examples = selected(names)

    # Several examples can share one deck, and the deck renders one time.
    rendered =
      Map.new(Enum.uniq(Enum.map(examples, & &1.deck)), fn deck ->
        html = Path.join(work, Path.basename(deck, ".exs") <> ".html")
        :ok = Expresso.main(deck, html)
        {deck, html}
      end)

    recorder = Recorder.start()

    try do
      Enum.each(examples, fn example ->
        url = "file://" <> Path.expand(Map.fetch!(rendered, example.deck)) <> example.address
        frames = Recorder.record(recorder, url, example.actions, example.height)
        path = Path.join(output, file(example))
        write(path, contents(example, frames))
        Mix.shell().info("#{path}: #{describe(example, frames)}")
      end)
    after
      Recorder.stop(recorder)
    end
  end

  # A still is the last frame, which shows the page after each action.
  defp contents(%{still: true}, frames), do: List.last(frames).png

  defp contents(example, frames) do
    case Gif.encode(frames) do
      {:ok, gif} -> gif
      {:error, message} -> Mix.raise("#{example.name}: #{message}")
    end
  end

  defp describe(%{still: true}, _frames), do: "a still"
  defp describe(_example, frames), do: "#{length(frames)} frames"

  defp parse([]), do: {"_build/gifs", []}
  defp parse([output | names]), do: {output, names}

  defp selected([]), do: examples()

  defp selected(names) do
    case Enum.reject(names, fn name -> Enum.any?(examples(), &(&1.name == name)) end) do
      [] -> Enum.filter(examples(), &(&1.name in names))
      unknown -> Mix.raise("unknown example: #{Enum.join(unknown, ", ")}")
    end
  end

  # The path is a file in the output directory that the user gives.
  # sobelow_skip ["Traversal.FileModule"]
  defp write(path, contents), do: File.write!(path, contents)
end
