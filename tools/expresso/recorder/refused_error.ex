defmodule Expresso.Recorder.RefusedError do
  @moduledoc """
  The error when Chromium refuses a screenshot

  Chromium can answer a screenshot with the message `Unable to capture
  screenshot`. `Expresso.Recorder.record/4` then records the example again in
  a new page.
  """

  defexception [:error]

  @typedoc "The exception, with the error that Playwright returned"
  @type t :: %__MODULE__{error: term()}

  @impl true
  def message(%__MODULE__{error: error}), do: "Chromium refused the screenshot: #{inspect(error)}"
end
