defmodule Expresso.Test.PrivateDir do
  @moduledoc """
  Waits for the `sh` process of `Expresso.PrivateDir` in a test

  The async tests of the full suite make the VM slow. In one run `open!/1`
  took more than five seconds, because the start of an operating system
  process stopped for some seconds. Thus a test that starts a private
  directory, or waits for its removal, waits for up to 30 seconds.
  """

  import ExUnit.Assertions

  # The time in milliseconds that a test waits.
  @wait 30_000

  # The time in milliseconds between two looks at the directory.
  @interval 500

  @doc """
  The time in milliseconds that a test waits for a process that opens a
  private directory
  """
  @spec wait() :: pos_integer()
  def wait, do: @wait

  @doc """
  Wait until the directory goes away, and fail the test after 30 seconds
  """
  @spec wait_for_removal(Path.t()) :: :ok
  def wait_for_removal(path), do: wait_for_removal(path, div(@wait, @interval))

  defp wait_for_removal(path, tries) do
    cond do
      not File.exists?(path) -> :ok
      tries == 0 -> flunk("#{path} is still there")
      true -> wait_again(path, tries)
    end
  end

  defp wait_again(path, tries) do
    Process.sleep(@interval)
    wait_for_removal(path, tries - 1)
  end
end
