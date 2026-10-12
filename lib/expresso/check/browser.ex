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
  # the search.
  @names ~w(chromium chromium-browser google-chrome google-chrome-stable chrome headless_shell chrome-headless-shell)
  @mac_paths [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium"
  ]

  # The browsers of Playwright, in its cache on Linux and on macOS. The headless
  # shell comes first, because it starts faster.
  @playwright [
    "~/.cache/ms-playwright/chromium_headless_shell-*/chrome-*/headless_shell",
    "~/Library/Caches/ms-playwright/chromium_headless_shell-*/chrome-*/headless_shell",
    "~/.cache/ms-playwright/chromium-*/chrome-linux/chrome",
    "~/Library/Caches/ms-playwright/chromium-*/chrome-mac*/Chromium.app/Contents/MacOS/Chromium"
  ]

  @width 1920
  @height 1080

  # The time in the page that the check can use. The browser advances this
  # time only when the page waits, so a slow computer does not make the check
  # fail.
  @budget 600_000

  @doc """
  Find Chrome or Chromium

  The variable `EXPRESSO_CHROMIUM` in `env` gives the path of the browser. Without
  it, the function looks for each usual name of the browser on the `PATH`, then
  in the usual places of macOS, and then in the cache of Playwright.
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
        Enum.find_value(@playwright, &(&1 |> Path.expand() |> Path.wildcard() |> List.last()))

    if found,
      do: {:ok, found},
      else:
        {:error,
         "This level of --check needs Chrome or Chromium. Install one of them, or give its " <>
           "path in EXPRESSO_CHROMIUM. docs/how-to/check-a-deck.md tells how."}
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

  defp ancestors(directory) do
    case Path.dirname(directory) do
      ^directory -> [directory]
      parent -> [directory | ancestors(parent)]
    end
  end

  @doc """
  Run the check of the page on a document in the browser, and return the result

  With `axe`, the path of `axe.min.js`, the page also runs axe-core. The
  function returns an error when the browser does not start, or when the page
  writes no result.
  """
  @spec run(String.t(), Path.t(), Path.t() | nil) :: {:ok, result()} | {:error, String.t()}
  # sobelow_skip ["Traversal"]
  def run(html, browser, axe \\ nil) do
    directory =
      Path.join(System.tmp_dir!(), "expresso-check-#{System.unique_integer([:positive])}")

    File.mkdir_p!(directory)

    try do
      page = Path.join(directory, "deck.html")
      File.write!(page, with_axe(html, axe))
      url = "file://#{page}?" <> if(axe, do: "check=a11y", else: "check")
      measure(browser, url, directory, {@width, @height})
    after
      File.rm_rf(directory)
    end
  end

  # Put axe-core into the document before the end of its `body`. A `</script`
  # in the source of axe-core would close the element, so it gets a backslash,
  # which JavaScript reads as the same text.
  defp with_axe(html, nil), do: html

  # sobelow_skip ["Traversal"]
  defp with_axe(html, axe) do
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
  defp measure(browser, url, directory, {width, height} = window) do
    probe = Path.join(directory, "size.html")

    File.write!(
      probe,
      "<body><script>document.body.dataset.size = innerWidth + \" \" + innerHeight</script></body>"
    )

    with {:ok, dom} <- browse(browser, "file://#{probe}", directory, window),
         [w, h] <- Regex.run(~r/data-size="(\d+) (\d+)"/, dom, capture: :all_but_first) do
      larger = {width + @width - String.to_integer(w), height + @height - String.to_integer(h)}
      with {:ok, dom} <- browse(browser, url, directory, larger), do: result(dom)
    else
      {:error, _message} = error -> error
      nil -> {:error, "The browser #{browser} did not run the script of a page."}
    end
  end

  defp browse(browser, url, directory, {width, height}) do
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
    # that log, so the output of the command holds only the report.
    case System.cmd("sh", ["-c", ~s(exec "$0" "$@" 2>/dev/null), browser | args]) do
      {dom, 0} -> {:ok, dom}
      {_dom, status} -> {:error, "The browser #{browser} stopped with the exit status #{status}."}
    end
  rescue
    error in ErlangError ->
      {:error, "The browser #{browser} did not start: #{Exception.message(error)}"}
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
    with [json] <- Regex.run(@result, dom, capture: :all_but_first),
         {:ok, %{"width" => width, "height" => height, "layout" => layout} = value} <-
           JSON.decode(json) do
      {:ok,
       %{width: width, height: height, layout: layout, accessibility: value["accessibility"]}}
    else
      _other ->
        {:error,
         "The page wrote no result. The script of the deck stopped, or the check did not " <>
           "end in the time of the browser."}
    end
  end
end
