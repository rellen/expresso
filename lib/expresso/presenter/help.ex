defmodule Expresso.Presenter.Help do
  @moduledoc """
  Makes the list of keys of each mode from the definition of the presenter

  The key `?` or `/` shows the list. The renderer writes one section for each
  mode that has bindings, and the script opens the section of the mode under
  the list of keys. Each row holds the names of the keys, or the label of a
  binding, and the text of the binding. The `group` option of a binding gives
  the heading of its row. `rows/1` gives the rows of the tables of the README,
  and `groups/1` gives the rows of the document.
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
      {"?, /", "The search of the keys and commands. Esc closes it."}
  """
  @spec rows(Definition.t()) :: [{atom(), [{String.t(), String.t()}]}]
  def rows(definition) do
    for %{bindings: [_ | _] = bindings, name: name} <- definition.modes do
      {name, Enum.map(bindings, &{names(&1), &1.text})}
    end
  end

  @typedoc "A row of the list of keys in the document"
  @type row :: %{keys: [String.t()], label: String.t() | nil, text: String.t(), words: String.t()}

  @doc """
  Return the rows of each mode that has bindings, in groups

  A group is its heading and its rows, in the order of the first binding of
  the group. A binding with no group goes into a group with the heading
  `nil`. The words of a row are the names of its keys, its label and its text
  in lower case, and the filter of the list looks for the text in them.

      iex> [{:overview, [{nil, [first | _rows]}]} | _modes] =
      ...>   Expresso.Presenter.Help.groups(Expresso.Presenter.Definition.presenter())
      iex> first.keys
      ["?", "/"]
  """
  @spec groups(Definition.t()) :: [{atom(), [{String.t() | nil, [row()]}]}]
  def groups(definition) do
    for %{bindings: [_ | _] = bindings, name: name} <- definition.modes do
      rows = Enum.group_by(bindings, & &1.group, &row/1)
      order = bindings |> Enum.map(& &1.group) |> Enum.uniq()
      {name, for(group <- order, do: {group, rows[group]})}
    end
  end

  defp row(binding) do
    keys = keys(binding)

    %{
      keys: keys,
      label: binding.label,
      text: binding.text,
      words:
        [keys, binding.label || [], binding.text]
        |> List.flatten()
        |> Enum.join(" ")
        |> String.downcase()
    }
  end

  @doc """
  Return the name of a mode in the list of keys, such as `"Present view"`

      iex> Expresso.Presenter.Help.title(:overview)
      "Overview"
  """
  @spec title(atom()) :: String.t()
  def title(:present), do: "Present view"
  def title(:speaker), do: "Speaker view"
  def title(:handout), do: "Handout view"
  def title(mode), do: mode |> Atom.to_string() |> String.capitalize()

  @doc """
  Return the names of the keys of a binding, such as `"j, →, ↓, Page Down, Space"`

  A binding with a label returns its label.
  """
  @spec names(Definition.binding()) :: String.t()
  def names(%{label: label}) when is_binary(label), do: label
  def names(binding), do: binding |> keys() |> Enum.join(", ")

  @doc """
  Return the name of each key of a binding, such as `["j", "→", "↓", "Page Down", "Space"]`

  An event that is not a key has no name.
  """
  @spec keys(Definition.binding()) :: [String.t()]
  def keys(binding) do
    Enum.flat_map(binding.on, fn
      {:key, key} -> [Map.get(@names, key, key)]
      _event -> []
    end)
  end
end
