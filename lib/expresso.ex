defmodule Expresso do
  @moduledoc """
  Documentation for `Expresso`.
  """

  @doc """
  present a deck
  """
  @spec present() :: no_return
  def present() do
    raise "not implemented"
  end

  @doc """
  Load all the deck and slide templates
  """
  @spec load_templates() :: :ok
  def load_templates() do
    templates = Path.wildcard("./priv/templates/{decks,slides}/*.exs")

    Kernel.ParallelCompiler.compile(templates)

    :ok
  end
end
