defmodule Expresso.Check.Session do
  @moduledoc """
  Runs `--check=browser`: the checks of the page in Playwright, and the keys of the presenter

  `--check=browser` runs each check of `--check=a11y`, and then it uses the
  presenter as the presenter does, with real key presses. It needs Node, the
  npm packages `playwright` and `axe-core`, the Chromium of Playwright, and
  the Hex package `playwright_ex`. `find/2` finds them.

  `run/4` writes a copy of the document with axe-core to a temporary
  directory, and opens it in a page of 1920 × 1080:

  1. With `?check=a11y`, the page runs the layout check and axe-core.
     `assets/src/check.ts` gives the rules.
  2. With no query, the session presses the key of the next step from the
     first step to the last step. After each key, the slide and the step that
     show must be the next entry of the list of the steps.
  3. The session opens the menu, the list of keys, the overview and the
     handout view with their keys. Each view must open. The menu and the list
     of keys must take the focus, and `Escape` must close them and give the
     focus back.
  4. Each error of the script of the page, and each `console.error`, during
     the steps 2 and 3 is a problem too.

  The keys come from the program of `Expresso.Presenter.Default`, so the
  check presses the keys that the list of keys of the deck shows.
  """

  # `playwright_ex` is an optional dependency. A project that uses Expresso
  # adds it only for this level, so the compiler must not warn about it.
  @compile {:no_warn_undefined,
            [
              PlaywrightEx,
              PlaywrightEx.Browser,
              PlaywrightEx.BrowserContext,
              PlaywrightEx.Frame,
              PlaywrightEx.Supervisor
            ]}

  alias Expresso.Check.Browser
  alias Expresso.Presenter.{Definition, Program}

  @typedoc "The tools of the session: the Playwright CLI and the axe-core file"
  @type tools :: %{cli: Path.t(), axe: Path.t()}

  @name Expresso.Check.Playwright
  @width 1920
  @height 1080

  # The time in milliseconds of one action of Playwright, and of the check of
  # the page.
  @timeout 15_000
  @check_timeout 600_000

  # The script that each page runs before its own script. It keeps each
  # error of the script and each `console.error`, so the session can read
  # them after each key.
  @errors """
  window.__expressoErrors = [];
  addEventListener("error", (event) => __expressoErrors.push(String(event.message)));
  addEventListener("unhandledrejection", (event) => __expressoErrors.push(String(event.reason)));
  const consoleError = console.error.bind(console);
  console.error = (...values) => {
    __expressoErrors.push(values.map(String).join(" "));
    consoleError(...values);
  };
  """

  # The slide and the step that the present view shows, such as "2.3".
  @position """
  (() => {
    const slide = [...document.querySelectorAll("section.slide")]
      .find((section) => section.style.display === "flex");
    return slide === undefined ? null : slide.id.replace("slide-", "") + "." + slide.dataset.step;
  })()
  """

  @doc """
  Find the tools of `--check=browser`

  The function looks for each tool in this sequence, and it returns the error
  of the first tool that it does not find:

    1. The Hex package `playwright_ex`.
    2. Node, as `node` on the `PATH`.
    3. The npm package `playwright`. The variable `EXPRESSO_PLAYWRIGHT` in
       `env` gives the path of its `cli.js`. Without it, the function looks
       for `node_modules/playwright/cli.js` in each directory of
       `directories`, in each parent of them, and in the directory of
       `Expresso.Check.Tools`.
    4. axe-core, as `Expresso.Check.Browser.find_axe/2` finds it.
  """
  @spec find([Path.t()], %{String.t() => String.t()}) :: {:ok, tools()} | {:error, String.t()}
  def find(directories, env \\ System.get_env()) do
    with :ok <- client(),
         :ok <- node_js(),
         {:ok, cli} <- cli(directories, env),
         {:ok, axe} <- Browser.find_axe(directories, env) do
      {:ok, %{cli: cli, axe: axe}}
    end
  end

  defp client do
    if Code.ensure_loaded?(PlaywrightEx),
      do: :ok,
      else:
        {:error,
         "--check=browser needs the Hex package playwright_ex. Add " <>
           ~s({:playwright_ex, "~> 0.14", only: :dev, runtime: false}) <>
           " to the deps of your project, and run `mix deps.get`. docs/how-to/check-a-deck.md tells how."}
  end

  defp node_js do
    if System.find_executable("node"),
      do: :ok,
      else:
        {:error,
         "--check=browser needs Node. Install Node, and put `node` on the PATH. " <>
           "docs/how-to/check-a-deck.md tells how."}
  end

  defp cli(directories, env) do
    case env["EXPRESSO_PLAYWRIGHT"] do
      nil -> search_cli(directories, env)
      path -> given_cli(path)
    end
  end

  defp given_cli(path) do
    if File.regular?(path),
      do: {:ok, path},
      else: {:error, "EXPRESSO_PLAYWRIGHT gives #{path}, and that file does not exist."}
  end

  defp search_cli(directories, env) do
    found =
      directories
      |> Browser.places(env)
      |> Enum.map(&Path.join(&1, "node_modules/playwright/cli.js"))
      |> Enum.find(&File.regular?/1)

    if found,
      do: {:ok, found},
      else:
        {:error,
         "--check=browser needs the npm package playwright. Run " <>
           "`mix expresso --install-check-tools`, or `expresso --install-check-tools` with the " <>
           "binary. You can also run `npm install --save-dev playwright axe-core` and " <>
           "`npx playwright install chromium` in the directory of the deck, or give the path " <>
           "of its cli.js in EXPRESSO_PLAYWRIGHT. docs/how-to/check-a-deck.md tells how."}
  end

  @doc """
  Run the checks of the page and the keys of the presenter on a document

  `deck` gives the list of the steps and the program of the keys. The option
  `:schemes` gives the variants of the theme, such as `[:light, :dark]`, and
  `[nil]` by default for the variant of the document. The option `:sizes`
  gives the sizes of the page, such as `[{1280, 720}]`, and
  `[{1920, 1080}]` by default. The page runs its checks one time for each
  size and each variant, and the keys run one time, at the first size and in
  the first variant.

  The function returns a list with a tuple `{{size, scheme}, result}` for
  each size and each variant. A result holds the result of the page, as
  `Expresso.Check.Browser.decode/1` returns it. The first result also holds
  the problems of the keys and of the script in `:session`. The option `:env`
  gives the environment, and `EXPRESSO_CHROMIUM` in it gives a different
  browser than the Chromium of Playwright.
  """
  @spec run(String.t(), Expresso.Deck.t(), tools(), keyword()) ::
          {:ok, [{{Expresso.Check.size(), :light | :dark | nil}, map()}]} | {:error, String.t()}
  # sobelow_skip ["Traversal"]
  def run(html, deck, tools, opts \\ []) do
    env = Keyword.get_lazy(opts, :env, &System.get_env/0)
    schemes = Keyword.get(opts, :schemes, [nil])
    sizes = Keyword.get(opts, :sizes, [{@width, @height}])

    directory =
      Path.join(System.tmp_dir!(), "expresso-session-#{System.unique_integer([:positive])}")

    File.mkdir_p!(directory)
    page_path = Path.join(directory, "deck.html")
    File.write!(page_path, Browser.with_axe(html, tools.axe))
    previous = Process.flag(:trap_exit, true)

    try do
      with {:ok, supervisor} <- start(tools.cli),
           {:ok, browser} <- launch(env) do
        try do
          session(browser, "file://" <> page_path, deck, sizes, schemes)
        after
          Supervisor.stop(supervisor)
        end
      end
    after
      Process.flag(:trap_exit, previous)
      File.rm_rf(directory)
    end
  end

  defp start(cli) do
    case PlaywrightEx.Supervisor.start_link(timeout: @timeout, executable: cli, name: @name) do
      {:ok, supervisor} -> {:ok, supervisor}
      {:error, reason} -> {:error, "Playwright did not start: #{inspect(reason)}"}
    end
  rescue
    error -> {:error, "Playwright did not start: #{Exception.message(error)}"}
  end

  defp launch(env) do
    options =
      [timeout: @timeout, headless: true, connection: connection()] ++
        if path = env["EXPRESSO_CHROMIUM"], do: [executable_path: path], else: []

    case PlaywrightEx.launch_browser(:chromium, options) do
      {:ok, browser} ->
        {:ok, browser}

      {:error, reason} ->
        {:error,
         "Playwright did not start Chromium: #{first_line(reason)}. Run `npx playwright install " <>
           "chromium`, or give a browser in EXPRESSO_CHROMIUM."}
    end
  end

  # The first line of the message of an error of Playwright. The other lines
  # hold a box of text and the stack of the driver.
  defp first_line(%{error: %{message: message}}),
    do: message |> String.split("\n", parts: 2) |> hd()

  defp first_line(reason), do: inspect(reason)

  defp connection, do: PlaywrightEx.Supervisor.connection_name(@name)

  defp options(extra \\ []), do: [timeout: @timeout, connection: connection()] ++ extra

  # Open a page for each size, run the checks of the page for each size and
  # each variant, and then press the keys in the page of the first size.
  defp session(browser, url, deck, sizes, schemes) do
    frames = Map.new(sizes, &{&1, frame(browser, &1)})
    runs = for size <- sizes, scheme <- schemes, do: {size, scheme}

    with {:ok, [{run, result} | others]} <- check_runs(frames, url, runs) do
      problems = keys(Map.fetch!(frames, hd(sizes)), url, deck)
      {:ok, [{run, Map.put(result, :session, problems)} | others]}
    end
  end

  # A page of a size, in a context of its own, with the script that keeps
  # the errors.
  defp frame(browser, {width, height}) do
    {:ok, context} =
      PlaywrightEx.Browser.new_context(
        browser.guid,
        options(viewport: %{width: width, height: height}, reduced_motion: "reduce")
      )

    {:ok, _result} =
      PlaywrightEx.BrowserContext.add_init_script(context.guid, options(source: @errors))

    {:ok, page} = PlaywrightEx.BrowserContext.new_page(context.guid, options())
    %{frame: page.main_frame.guid}
  end

  defp check_runs(frames, url, runs) do
    Enum.reduce_while(runs, {:ok, []}, fn {size, scheme} = run, {:ok, results} ->
      case check_page(Map.fetch!(frames, size), url, scheme) do
        {:ok, result} -> {:cont, {:ok, results ++ [{run, result}]}}
        error -> {:halt, error}
      end
    end)
  end

  # Open the page with `?check=a11y`, wait for the end of the check, and read
  # its result.
  defp check_page(frame, url, scheme) do
    address = Browser.scheme(url <> "?check=a11y", scheme)
    {:ok, _response} = PlaywrightEx.Frame.goto(frame.frame, options(url: address))

    case wait(frame, "document.body.dataset.check === 'done'", @check_timeout) do
      true ->
        frame |> js("document.getElementById('check-result').textContent") |> Browser.decode()

      false ->
        {:error, "The page did not end its check in #{div(@check_timeout, 60_000)} minutes."}
    end
  end

  # Press the keys of the presenter, and return the problems.
  defp keys(frame, url, deck) do
    {:ok, _response} = PlaywrightEx.Frame.goto(frame.frame, options(url: url))
    program = Program.compile(Definition.presenter(), deck)
    steps = deck |> Expresso.Steps.entries() |> Enum.map(&"#{&1.slide}.#{&1.step}")

    problems = walk(frame, steps, key(program, :present, {:step, 1})) ++ views(frame, program)
    problems ++ Enum.map(js(frame, "window.__expressoErrors"), &"The script: #{&1}")
  end

  # Press the key of the next step at each step, and compare the step that
  # shows with the next entry of the list. The walk stops at the first
  # difference, because each later step then differs too.
  defp walk(frame, [first | rest], key) do
    if shows?(frame, first),
      do: walk_from(frame, first, rest, key),
      else: ["The keys: the deck opens at #{shown(frame)}, and not at #{first}"]
  end

  defp walk(_frame, [], _key), do: []

  defp walk_from(_frame, _current, [], _key), do: []

  defp walk_from(frame, current, [next | rest], key) do
    press(frame, key)

    if shows?(frame, next),
      do: walk_from(frame, next, rest, key),
      else: [
        "The keys: #{label(key)} at #{current} shows #{shown(frame)}, and not the next step #{next}"
      ]
  end

  defp shows?(frame, position), do: wait(frame, "#{@position} === #{JSON.encode!(position)}")
  defp shown(frame), do: js(frame, @position) || "no slide"

  # Open each view with its key, and close it again. The present view shows
  # step 1 again first, because the walk ends at the last step.
  defp views(frame, program) do
    first = key(program, :present, {:goto, 0})
    press(frame, first)
    _shown = wait(frame, "#{@position} === '1.1'")

    [
      view(frame, "the menu", key(program, :present, {:set, :menu, true}), "menu", "#menu"),
      view(
        frame,
        "the list of keys",
        key(program, :present, {:set, :help, true}),
        "help",
        "#help"
      ),
      view(
        frame,
        "the overview",
        key(program, :present, {:set, :overview, true}),
        "overview",
        nil
      ),
      handout(frame, key(program, :present, {:set, :view, :handout}))
    ]
    |> List.flatten()
  end

  defp view(frame, name, key, field, focus) do
    press(frame, key)

    opened =
      if wait(frame, "document.body.dataset.#{field} === 'true'"),
        do: focus_problems(frame, name, key, focus),
        else: ["The keys: #{label(key)} does not open #{name}"]

    press(frame, "Escape")

    closed =
      if wait(frame, "document.body.dataset.#{field} !== 'true'"),
        do: focus_back(frame, name, focus),
        else: ["The keys: Escape does not close #{name}"]

    opened ++ closed
  end

  defp focus_problems(_frame, _name, _key, nil), do: []

  defp focus_problems(frame, name, key, focus) do
    if wait(frame, "document.activeElement?.closest('#{focus}') != null"),
      do: [],
      else: ["The keys: #{name} opens with #{label(key)}, but it does not take the focus"]
  end

  defp focus_back(_frame, _name, nil), do: []

  defp focus_back(frame, name, focus) do
    if wait(frame, "document.activeElement?.closest('#{focus}') == null"),
      do: [],
      else: ["The keys: the focus stays in #{name} after Escape"]
  end

  defp handout(frame, key) do
    press(frame, key)

    if wait(frame, "document.body.dataset.view === 'handout'"),
      do: [],
      else: ["The keys: #{label(key)} does not open the handout view"]
  end

  @doc """
  Return the key of a mode of a program that runs a command

  A binding with more than one key gives the key that the list of keys shows
  first in this sense: a letter before another key, and a short name before
  a long name.

      iex> deck = Expresso.Builder.deck([Expresso.Builder.slide("one", elements: [])], name: "k")
      iex> program = Expresso.Presenter.Program.compile(Expresso.Presenter.Definition.presenter(), deck)
      iex> Expresso.Check.Session.key(program, :present, {:step, 1})
      "j"
      iex> Expresso.Check.Session.key(program, :present, {:set, :menu, true})
      "m"
  """
  @spec key(Program.t(), atom(), tuple()) :: String.t()
  def key(program, mode, command) do
    program.modes
    |> Enum.find(&(&1.name == mode))
    |> Map.fetch!(:keys)
    |> Enum.filter(fn {_key, commands} -> command in commands end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.min_by(&{not (String.length(&1) == 1 and &1 =~ ~r/^[a-z]$/), String.length(&1), &1})
  end

  # The name of a key in the report. A space is not readable alone.
  defp label(" "), do: "Space"
  defp label(key), do: key

  # Press a key on the element with the focus, as a key of the presenter
  # does. A press on another element would first move the focus to it, so
  # the page marks the element with the focus, and Playwright presses the key
  # on the mark.
  @mark """
  (() => {
    for (const element of document.querySelectorAll("[data-expresso-key]")) {
      element.removeAttribute("data-expresso-key");
    }
    (document.activeElement ?? document.body).setAttribute("data-expresso-key", "");
  })()
  """

  defp press(frame, key) do
    js(frame, @mark)

    {:ok, _result} =
      PlaywrightEx.Frame.press(frame.frame, options(selector: "[data-expresso-key]", key: key))

    :ok
  end

  # Wait until a JavaScript expression is true in the page, and return
  # whether it became true in the time. A key changes the document in a frame
  # of the browser, or after a transition, so a check right after the key can
  # read the document before the change.
  @wait 2_000
  defp wait(frame, expression, timeout \\ @wait) do
    match?(
      {:ok, _handle},
      PlaywrightEx.Frame.wait_for_function(frame.frame,
        timeout: timeout,
        connection: connection(),
        expression: expression,
        is_function: false,
        arg: nil
      )
    )
  end

  defp js(frame, expression) do
    {:ok, value} =
      PlaywrightEx.Frame.evaluate(
        frame.frame,
        options(expression: expression, is_function: false, arg: nil)
      )

    value
  end
end
