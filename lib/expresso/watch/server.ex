defmodule Expresso.Watch.Server do
  @moduledoc """
  Serves the page of the watch mode, and makes the page reload

  The server is `:httpd` from the `inets` application of OTP, so it needs no
  dependency. It listens on 127.0.0.1 only, so no other computer can read the
  deck. It serves a private directory in the temporary directory of the
  system, and that directory holds two files:

    * `index.html` - the last good document, with a small reload script at the
      end of the `body`.
    * `version` - the number of that render.

  The script asks for `version` two times each second. When the number is not
  the number of its own document, the script reloads the page. The address
  holds the slide and the step, so the page shows the same step after the
  reload. The speaker view opens the same address, so it reloads too.

  `publish/2` writes the new document, and then the new number. Each write
  goes to a temporary file, and a rename then replaces the old file. The
  server thus never sends a part of a file.

  This module owns the server and the script, so the two always change
  together. The file `version` and the script are internal: a later version
  can push the reload over a WebSocket, and the user sees no difference. The
  section "The watch mode" of `docs/architecture.md` gives the details.
  """

  @enforce_keys [:pid, :directory, :port]
  defstruct [:pid, :directory, :port, version: 0]

  @typedoc "A running server"
  @type t :: %__MODULE__{
          pid: pid(),
          directory: Path.t(),
          port: :inet.port_number(),
          version: non_neg_integer()
        }

  # The time between two requests of the script, in milliseconds.
  @interval 500

  @doc """
  Start the server on a port of 127.0.0.1

  The port 0 gives a free port, and `url/1` then returns the address with that
  port. Until the first call of `publish/2`, the page shows a short text.
  For a port in use, the function returns an error message that names
  `--port`.
  """
  @spec start(:inet.port_number()) :: {:ok, t()} | {:error, String.t()}
  def start(port) do
    {:ok, _started} = Application.ensure_all_started(:inets)
    directory = directory()
    server = %__MODULE__{pid: self(), directory: directory, port: port}
    write(server, "version", "0")
    write(server, "index.html", page(waiting(), 0))

    case :inets.start(:httpd, config(directory, port)) do
      {:ok, pid} ->
        {:ok, %{server | pid: pid, port: Keyword.fetch!(:httpd.info(pid), :port)}}

      {:error, reason} ->
        remove(directory)
        {:error, start_error(reason, port)}
    end
  end

  @doc """
  The address of the page of the server
  """
  @spec url(t()) :: String.t()
  def url(%__MODULE__{port: port}), do: "http://127.0.0.1:#{port}/"

  @doc """
  Serve a new document, and tell each open page to reload
  """
  @spec publish(t(), String.t()) :: t()
  def publish(server, html) do
    version = server.version + 1
    write(server, "index.html", page(html, version))
    write(server, "version", Integer.to_string(version))
    %{server | version: version}
  end

  @doc """
  Stop the server, and remove its directory
  """
  @spec stop(t()) :: :ok
  def stop(server) do
    :inets.stop(:httpd, server.pid)
    remove(server.directory)
    :ok
  end

  # `mod_alias` gives the directory index, `mod_get` sends a file, and
  # `mod_head` answers a HEAD request.
  defp config(directory, port) do
    [
      port: port,
      bind_address: {127, 0, 0, 1},
      server_name: ~c"expresso",
      server_root: String.to_charlist(directory),
      document_root: String.to_charlist(directory),
      directory_index: [~c"index.html"],
      modules: [:mod_alias, :mod_get, :mod_head],
      mime_types: [{~c"html", ~c"text/html; charset=utf-8"}],
      default_type: ~c"text/plain"
    ]
  end

  defp start_error(reason, port) do
    if in_use?(reason),
      do: "Port #{port} is in use. Give a different port with --port.",
      else: "Couldn't start the server on port #{port}: #{inspect(reason)}"
  end

  defp in_use?(:eaddrinuse), do: true

  defp in_use?(reason) when is_tuple(reason),
    do: reason |> Tuple.to_list() |> Enum.any?(&in_use?/1)

  defp in_use?(reason) when is_list(reason), do: Enum.any?(reason, &in_use?/1)
  defp in_use?(_reason), do: false

  # The name of the directory comes from this module, with a unique number.
  # sobelow_skip ["Traversal.FileModule"]
  defp directory do
    path = Path.join(System.tmp_dir!(), "expresso-watch-#{System.unique_integer([:positive])}")
    File.mkdir_p!(path)
    path
  end

  # The directory is the private directory of `directory/0`.
  # sobelow_skip ["Traversal.FileModule"]
  defp remove(directory) do
    File.rm_rf(directory)
    :ok
  end

  # The directory belongs to this server, and the names are fixed.
  # sobelow_skip ["Traversal.FileModule"]
  defp write(server, name, contents) do
    path = Path.join(server.directory, name)
    temporary = path <> ".tmp"
    File.write!(temporary, contents)
    File.rename!(temporary, path)
  end

  defp waiting do
    """
    <!DOCTYPE html>
    <html><head><meta charset="utf-8"><title>Expresso</title></head>
    <body><p>Expresso renders the deck. The terminal shows each error.</p></body></html>
    """
  end

  # The script goes in front of the last `</body>`, so a text of the deck
  # cannot move it.
  defp page(html, version) do
    script = reload_script(version)

    case String.split(html, "</body>") do
      [_no_body] ->
        html <> script

      parts ->
        {before, [last]} = Enum.split(parts, -1)
        Enum.join(before, "</body>") <> script <> "</body>" <> last
    end
  end

  defp reload_script(version) do
    """
    <script>
    (() => {
      const version = "#{version}";
      const ask = async () => {
        try {
          const response = await fetch("/version", { cache: "no-store" });
          if (response.ok && (await response.text()).trim() !== version) {
            location.reload();
            return;
          }
        } catch (_error) {}
        setTimeout(ask, #{@interval});
      };
      setTimeout(ask, #{@interval});
    })();
    </script>
    """
  end
end
