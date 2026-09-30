defmodule Expresso.Presenter.Verifier do
  @moduledoc """
  The Spark verifier of a presenter definition

  It runs one time for each module that uses `Expresso.Presenter.Dsl`, when the
  module compiles. It refuses these errors:

    * The option `state` does not hold exactly the fields of
      `Expresso.Presenter.Definition`, or a value has the wrong type.
    * The option `sync` or the option `match` of a mode names an unknown field.
    * Two modes have the same name.
    * A command is not a command of `Expresso.Presenter.Definition`, or it gives
      a field a value of the wrong type.
    * A mode with the option `any` has bindings.
    * One event has two bindings in one mode. The list of keys would then show
      two functions for the event.
    * The event `:element` is in a mode without the option `element`.

  The script in the browser reads the same fields and commands. Without the
  verifier, the script finds such an error only when the presenter uses the
  document.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier

  # The type of each field of the state.
  @fields %{
    index: :index,
    view: :view,
    blank: :boolean,
    help: :boolean,
    digits: :digits,
    overview: :boolean,
    selected: :slide,
    progress: :boolean,
    every: :boolean
  }

  @views [:present, :speaker, :handout]
  @builtins [:open_speaker, :fullscreen, :reset_timer]

  @doc """
  Make sure of the definition of a presenter
  """
  @impl Verifier
  @spec verify(map()) :: :ok | {:error, Spark.Error.DslError.t()}
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    state = Verifier.get_option(dsl_state, [:presenter], :state)
    sync = Verifier.get_option(dsl_state, [:presenter], :sync)
    modes = Verifier.get_entities(dsl_state, [:presenter])

    result =
      with :ok <- state(state),
           :ok <- sync(sync),
           :ok <- names(modes) do
        Enum.reduce_while(modes, :ok, &mode_result/2)
      end

    result(result, module)
  end

  defp mode_result(mode, :ok) do
    case mode(mode) do
      :ok -> {:cont, :ok}
      {:error, message} -> {:halt, {:error, message, mode.name}}
    end
  end

  defp result(:ok, _module), do: :ok

  defp result({:error, message}, module),
    do: {:error, Spark.Error.DslError.exception(module: module, message: message, path: [])}

  defp result({:error, message, mode}, module),
    do:
      {:error,
       Spark.Error.DslError.exception(module: module, message: message, path: [:mode, mode])}

  defp state(state) do
    keys = Keyword.keys(state)

    cond do
      Enum.sort(keys) != Enum.sort(Map.keys(@fields)) ->
        {:error,
         "the state must hold exactly the fields #{inspect(Map.keys(@fields))}, and it holds #{inspect(keys)}"}

      bad = Enum.find(state, fn {field, value} -> not value?(field, value) end) ->
        {field, value} = bad
        {:error, "the field #{field} cannot have the value #{inspect(value)}"}

      true ->
        :ok
    end
  end

  defp sync(sync) do
    case Enum.reject(sync, &Map.has_key?(@fields, &1)) do
      [] -> :ok
      unknown -> {:error, "the option sync names the unknown fields #{inspect(unknown)}"}
    end
  end

  defp names(modes) do
    case modes |> Enum.map(& &1.name) |> duplicates() do
      [] -> :ok
      [name | _names] -> {:error, "two modes have the name #{inspect(name)}"}
    end
  end

  defp mode(mode) do
    commands = List.flatten([mode.each, mode.any || [] | Enum.map(mode.bindings, & &1.commands)])

    with :ok <- match(mode.match),
         :ok <- commands(commands),
         :ok <- any(mode),
         :ok <- events(mode) do
      element(mode)
    end
  end

  defp match(match) do
    case Enum.find(match, fn {field, value} -> not value?(field, value) end) do
      nil -> :ok
      {field, value} -> {:error, "the condition #{field}: #{inspect(value)} is not valid"}
    end
  end

  defp commands(commands) do
    case Enum.find(commands, &(not command?(&1))) do
      nil -> :ok
      command -> {:error, "#{inspect(command)} is not a valid command"}
    end
  end

  defp any(%{any: any, bindings: [_ | _]}) when is_list(any),
    do: {:error, "a mode with the option any cannot have bindings"}

  defp any(_mode), do: :ok

  defp events(mode) do
    case mode.bindings |> Enum.flat_map(& &1.on) |> duplicates() do
      [] -> :ok
      [event | _events] -> {:error, "the event #{inspect(event)} has two bindings"}
    end
  end

  defp element(%{element: true}), do: :ok

  defp element(mode) do
    if Enum.any?(mode.bindings, &(:element in &1.on)),
      do: {:error, "the event :element needs the option element: true"},
      else: :ok
  end

  defp duplicates(items),
    do: items |> Enum.frequencies() |> Enum.filter(&(elem(&1, 1) > 1)) |> Enum.map(&elem(&1, 0))

  defp value?(field, value), do: Map.has_key?(@fields, field) and type?(@fields[field], value)

  defp type?(:index, value), do: is_integer(value) and value >= 0
  defp type?(:slide, value), do: is_integer(value) and value >= 1
  defp type?(:view, value), do: value in @views
  defp type?(:boolean, value), do: is_boolean(value)
  defp type?(:digits, value), do: is_binary(value) and String.match?(value, ~r/^[0-9]*$/)

  defp command?({:set, field, value}), do: value?(field, value)
  defp command?({:toggle, field}), do: @fields[field] == :boolean
  defp command?({:clear, field}), do: Map.has_key?(@fields, field)
  defp command?({:assign, :selected, {:entry, :slide}}), do: true
  defp command?({:append, :digits}), do: true
  defp command?({:step, count}), do: is_integer(count)
  defp command?({:goto, :last_slide}), do: true
  defp command?({:goto, index}), do: type?(:index, index)
  defp command?({:goto_slide, :selected}), do: true
  defp command?({:goto_slide, slide}), do: type?(:slide, slide)
  defp command?({:select, :last_slide}), do: true
  defp command?({:select, slide}), do: type?(:slide, slide)
  defp command?({:select_by, {:columns, sign}}), do: sign in [1, -1]
  defp command?({:select_by, count}), do: is_integer(count)
  defp command?(:go_typed), do: true
  defp command?({:builtin, name}), do: name in @builtins
  defp command?(_command), do: false
end
