defmodule Expresso.Presenter.Schema.Check do
  @moduledoc """
  Makes sure that a JSON value agrees with a form of `Expresso.Presenter.Schema`

  `check/2` examines a decoded JSON value with the same forms as the decoders
  of `assets/src/schema.ts`. `Expresso.Presenter.Verifier` uses it for the
  values of a definition, and the tests use it for each value that the
  renderer writes. An error holds the path of the value, such as
  `$.modes[2].keys`, and the form that the value does not agree with.

  A pattern has the meaning of a JavaScript regular expression: `$` matches
  only at the end of the string, and not in front of a last newline.
  """

  alias Expresso.Presenter.Schema

  @forms Map.new(Schema.types(), fn {name, _doc, form} -> {name, form} end)

  @doc """
  Make sure that a decoded JSON value agrees with a form, or with the form of a name

      iex> Expresso.Presenter.Schema.Check.check("12", {:string, "^[0-9]*$"})
      :ok

      iex> Expresso.Presenter.Schema.Check.check("12\\n", {:string, "^[0-9]*$"})
      {:error, ~s($: expected {:string, "^[0-9]*$"})}
  """
  @spec check(term(), atom() | Schema.type()) :: :ok | {:error, String.t()}
  def check(value, name) when is_atom(name) and name not in [:boolean, :string],
    do: check(value, {:ref, name})

  def check(value, type) do
    at(value, type, "$")
  catch
    {:invalid, path, expected} -> {:error, "#{path}: expected #{expected}"}
  end

  defp at(value, type, path) do
    if valid?(value, type, path), do: :ok, else: throw({:invalid, path, describe(type)})
  end

  defp valid?(value, :boolean, _path), do: is_boolean(value)
  defp valid?(value, :string, _path), do: is_binary(value)

  defp valid?(value, {:string, pattern}, _path),
    do: is_binary(value) and :re.run(value, regex(pattern), capture: :none) == :match

  defp valid?(value, {:integer, min}, _path),
    do: is_integer(value) and (min == nil or value >= min)

  defp valid?(value, {:number, min, max}, _path),
    do: is_number(value) and (min == nil or value >= min) and (max == nil or value <= max)

  defp valid?(value, {:literal, literal}, _path), do: value === literal
  defp valid?(value, {:enum, values}, _path), do: value in values
  defp valid?(nil, {:nullable, _type}, _path), do: true
  defp valid?(value, {:nullable, type}, path), do: valid?(value, type, path)

  defp valid?(value, {:list, type}, path) when is_list(value) do
    value
    |> Enum.with_index()
    |> Enum.each(fn {each, i} -> at(each, type, "#{path}[#{i}]") end)

    true
  end

  defp valid?(value, {:tuple, types}, path)
       when is_list(value) and length(value) == length(types) do
    value
    |> Enum.zip(types)
    |> Enum.with_index()
    |> Enum.each(fn {{each, type}, i} -> at(each, type, "#{path}[#{i}]") end)

    true
  end

  defp valid?(value, {kind, fields}, path)
       when is_map(value) and kind in [:object, :open_object, :partial] do
    keys = Enum.map(fields, fn {key, _type} -> Atom.to_string(key) end)
    extra = Map.keys(value) -- keys
    missing = keys -- Map.keys(value)

    cond do
      kind != :open_object and extra != [] ->
        throw({:invalid, "#{path}.#{hd(extra)}", "no such key"})

      kind != :partial and missing != [] ->
        throw({:invalid, "#{path}.#{hd(missing)}", "a value"})

      true ->
        for {key, type} <- fields, Map.has_key?(value, Atom.to_string(key)) do
          at(Map.fetch!(value, Atom.to_string(key)), type, "#{path}.#{key}")
        end

        true
    end
  end

  defp valid?(value, {:union, types}, path), do: Enum.any?(types, &(one(value, &1, path) == :ok))
  defp valid?(value, {:ref, name}, path), do: valid?(value, Map.fetch!(@forms, name), path)
  defp valid?(_value, _type, _path), do: false

  defp one(value, type, path) do
    at(value, type, path)
  catch
    {:invalid, _path, _expected} -> :error
  end

  # Each pattern compiles one time in the VM. A compiled regular expression
  # cannot go into a module attribute.
  defp regex(pattern) do
    key = {__MODULE__, pattern}

    case :persistent_term.get(key, nil) do
      nil ->
        {:ok, compiled} = :re.compile(pattern, [:unicode, :dollar_endonly])
        :persistent_term.put(key, compiled)
        compiled

      compiled ->
        compiled
    end
  end

  defp describe({:ref, name}), do: Atom.to_string(name)
  defp describe({:union, _types}), do: "one of the forms of a union"
  defp describe(type), do: inspect(type)
end
