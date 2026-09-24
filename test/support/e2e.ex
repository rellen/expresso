defmodule Expresso.E2E do
  @moduledoc """
  The case template of the browser tests

  A browser test renders a deck to an HTML file, opens the file in Chromium
  with Playwright, and operates the presenter as a person does. `use
  Expresso.E2E` tags each test of the module with `:e2e`. `test_helper.exs`
  excludes that tag, so `mix test` does not start a browser. `mix test --only
  e2e` runs these tests. `docs/development.md` gives the setup.

  Each module starts one Playwright connection and one browser. Each test gets
  a new browser context and a new page, so no state goes from one test to the
  next. The context asks for reduced motion, and the theme then sets each
  duration to zero. Therefore a test can read a style right after a key.

  The environment variable `EXPRESSO_CHROMIUM` gives the path of a Chromium
  executable. Without it, Playwright uses its own browser, which
  `npx playwright install chromium` installs.
  """

  use ExUnit.CaseTemplate

  alias PlaywrightEx.{Browser, BrowserContext, Connection, EventWaiter, Frame, Page}

  @timeout 10_000

  using do
    quote do
      import Expresso.E2E

      @moduletag :e2e
      @moduletag :tmp_dir
    end
  end

  setup_all do
    start_supervised!(
      {PlaywrightEx.Supervisor, timeout: @timeout, executable: "node_modules/playwright/cli.js"}
    )

    launch = [timeout: @timeout, headless: true]

    launch =
      case System.get_env("EXPRESSO_CHROMIUM") do
        nil -> launch
        path -> Keyword.put(launch, :executable_path, path)
      end

    {:ok, browser} = PlaywrightEx.launch_browser(:chromium, launch)
    %{browser: browser}
  end

  setup %{browser: browser} do
    {:ok, context} =
      Browser.new_context(browser.guid,
        timeout: @timeout,
        viewport: %{width: 1280, height: 720},
        reduced_motion: "reduce"
      )

    {:ok, page} = BrowserContext.new_page(context.guid, timeout: @timeout)
    on_exit(fn -> BrowserContext.close(context.guid, timeout: @timeout) end)
    %{context: context, page: page}
  end

  @doc """
  Render a deck to an HTML file in the directory of the test, and give its
  address. The deck is a module of the DSL or an `Expresso.Deck` struct.
  """
  @spec render(module() | Expresso.Deck.t(), String.t(), String.t()) :: String.t()
  def render(deck, tmp_dir, name \\ "deck") do
    {:ok, deck} = Expresso.to_deck(deck)
    path = Path.join(tmp_dir, name <> ".html")
    File.write!(path, Expresso.Deck.render(deck))
    "file://" <> path
  end

  @doc """
  Open an address in a page, and wait for the load of the document
  """
  @spec open(map(), String.t()) :: map()
  def open(page, url) do
    {:ok, _response} = Frame.goto(page.main_frame.guid, timeout: @timeout, url: url)
    page
  end

  @doc """
  Press one key in a page, such as `"j"`, `"ArrowRight"` or `"Shift+Slash"`
  """
  @spec press(map(), String.t()) :: map()
  def press(page, key) do
    {:ok, _result} =
      Frame.press(page.main_frame.guid, timeout: @timeout, selector: "body", key: key)

    page
  end

  @doc """
  Press each key of a list in a page, in sequence
  """
  @spec keys(map(), [String.t()]) :: map()
  def keys(page, keys), do: Enum.reduce(keys, page, &press(&2, &1))

  @doc """
  Click the main mouse button at a point of the viewport of a page
  """
  @spec click(map(), number(), number()) :: map()
  def click(page, x, y) do
    {:ok, _result} = Page.mouse_move(page.guid, timeout: @timeout, x: x, y: y)
    {:ok, _result} = Page.mouse_down(page.guid, timeout: @timeout)
    {:ok, _result} = Page.mouse_up(page.guid, timeout: @timeout)
    page
  end

  @doc """
  Tap a point of the viewport of a page with a finger

  The context of the page must have `has_touch: true`.
  """
  @spec tap(map(), number(), number()) :: map()
  def tap(page, x, y) do
    case PlaywrightEx.send(
           %{guid: page.guid, method: :touchscreen_tap, params: %{x: x, y: y}},
           timeout: @timeout
         ) do
      %{error: error} -> raise "touchscreen_tap failed: #{inspect(error)}"
      _response -> page
    end
  end

  @doc """
  Move one finger across a page from one point to another point

  Playwright has a tap but no swipe, so the page gets the touch events from a
  script. Each point is a tuple `{x, y}` in the viewport.
  """
  @spec swipe(map(), {number(), number()}, {number(), number()}) :: map()
  def swipe(page, {x1, y1}, {x2, y2}) do
    js(page, """
    (() => {
      const target = document.elementFromPoint(#{x1}, #{y1}) ?? document.body;
      const touch = (x, y) =>
        new Touch({ identifier: 1, target, clientX: x, clientY: y });
      const start = touch(#{x1}, #{y1});
      const end = touch(#{x2}, #{y2});
      const send = (type, touches, changed) =>
        target.dispatchEvent(new TouchEvent(type, {
          bubbles: true, cancelable: true, touches, targetTouches: touches,
          changedTouches: changed
        }));
      send("touchstart", [start], [start]);
      send("touchmove", [end], [end]);
      send("touchend", [], [end]);
    })()
    """)

    page
  end

  @doc """
  Give the value of a JavaScript expression in a page
  """
  @spec js(map(), String.t()) :: term()
  def js(page, expression) do
    {:ok, value} =
      Frame.evaluate(page.main_frame.guid,
        timeout: @timeout,
        expression: expression,
        is_function: false,
        arg: nil
      )

    value
  end

  @doc """
  Give the position of the present view, such as `"2.3"`: the number of the
  slide that shows and its step
  """
  @spec position(map()) :: String.t()
  def position(page) do
    js(page, """
    (() => {
      const slide = [...document.querySelectorAll("section.slide")]
        .find((section) => section.style.display === "flex");
      return slide.id.replace("slide-", "") + "." + slide.dataset.step;
    })()
    """)
  end

  @doc """
  Give the pages of the handout view that a reader sees, such as `["1.1", "2.3"]`
  """
  @spec shown_pages(map()) :: [String.t()]
  def shown_pages(page) do
    js(page, """
    [...document.querySelectorAll(".handout-page")]
      .filter((page) => getComputedStyle(page).display !== "none")
      .map((page) => page.dataset.slide + "." + page.dataset.step)
    """)
  end

  @doc """
  Reload a page, and wait for the load of the document
  """
  @spec reload(map()) :: map()
  def reload(page) do
    {:ok, _response} = Page.reload(page.guid, timeout: @timeout)
    page
  end

  @doc """
  Print a page to PDF with the media of a printer, and give the number of
  pages of the PDF

  The function counts the page objects of the PDF, so it needs no PDF tool.
  The page then gets the media of a screen again.
  """
  @spec pdf_pages(map()) :: non_neg_integer()
  def pdf_pages(page) do
    emulate(page, "print")

    %{result: %{pdf: pdf}} =
      PlaywrightEx.send(
        %{guid: page.guid, method: :pdf, params: %{landscape: true}},
        timeout: @timeout
      )

    emulate(page, "screen")
    ~r{/Type\s*/Page\b(?!s)} |> Regex.scan(Base.decode64!(pdf)) |> length()
  end

  @doc """
  Give a page the media of a printer or of a screen
  """
  @spec emulate(map(), String.t()) :: map()
  def emulate(page, media) do
    # The driver answers with no result for this method, and with an error
    # when it fails.
    case PlaywrightEx.send(
           %{guid: page.guid, method: :emulate_media, params: %{media: media}},
           timeout: @timeout
         ) do
      %{error: error} -> raise "emulate_media failed: #{inspect(error)}"
      _response -> page
    end
  end

  @doc """
  Run a function that opens a second window, and give the page of that window

  The function waits for the load of the document of the new page.
  """
  @spec popup(map(), (-> term())) :: map()
  def popup(context, action) do
    {:ok, waiter} = EventWaiter.arm(context.guid, :page, timeout: @timeout)

    try do
      action.()
      {:ok, %{params: %{page: %{guid: guid}}}} = EventWaiter.await(waiter)
      initializer = Connection.initializer!(PlaywrightEx.Supervisor.Connection, guid)
      page = %{guid: guid, main_frame: initializer.main_frame}

      {:ok, _result} =
        Frame.wait_for_load_state(page.main_frame.guid, timeout: @timeout, state: "load")

      page
    after
      EventWaiter.cancel(waiter)
    end
  end

  @doc """
  Wait until a JavaScript expression in a page gives a true value
  """
  @spec wait_for(map(), String.t()) :: map()
  def wait_for(page, expression) do
    {:ok, _result} =
      Frame.wait_for_function(page.main_frame.guid,
        timeout: @timeout,
        expression: expression,
        is_function: false,
        arg: nil,
        polling: 50
      )

    page
  end
end
