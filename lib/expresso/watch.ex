defmodule Expresso.Watch do
  @moduledoc """
  Serves a deck, and renders it again after each change

      $ mix expresso deck.exs [deck.html] --watch [--port 4100]

  Open `http://127.0.0.1:4100/` in a browser. After each change to the deck
  file, or to an image, a diagram or a style sheet of the deck, the watch mode
  renders the deck again. The page then reloads, and it shows the same step.
  With an output path, the watch mode also writes the document to that file.

  When a render fails, the watch mode writes the error to the standard error.
  The page then keeps the last good document, and the output file does not
  change. Stop the watch mode with Ctrl-C.

  Three modules do the work:

    * `Expresso.DeckFile` records the files that each render reads.
    * `Expresso.Watch.Files` finds a change to one of those files.
    * `Expresso.Watch.Server` serves the page, and makes it reload.

  The section "The watch mode" of `docs/architecture.md` gives the design, and
  the parts that a later version can replace.
  """

  alias Expresso.DeckFile
  alias Expresso.Watch.{Files, Server}

  # The time between two snapshots of the files, in milliseconds.
  @interval 500

  @doc """
  Run the watch mode for a deck file

  The function returns only for an error that stops the watch mode, such as a
  port in use. It writes the error message to the standard error, and it
  returns `{:error, message}`.

  The options are:

    * `:port` - the port of the server. This option is required. The port 0
      gives a free port.
    * `:interval` - the time between two snapshots of the files, in
      milliseconds. The default is 500.
    * `:device` and `:error_device` - the devices for the messages and for the
      errors. The defaults are `:stdio` and `:stderr`.
    * `:notify` - a process that gets `{Expresso.Watch, event}` for each event:
      `{:serving, url}`, `{:rendered, version}` or `{:failed, message}`. The
      tests wait for these messages.
  """
  @spec run(Path.t(), Path.t() | nil, keyword()) :: {:error, String.t()}
  def run(input_path, output_path, options) do
    case Server.start(Keyword.fetch!(options, :port)) do
      {:ok, server} ->
        url = Server.url(server)
        IO.puts(device(options), "Serving #{input_path} at #{url}")
        IO.puts(device(options), "Stop with Ctrl-C.")
        notify(options, {:serving, url})

        %{
          input: input_path,
          output: output_path,
          server: server,
          options: options,
          paths: [input_path],
          snapshot: %{}
        }
        |> render()
        |> loop()

      {:error, message} ->
        IO.puts(error_device(options), message)
        {:error, message}
    end
  end

  defp loop(state) do
    Process.sleep(Keyword.get(state.options, :interval, @interval))
    snapshot = Files.snapshot(watched_paths(state.paths))

    if Files.changed?(state.snapshot, snapshot),
      do: state |> render() |> loop(),
      else: loop(%{state | snapshot: snapshot})
  end

  # The snapshot of the known files comes before the render. A change during
  # the render then gives a different snapshot at the next look, and a new
  # render. A file that the render reads for the first time gets its state
  # after the render.
  defp render(state) do
    known = Files.snapshot(watched_paths(state.paths))
    started = System.monotonic_time(:millisecond)
    {result, read_paths} = DeckFile.track(fn -> render_file(state.input) end)
    milliseconds = System.monotonic_time(:millisecond) - started

    state =
      case result do
        {:ok, html} -> rendered(state, html, milliseconds, read_paths)
        {:error, message} -> failed(state, message, read_paths)
      end

    new_paths = state.paths |> watched_paths() |> Enum.reject(&Map.has_key?(known, &1))
    %{state | snapshot: Map.merge(Files.snapshot(new_paths), known)}
  end

  defp rendered(state, html, milliseconds, read_paths) do
    server = Server.publish(state.server, html)
    written = write(html, state.output, state.options)

    IO.puts(
      device(state.options),
      "#{clock()} Rendered #{state.input} in #{milliseconds} ms#{written}"
    )

    notify(state.options, {:rendered, server.version})
    %{state | server: server, paths: Enum.uniq([state.input | read_paths])}
  end

  # A render that fails can stop before it reads each file of the deck, so the
  # watch mode keeps the paths of the renders before it.
  defp failed(state, message, read_paths) do
    IO.puts(error_device(state.options), "#{clock()} Couldn't render #{state.input}:")
    IO.puts(error_device(state.options), message)
    notify(state.options, {:failed, message})
    %{state | paths: Enum.uniq(state.paths ++ read_paths)}
  end

  # Each render evaluates the deck file again, so a deck module gets a new
  # definition each time. The compiler option stops the warning about that
  # definition. The option is global, so it holds only during the render.
  defp render_file(input_path) do
    previous = Code.get_compiler_option(:ignore_module_conflict)
    Code.put_compiler_option(:ignore_module_conflict, true)

    try do
      Expresso.render_file(input_path)
    after
      Code.put_compiler_option(:ignore_module_conflict, previous)
    end
  end

  defp write(_html, nil, _options), do: ""

  defp write(html, output_path, options) do
    case write_to_file(html, output_path) do
      :ok ->
        ", and wrote #{output_path}"

      {:error, reason} ->
        IO.puts(
          error_device(options),
          "Couldn't write output file: #{:file.format_error(reason)}"
        )

        ""
    end
  end

  # The person who runs the command gives the output path.
  # sobelow_skip ["Traversal.FileModule"]
  defp write_to_file(html, output_path), do: File.write(output_path, html)

  # `Expresso.load_templates/0` compiles the custom templates in each render,
  # so a new template or a change to a template also starts a render.
  defp watched_paths(paths),
    do: Enum.uniq(paths ++ Path.wildcard("./priv/templates/{decks,slides}/*.exs"))

  defp clock do
    {_date, {hour, minute, second}} = :calendar.local_time()
    :io_lib.format("~2..0B:~2..0B:~2..0B", [hour, minute, second]) |> IO.iodata_to_binary()
  end

  defp device(options), do: Keyword.get(options, :device, :stdio)
  defp error_device(options), do: Keyword.get(options, :error_device, :stderr)

  defp notify(options, event) do
    case Keyword.get(options, :notify) do
      nil -> :ok
      pid -> send(pid, {__MODULE__, event})
    end
  end
end
