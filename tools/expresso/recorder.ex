defmodule Expresso.Recorder do
  @moduledoc """
  Records the frames of a deck in Chromium while it does the keys of an example

  `mix expresso.gifs` uses this module. `start/0` starts Playwright and one
  browser, `record/2` returns the frames of one example, and `stop/1` closes
  the browser. `Expresso.Gif` then encodes the frames as a GIF.

  A GIF must show each animation in the same way on each run. Therefore the
  recorder pauses the animations of the page after each key. It moves each
  animation to the time of each frame, and it takes a screenshot of each
  frame. The time of the computer then has no effect on the frames. The clock
  of the page is also fixed, and an action can move it, so the timer of the
  speaker view shows the same time on each run.

  The environment variable `EXPRESSO_CHROMIUM` gives the path of a Chromium
  executable, as it does for the browser tests.
  """

  alias Expresso.Recorder.Frames
  alias PlaywrightEx.{Browser, BrowserContext, Connection, Frame, Page}

  @timeout 30_000

  # The time of the clock of the page at the start of each example.
  @epoch DateTime.to_unix(~U[2026-01-01 09:00:00Z], :millisecond)

  @typedoc "The browser and the browser context of the recorder"
  @type t :: %{browser: map(), context: map()}

  @typedoc """
  A key, such as `"j"`, or a move of the clock of the page by a number of
  milliseconds. The speaker view then shows a later time.
  """
  @type action :: String.t() | {:advance, pos_integer()}

  @typedoc "A PNG image and the time that the GIF shows it, in milliseconds"
  @type frame :: Expresso.Gif.frame()

  @doc """
  Start Playwright and one Chromium for the recorder

  The GIF is 800 by 450 pixels. The slides have the layout of a window of
  1280 by 720 pixels, and the scale of 0.625 makes each frame smaller.
  """
  @spec start() :: t()
  def start do
    # The browser tests start Playwright before they run the task.
    case PlaywrightEx.Supervisor.start_link(
           timeout: @timeout,
           executable: "node_modules/playwright/cli.js"
         ) do
      {:ok, _supervisor} -> :ok
      {:error, {:already_started, _supervisor}} -> :ok
    end

    launch = [timeout: @timeout, headless: true]

    launch =
      case System.get_env("EXPRESSO_CHROMIUM") do
        nil -> launch
        path -> Keyword.put(launch, :executable_path, path)
      end

    {:ok, browser} = PlaywrightEx.launch_browser(:chromium, launch)

    {:ok, context} =
      Browser.new_context(browser.guid,
        timeout: @timeout,
        viewport: %{width: 1280, height: 720},
        device_scale_factor: 0.625,
        reduced_motion: "no-preference"
      )

    %{browser: browser, context: context}
  end

  @doc "Close the browser of the recorder"
  @spec stop(t()) :: :ok
  def stop(recorder) do
    {:ok, _result} = Browser.close(recorder.browser.guid, timeout: @timeout)
    :ok
  end

  @doc """
  Open the address in a new page, do each action, and return the frames

  The first frame shows the page before the actions. Each key adds a frame
  for each step of its animations, then a frame after them. `height` is the
  height of each frame, in the layout of a window of 1280 by 720 pixels. A
  height that is more than the height of the window reaches below the window,
  so a still of the handout view shows several pages.
  """
  @spec record(t(), String.t(), [action()], pos_integer()) :: [frame(), ...]
  def record(recorder, url, actions, height) do
    {:ok, page} = BrowserContext.new_page(recorder.context.guid, timeout: @timeout)

    try do
      fix_clock(recorder, @epoch)
      {:ok, _response} = Frame.goto(page.main_frame.guid, timeout: @timeout, url: url)
      evaluate(page, "async () => { await document.fonts.ready; }")
      # The progress bar can move after the load. The first frame shows its end.
      finish(page)

      first = %{png: shot(page, height), delay: Frames.start()}
      last = length(actions) - 1

      {frames, _now} =
        actions
        |> Enum.with_index()
        |> Enum.flat_map_reduce(@epoch, fn {action, index}, now ->
          {frames, now} = act(recorder, page, height, action, now)
          {frames ++ [%{png: shot(page, height), delay: Frames.hold(index == last)}], now}
        end)

      [first | frames]
    after
      Page.close(page.guid, timeout: @timeout)
    end
  end

  defp act(recorder, page, _height, {:advance, milliseconds}, now) do
    now = now + milliseconds
    advance(recorder, page, now)
    {[], now}
  end

  defp act(_recorder, page, height, key, now) do
    press(page, key)

    frames =
      for time <- Frames.times(started(page)) do
        seek(page, time)
        %{png: shot(page, height), delay: div(1000, Frames.fps())}
      end

    finish(page)
    {frames, now}
  end

  # The picture of the page, from its top.
  defp shot(page, height) do
    {:ok, png} =
      Page.screenshot(page.guid,
        timeout: @timeout,
        type: "png",
        full_page: true,
        clip: %{x: 0, y: 0, width: 1280, height: height}
      )

    Base.decode64!(png)
  end

  defp press(page, key) do
    send!(page, :keyboard_press, %{key: key})
  end

  defp fix_clock(recorder, now) do
    send!(recorder.context, :clock_set_fixed_time, %{time_number: now})
  end

  # The spec of `PlaywrightEx.send/2` takes a message with no parameters, so
  # the recorder sends the message with the connection.
  defp send!(target, method, params) do
    message = %{guid: target.guid, method: method, params: params}

    case Connection.send(PlaywrightEx.Supervisor.Connection, message, @timeout) do
      %{error: error} -> raise "#{method} failed: #{inspect(error)}"
      _response -> :ok
    end
  end

  # Wait for the animations of a key, pause them, and return the time of the
  # longest one in milliseconds. A key with no animation returns 0. The page
  # looks at each animation frame, and it pauses each animation at once, so an
  # animation runs for one frame at most before the pause. The seek then sets
  # the exact time of each frame. The page waits two more frames, because the
  # browser can start a transition of the slide after the transitions of the
  # overlays.
  defp started(page) do
    evaluate(page, """
    async () => {
      const frame = () => new Promise((resolve) => requestAnimationFrame(resolve));
      const pause = () => {
        const all = document.getAnimations();
        for (const animation of all) {
          animation.pause();
        }
        return all;
      };
      let waited = 0;
      while (pause().length === 0) {
        if (waited > 500) {
          return 0;
        }
        const before = performance.now();
        await frame();
        waited += performance.now() - before;
      }
      await frame();
      await frame();
      const ends = pause().map((animation) =>
        Number(animation.effect?.getComputedTiming().endTime ?? 0),
      );
      return Math.max(0, ...ends);
    }
    """)
  end

  # Move each paused animation to a time, and wait for two animation frames,
  # so the compositor paints the new time before the screenshot.
  defp seek(page, time) do
    evaluate(
      page,
      """
      async (time) => {
        for (const animation of document.getAnimations()) {
          animation.currentTime = time;
        }
        for (let count = 0; count < 2; count++) {
          await new Promise((resolve) => requestAnimationFrame(resolve));
        }
      }
      """,
      time
    )
  end

  # Move each animation to its end, and wait until the page has no animation.
  defp finish(page) do
    evaluate(page, """
    () => {
      for (const animation of document.getAnimations()) {
        animation.finish();
      }
    }
    """)

    wait_for(page, "() => document.getAnimations().length === 0", nil)
  end

  # Move the clock of the page, and wait until the timer of the speaker view
  # shows the new time. The timer reads the clock one time each second.
  defp advance(recorder, page, now) do
    before =
      evaluate(page, ~s|() => document.getElementById("speaker-timer")?.textContent ?? null|)

    fix_clock(recorder, now)

    wait_for(
      page,
      ~s|(before) => document.getElementById("speaker-timer")?.textContent !== before|,
      before
    )
  end

  defp evaluate(page, function, arg \\ nil) do
    {:ok, value} =
      Frame.evaluate(page.main_frame.guid,
        timeout: @timeout,
        expression: function,
        is_function: true,
        arg: arg
      )

    value
  end

  defp wait_for(page, function, arg) do
    {:ok, _result} =
      Frame.wait_for_function(page.main_frame.guid,
        timeout: @timeout,
        expression: function,
        is_function: true,
        arg: arg,
        polling: "raf"
      )

    :ok
  end
end
