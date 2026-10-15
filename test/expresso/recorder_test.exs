defmodule Expresso.RecorderTest do
  use ExUnit.Case, async: true

  alias Expresso.Recorder
  alias Expresso.Recorder.RefusedError

  @png Base.encode64("png")

  @refused %{
    error: %{
      message: "Protocol error (Page.captureScreenshot): Unable to capture screenshot",
      name: "Error"
    }
  }

  @timeout %{error: %{message: "Timeout 30000ms exceeded.", name: "TimeoutError"}}

  # An attempt function that does the results of a list in sequence, and a
  # wait function. The test then reads the calls of each one. A result is a
  # value to return, or an exception to raise.
  defp fakes(results) do
    {:ok, agent} = Agent.start_link(fn -> %{results: results, calls: []} end)

    attempt = fn ->
      result =
        Agent.get_and_update(agent, fn %{results: [result | rest]} = state ->
          {result, %{state | results: rest, calls: [:attempt | state.calls]}}
        end)

      if is_exception(result), do: raise(result), else: result
    end

    wait = fn -> Agent.update(agent, &%{&1 | calls: [:wait | &1.calls]}) end
    calls = fn -> agent |> Agent.get(& &1.calls) |> Enum.reverse() end
    {attempt, wait, calls}
  end

  describe "capture/1" do
    test "returns the PNG of the screenshot" do
      assert Recorder.capture(fn -> {:ok, @png} end) == "png"
    end

    test "raises RefusedError when Chromium refuses the screenshot" do
      assert_raise RefusedError, ~r/Unable to capture screenshot/, fn ->
        Recorder.capture(fn -> {:error, @refused} end)
      end
    end

    test "raises a RuntimeError for a different error" do
      assert_raise RuntimeError, ~r/Timeout 30000ms exceeded/, fn ->
        Recorder.capture(fn -> {:error, @timeout} end)
      end
    end
  end

  describe "retry/3" do
    test "returns the result of the first run, and does not wait" do
      {attempt, wait, calls} = fakes([:frames])

      assert Recorder.retry(attempt, wait, 3) == :frames
      assert calls.() == [:attempt]
    end

    test "waits and runs again after a refusal" do
      {attempt, wait, calls} = fakes([%RefusedError{error: @refused}, :frames])

      assert Recorder.retry(attempt, wait, 3) == :frames
      assert calls.() == [:attempt, :wait, :attempt]
    end

    test "raises the refusal of the last run" do
      refused = %RefusedError{error: @refused}
      {attempt, wait, calls} = fakes([refused, refused, refused])

      assert_raise RefusedError, fn -> Recorder.retry(attempt, wait, 3) end
      assert calls.() == [:attempt, :wait, :attempt, :wait, :attempt]
    end

    test "raises a different error at once" do
      {attempt, wait, calls} = fakes([%RuntimeError{message: "the screenshot failed"}])

      assert_raise RuntimeError, fn -> Recorder.retry(attempt, wait, 3) end
      assert calls.() == [:attempt]
    end
  end
end
