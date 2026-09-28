defmodule Expresso.Watch do
  @moduledoc """
  The watch mode of `mix expresso` and of the binary

      $ mix expresso deck.exs [deck.html] --watch [--port 4100]

  The watch mode renders the deck, and it serves the document at
  `http://127.0.0.1:4100/`. It then renders the deck again after each change
  to a file of the deck. The page in the browser reloads after each render
  that succeeds, and it shows the same step. With an output path, the watch
  mode also writes the document to that file after each render that succeeds.

  The files of the deck are the deck file, each image, diagram and style sheet
  that the last render read, and the custom templates of `priv/templates`.
  `Expresso.Watch.Files` finds their changes, and `Expresso.Watch.Server`
  serves the page and makes it reload.

  A render that fails writes its message to the standard error. The page then
  keeps the last document that succeeded, and the output file stays as it is.
  Each render evaluates the deck file again, and the compiler does not warn
  about a module of the deck that the render defines again.

  The watch mode runs until a person stops the command, for example with
  Ctrl-C.
  """

  alias Expresso.Watch.{Files, Server}

  # The time between two snapshots of the files, in milliseconds.
  @interval 500

  @doc """
  Run the watch mode for a deck file

  The function returns only for an error that stops the watch mode, such as a
  port in use. It writes the message of that error to the standard error.

  The options are:

    * `:port` - the port of the server, required. The port 0 gives a free
      port.
    * `:notify` - a process that gets `{Expresso.Watch, event}` for each event.
      The event is `{:serving, url}`, `{:rendered, version}` or
      `{:failed, message}`. The tests use it.
    * `:interval` - the time between two snapshots, in milliseconds. The
      default is 500.
    * `:device` and `:error_device` - the devices of the messages and of the
      errors. The defaults are `:stdio` and `:stderr`.
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
          files: [input_path],
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
    snapshot = Files.snapshot(watched(state.files))

    if Files.changed?(state.snapshot, snapshot),
      do: state |> render() |> loop(),
      else: loop(%{state | snapshot: snapshot})
  end

  # A render that fails keeps the files of the renders before it, because the
  # render stops before it reads each file of the deck.
  #
  # The snapshot of the known files comes before the render. A change during
  # the render then gives a different snapshot at the next look, and a new
  # render. A file that the render reads for the first time gets its state
  # after the render.
  defp render(state) do
    before = Files.snapshot(watched(state.files))
    started = System.monotonic_time(:millisecond)
    {result, read} = Files.tracking(fn -> evaluate(state.input) end)
    milliseconds = System.monotonic_time(:millisecond) - started

    state =
      case result do
        {:ok, html} ->
          published(state, html, milliseconds, read)

        {:error, message} ->
          IO.puts(error_device(state.options), "#{clock()} Couldn't render #{state.input}:")
          IO.puts(error_device(state.options), message)
          notify(state.options, {:failed, message})
          %{state | files: Enum.uniq(state.files ++ read)}
      end

    new = state.files |> watched() |> Enum.reject(&Map.has_key?(before, &1))
    %{state | snapshot: Map.merge(Files.snapshot(new), before)}
  end

  defp published(state, html, milliseconds, read) do
    server = Server.publish(state.server, html)
    written = write(html, state.output, state.options)

    IO.puts(
      device(state.options),
      "#{clock()} Rendered #{state.input} in #{milliseconds} ms#{written}"
    )

    notify(state.options, {:rendered, server.version})
    %{state | server: server, files: Enum.uniq([state.input | read])}
  end

  # Each render evaluates the deck file again, and a deck module then gets a
  # new definition. The option stops the warning of the compiler for it. The
  # option is global, so it holds only for the render.
  defp evaluate(input_path) do
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

  # `Expresso.load_templates/0` compiles these templates in each render, so a
  # new template or a change to a template gives a new render too.
  defp watched(files),
    do: Enum.uniq(files ++ Path.wildcard("./priv/templates/{decks,slides}/*.exs"))

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
