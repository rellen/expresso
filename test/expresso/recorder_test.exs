defmodule Expresso.RecorderTest do
  use ExUnit.Case, async: true

  alias Expresso.Recorder

  @png Base.encode64("png")

  @refused %{
    error: %{
      message: "Protocol error (Page.captureScreenshot): Unable to capture screenshot",
      name: "Error"
    }
  }

  # A screenshot function that returns the results of a list in sequence, and
  # a wait function. The test then reads the calls of each one.
  defp fakes(results) do
    {:ok, agent} = Agent.start_link(fn -> %{results: results, calls: []} end)

    screenshot = fn ->
      Agent.get_and_update(agent, fn %{results: [result | rest]} = state ->
        {result, %{state | results: rest, calls: [:screenshot | state.calls]}}
      end)
    end

    wait = fn -> Agent.update(agent, &%{&1 | calls: [:wait | &1.calls]}) end
    calls = fn -> agent |> Agent.get(& &1.calls) |> Enum.reverse() end
    {screenshot, wait, calls}
  end

  describe "capture/2" do
    test "returns the PNG of the first screenshot, and does not wait" do
      {screenshot, wait, calls} = fakes([{:ok, @png}])

      assert Recorder.capture(screenshot, wait) == "png"
      assert calls.() == [:screenshot]
    end

    test "waits and takes the screenshot again after Chromium refuses it" do
      {screenshot, wait, calls} = fakes([{:error, @refused}, {:ok, @png}])

      assert Recorder.capture(screenshot, wait) == "png"
      assert calls.() == [:screenshot, :wait, :screenshot]
    end

    test "raises when Chromium refuses the screenshot two times" do
      {screenshot, wait, calls} = fakes([{:error, @refused}, {:error, @refused}])

      assert_raise RuntimeError, ~r/Unable to capture screenshot/, fn ->
        Recorder.capture(screenshot, wait)
      end

      assert calls.() == [:screenshot, :wait, :screenshot]
    end

    test "raises at once for a different error" do
      error = %{error: %{message: "Timeout 30000ms exceeded.", name: "TimeoutError"}}
      {screenshot, wait, calls} = fakes([{:error, error}])

      assert_raise RuntimeError, ~r/Timeout 30000ms exceeded/, fn ->
        Recorder.capture(screenshot, wait)
      end

      assert calls.() == [:screenshot]
    end
  end
end
