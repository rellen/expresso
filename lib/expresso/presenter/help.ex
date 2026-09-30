defmodule Expresso.Presenter.Help do
  @moduledoc """
  Makes the list of keys of each mode from the definition of the presenter

  The key `?` shows the list. The renderer writes one list for each mode that
  has bindings, and the script shows the list of the mode under the list of
  keys. Each row holds the names of the keys, or the label of a binding, and
  the text of the binding.
  """

  alias Expresso.Presenter.Definition

  # The names that the list shows for some values of `KeyboardEvent.key`. Each
  # other key shows its value.
  @names %{
    " " => "Space",
    "ArrowRight" => "→",
    "ArrowLeft" => "←",
    "ArrowUp" => "↑",
    "ArrowDown" => "↓",
    "PageDown" => "Page Down",
    "PageUp" => "Page Up",
    "Escape" => "Esc"
  }

  @doc """
  Return the rows of the list of each mode that has bindings

  The modes and the rows come in the order of the definition.

      iex> [{:overview, [first | _rows]} | _modes] =
      ...>   Expresso.Presenter.Help.rows(Expresso.Presenter.Definition.presenter())
      iex> first
      {"?", "This list of keys. The next key closes it."}
  """
  @spec rows(Definition.t()) :: [{atom(), [{String.t(), String.t()}]}]
  def rows(definition) do
    for %{bindings: [_ | _] = bindings, name: name} <- definition.modes do
      {name, Enum.map(bindings, &{names(&1), &1.text})}
    end
  end

  @doc """
  Return the names of the keys of a binding, such as `"j, →, ↓, Page Down, Space"`

  A binding with a label returns its label.
  """
  @spec names(Definition.binding()) :: String.t()
  def names(%{label: label}) when is_binary(label), do: label

  def names(binding) do
    binding.on
    |> Enum.flat_map(fn
      {:key, key} -> [Map.get(@names, key, key)]
      _event -> []
    end)
    |> Enum.join(", ")
  end
end
