defmodule Expresso.Check.Browser do
  @moduledoc """
  Runs the layout check and the accessibility check of a document in a headless browser

  `--check=layout` and `--check=a11y` need Chrome or Chromium. The function
  `find/1` finds the browser, and `find_axe/2` finds axe-core for
  `--check=a11y`. `run/3` writes a copy of the document to a temporary
  directory, with axe-core in it for `--check=a11y`. The browser opens the copy
  with `?check` or `?check=a11y`, and it writes the document to its standard
  output after the check. The script of the page writes the result into an
  element `check-result`. `assets/src/check.ts` gives the rules.

  The page has the size 1920 × 1080. A browser can keep a part of the window
  for itself, so `run/3` first opens a small page that writes its size, and it
  makes the window larger by the difference.
  """

  @typedoc "The result of the page: the size, the problems of the layout and the violations of axe-core"
  @type result :: %{
          width: pos_integer(),
          height: pos_integer(),
          layout: [String.t()],
          accessibility: [map()] | nil
        }

  # The names of Chrome and Chromium on Linux and on macOS, in the order of
  # the search. Chrome comes first: on Ubuntu, `chromium` can be a command
  # that installs a snap, and that command does not end.
  @names ~w(google-chrome google-chrome-stable chrome chrome-headless-shell headless_shell chromium chromium-browser)
  @mac_paths [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium"
  ]

  # The browsers of Playwright, in its cache on Linux and on macOS. The headless
  # shell comes first, because it starts faster. The names of the files
  # changed in Playwright 1.57, so each browser has an old and a new pattern.
  @playwright [
    "~/.cache/ms-playwright/chromium_headless_shell-*/chrome-headless-shell-*/chrome-headless-shell",
    "~/.cache/ms-playwright/chromium_headless_shell-*/chrome-linux/headless_shell",
    "~/Library/Caches/ms-playwright/chromium_headless_shell-*/chrome-headless-shell-*/chrome-headless-shell",
    "~/Library/Caches/ms-playwright/chromium_headless_shell-*/chrome-mac*/headless_shell",
    "~/.cache/ms-playwright/chromium-*/chrome-linux*/chrome",
    "~/Library/Caches/ms-playwright/chromium-*/chrome-mac*/*.app/Contents/MacOS/*"
  ]

  @width 1920
  @height 1080

  # The time in the page that the check can use. The browser advances this
  # time only when the page waits, so a slow computer does not make the check
  # fail.
  @budget 600_000

  # The time in milliseconds that a run of the browser can take. A browser
  # that does not end in this time is stopped, so a browser that waits for
  # ever does not stop the command. The small page of the size needs less.
  @probe_timeout 30_000
  @timeout 600_000

  @doc """
  Find Chrome or Chromium

  The variable `EXPRESSO_CHROMIUM` in `env` gives the path of the browser. Without
  it, the function looks for each usual name of the browser on the `PATH`, then
  in the usual places of macOS, and then in the cache of Playwright. Chrome
  comes before Chromium, because `chromium` on Ubuntu can be a command that
  installs a snap.
  """
  @spec find(%{String.t() => String.t()}) :: {:ok, Path.t()} | {:error, String.t()}
  def find(env \\ System.get_env()) do
    case env["EXPRESSO_CHROMIUM"] do
      nil -> search()
      path -> given(path)
    end
  end

  defp given(path) do
    if File.regular?(path),
      do: {:ok, path},
      else: {:error, "EXPRESSO_CHROMIUM gives #{path}, and that file does not exist."}
  end

  defp search do
    found =
      Enum.find_value(@names, &System.find_executable/1) ||
        Enum.find(@mac_paths, &File.regular?/1) ||
        playwright()

    if found,
      do: {:ok, found},
      else:
        {:error,
         "This level of --check needs Chrome or Chromium. Install one of them, or give its " <>
           "path in EXPRESSO_CHROMIUM. docs/how-to/check-a-deck.md tells how."}
  end

  @doc """
  Return the path of a browser in the cache of Playwright, or `nil`

  The function prefers the headless shell, and the latest version of each
  browser.
  """
  @spec playwright() :: Path.t() | nil
  def playwright do
    Enum.find_value(@playwright, fn pattern ->
      pattern |> Path.expand() |> Path.wildcard() |> Enum.filter(&File.regular?/1) |> List.last()
    end)
  end

  @doc """
  Find the file `axe.min.js` of axe-core

  The variable `EXPRESSO_AXE` in `env` gives the path of the file. Without it,
  the function looks for `node_modules/axe-core/axe.min.js` in each directory
  of `directories`, and in each parent of them.
  """
  @spec find_axe([Path.t()], %{String.t() => String.t()}) ::
          {:ok, Path.t()} | {:error, String.t()}
  def find_axe(directories, env \\ System.get_env()) do
    case env["EXPRESSO_AXE"] do
      nil -> search_axe(directories)
      path -> given_axe(path)
    end
  end

  defp given_axe(path) do
    if File.regular?(path),
      do: {:ok, path},
      else: {:error, "EXPRESSO_AXE gives #{path}, and that file does not exist."}
  end

  defp search_axe(directories) do
    found =
      directories
      |> Enum.flat_map(&ancestors(Path.expand(&1)))
      |> Enum.uniq()
      |> Enum.map(&Path.join(&1, "node_modules/axe-core/axe.min.js"))
      |> Enum.find(&File.regular?/1)

    if found,
      do: {:ok, found},
      else:
        {:error,
         "--check=a11y needs axe-core. Run `npm install --save-dev axe-core` in the " <>
           "directory of the deck, or give the path of axe.min.js in EXPRESSO_AXE. " <>
           "docs/how-to/check-a-deck.md tells how."}
  end

  @doc false
  @spec ancestors(Path.t()) :: [Path.t()]
  def ancestors(directory) do
    case Path.dirname(directory) do
      ^directory -> [directory]
      parent -> [directory | ancestors(parent)]
    end
  end

  @doc """
  Run the check of the page on a document in the browser, and return the result

  With `axe`, the path of `axe.min.js`, the page also runs axe-core. The
  function returns an error when the browser does not start, or when the page
  writes no result. The option `:probe_timeout` gives the time in
  milliseconds for the small page of the size, 30 000 by default, and
  `:timeout` gives the time for the check, 600 000 by default. The option
  `:scheme`, `:light` or `:dark`, shows that variant of a theme with two
  variants, with `?scheme=` in the address.
  """
  @spec run(String.t(), Path.t(), Path.t() | nil, keyword()) ::
          {:ok, result()} | {:error, String.t()}
  # sobelow_skip ["Traversal"]
  def run(html, browser, axe \\ nil, opts \\ []) do
    directory =
      Path.join(System.tmp_dir!(), "expresso-check-#{System.unique_integer([:positive])}")

    File.mkdir_p!(directory)

    try do
      page = Path.join(directory, "deck.html")
      File.write!(page, with_axe(html, axe))
      url = "file://#{page}?" <> if(axe, do: "check=a11y", else: "check")
      url = scheme(url, Keyword.get(opts, :scheme))

      timeouts = {
        Keyword.get(opts, :probe_timeout, @probe_timeout),
        Keyword.get(opts, :timeout, @timeout)
      }

      measure(browser, url, directory, {@width, @height}, timeouts)
    after
      File.rm_rf(directory)
    end
  end

  @doc """
  Add the variant of a theme to the address of a page

      iex> Expresso.Check.Browser.scheme("file:///d.html?check", :dark)
      "file:///d.html?check&scheme=dark"
      iex> Expresso.Check.Browser.scheme("file:///d.html?check", nil)
      "file:///d.html?check"
  """
  @spec scheme(String.t(), :light | :dark | nil) :: String.t()
  def scheme(url, nil), do: url
  def scheme(url, scheme), do: "#{url}&scheme=#{scheme}"

  @doc """
  Put axe-core into a document before the end of its `body`

  `axe` is the path of `axe.min.js`, or `nil` for no change. A `</script` in
  the source of axe-core would close the element, so it gets a backslash,
  which JavaScript reads as the same text. `Expresso.Check.Session` also
  calls this function.
  """
  @spec with_axe(String.t(), Path.t() | nil) :: String.t()
  def with_axe(html, nil), do: html

  # sobelow_skip ["Traversal"]
  def with_axe(html, axe) do
    source = axe |> File.read!() |> String.replace("</script", "<\\/script")
    [head, tail] = split_last(html, "</body>")
    IO.iodata_to_binary([head, "<script>", source, "</script></body>", tail])
  end

  defp split_last(text, pattern) do
    case :binary.matches(text, pattern) do
      [] ->
        [text, ""]

      matches ->
        {start, length} = List.last(matches)

        [
          binary_part(text, 0, start),
          binary_part(text, start + length, byte_size(text) - start - length)
        ]
    end
  end

  # Find the size of the window that gives a page of 1920 × 1080. A small page
  # writes its size, and the window grows by the difference. Then run the
  # check one time in a window of that size.
  # sobelow_skip ["Traversal"]
  defp measure(browser, url, directory, {width, height} = window, {probe_timeout, timeout}) do
    probe = Path.join(directory, "size.html")

    File.write!(
      probe,
      "<body><script>document.body.dataset.size = innerWidth + \" \" + innerHeight</script></body>"
    )

    with {:ok, dom} <- browse(browser, "file://#{probe}", directory, window, probe_timeout),
         [w, h] <- Regex.run(~r/data-size="(\d+) (\d+)"/, dom, capture: :all_but_first) do
      larger = {width + @width - String.to_integer(w), height + @height - String.to_integer(h)}
      with {:ok, dom} <- browse(browser, url, directory, larger, timeout), do: result(dom)
    else
      {:error, _message} = error -> error
      nil -> {:error, "The browser #{browser} did not run the script of a page."}
    end
  end

  defp browse(browser, url, directory, {width, height}, timeout) do
    args = [
      "--headless",
      "--no-sandbox",
      "--disable-gpu",
      "--hide-scrollbars",
      "--mute-audio",
      "--no-first-run",
      "--user-data-dir=#{Path.join(directory, "profile")}",
      "--window-size=#{width},#{height}",
      "--virtual-time-budget=#{@budget}",
      "--dump-dom",
      url
    ]

    # The browser writes its own log to the standard error. The shell drops
    # that log, so the output of the command holds only the document. The
    # shell starts the browser in its own process, so `kill` stops it.
    port =
      Port.open({:spawn_executable, System.find_executable("sh")}, [
        :binary,
        :exit_status,
        args: ["-c", ~s(exec "$0" "$@" 2>/dev/null), browser | args]
      ])

    # A browser that exits at once closes the port before `Port.info/2`,
    # which then returns `nil`. Its exit status is already in the mailbox.
    pid =
      case Port.info(port, :os_pid) do
        {:os_pid, pid} -> pid
        nil -> nil
      end

    deadline = System.monotonic_time(:millisecond) + timeout
    collect(port, %{pid: pid, browser: browser, deadline: deadline, timeout: timeout}, [])
  end

  # Read the output of the browser until it exits, or until the time ends.
  defp collect(port, run, output) do
    wait = max(run.deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {^port, {:data, data}} ->
        collect(port, run, [output, data])

      {^port, {:exit_status, 0}} ->
        {:ok, IO.iodata_to_binary(output)}

      {^port, {:exit_status, status}} ->
        {:error, "The browser #{run.browser} stopped with the exit status #{status}."}
    after
      wait ->
        if run.pid, do: System.cmd("kill", ["-9", Integer.to_string(run.pid)])

        receive do
          {^port, {:exit_status, _status}} -> :ok
        after
          5_000 -> :ok
        end

        {:error,
         "The browser #{run.browser} did not end in #{div(run.timeout, 1000)} s. Give a " <>
           "different browser in EXPRESSO_CHROMIUM, such as the headless shell of Playwright."}
    end
  end

  # The element of the result. The presenter script holds the text
  # `id="check-result"` too, so the pattern starts at the tag.
  @result ~r/<script[^>]*\bid="check-result"[^>]*>(.*?)<\/script>/s

  @doc """
  Read the result of the page from the document that the browser writes

      iex> dom = ~s(<body><script type="application/json" id="check-result">) <>
      ...>   ~s({"width":1920,"height":1080,"layout":[],"accessibility":null}</script></body>)
      iex> Expresso.Check.Browser.result(dom)
      {:ok, %{width: 1920, height: 1080, layout: [], accessibility: nil}}
  """
  @spec result(String.t()) :: {:ok, result()} | {:error, String.t()}
  def result(dom) do
    case Regex.run(@result, dom, capture: :all_but_first) do
      [json] -> decode(json)
      nil -> no_result()
    end
  end

  @doc """
  Read the JSON of the element `check-result`

      iex> Expresso.Check.Browser.decode(~s({"width":1920,"height":1080,"layout":["x"],"accessibility":[]}))
      {:ok, %{width: 1920, height: 1080, layout: ["x"], accessibility: []}}
  """
  @spec decode(String.t()) :: {:ok, result()} | {:error, String.t()}
  def decode(json) do
    case JSON.decode(json) do
      {:ok, %{"width" => width, "height" => height, "layout" => layout} = value} ->
        {:ok,
         %{width: width, height: height, layout: layout, accessibility: value["accessibility"]}}

      _other ->
        no_result()
    end
  end

  defp no_result,
    do:
      {:error,
       "The page wrote no result. The script of the deck stopped, or the check did not " <>
         "end in the time of the browser."}
end
