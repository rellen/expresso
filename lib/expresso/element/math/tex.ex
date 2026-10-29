defmodule Expresso.Element.Math.Tex do
  @moduledoc """
  Makes the MathML of formulas in LaTeX with Temml

  [Temml](https://temml.org) is a library in JavaScript, so `render!/2` runs
  Node with the script `priv/temml/render.mjs`, through
  `Expresso.Element.Diagram.Tool`. The project holds a copy of `temml.mjs`
  and its license in `priv/temml/`, so a render needs Node and no package of
  npm. `EXPRESSO_NODE` gives the path of Node, as for a diagram of Mermaid.
  `version/0` gives the version of the copy.

  One run of Node makes the MathML of each source of a list, so a deck starts
  Node one time. Temml makes a formula in display mode, and it trusts `\\class`
  and `\\data` only, because the parts of a formula use them. It refuses each
  other command that writes an attribute or reads a file, such as
  `\\includegraphics`. The macros `\\part` and `\\id` give a name to a part.
  `docs/math-parts.md` gives the design.
  """

  alias Expresso.Element.Diagram.Tool

  @tool %{
    name: "Node",
    program: "node",
    variable: "EXPRESSO_NODE",
    install: "https://nodejs.org"
  }

  # The version of the copy of `temml.mjs` in `priv/temml/`. A test compares it
  # with the version in `package.json`.
  @version "0.14.0"

  @typedoc "The result for one source: its MathML, or the message of Temml"
  @type result :: {:ok, String.t()} | {:error, String.t()}

  @doc "The tool, for `Expresso.Element.Diagram.Tool`"
  @spec tool() :: Tool.t()
  def tool, do: @tool

  @doc "The version of the copy of Temml"
  @spec version() :: String.t()
  def version, do: @version

  @doc "The path of the script that runs Temml"
  @spec script() :: Path.t()
  def script, do: Application.app_dir(:expresso, "priv/temml/render.mjs")

  @doc """
  Make the MathML of each source, in one run of Node

  The function returns one result for each source, in the same order: the
  MathML of a source that Temml reads, or the message of Temml for a source
  that it cannot read. An empty list needs no Node. The function raises an
  `ArgumentError` when Node is not present, and when the script fails.
  """
  @spec render!([String.t()]) :: [result()]
  def render!([]), do: []

  def render!(sources) do
    files = [{"sources.json", JSON.encode!(sources)}]
    command = fn dir -> {[script(), dir], []} end

    @tool
    |> Tool.run!({:subject, "the formulas of the deck"}, command, files, "mathml.json")
    |> JSON.decode!()
    |> Enum.map(&result/1)
  end

  defp result(%{"mathml" => mathml}), do: {:ok, mathml}
  defp result(%{"error" => message}), do: {:error, message}
end
