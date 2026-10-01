defmodule Expresso.Test.SchemaCheck do
  @moduledoc """
  Makes sure that a JSON value agrees with a form of `Expresso.Presenter.Schema`

  The tests decode the JSON that the renderer writes, and `check/2` examines
  the result with the same forms as the decoders of `assets/src/schema.ts`. An
  error holds the path of the value, such as `$.modes[2].keys`, and the form
  that the value does not agree with.
  """

  alias Expresso.Presenter.Schema

  @doc "Make sure that a decoded JSON value agrees with a form, or with the form of a name"
  @spec check(term(), atom() | Schema.type()) :: :ok | {:error, String.t()}
  def check(value, name) when is_atom(name) and name not in [:boolean, :string],
    do: check(value, {:ref, name})

  def check(value, type) do
    forms = Map.new(Schema.types(), fn {name, _doc, form} -> {name, form} end)
    at(value, type, "$", forms)
  catch
    {:invalid, path, expected} -> {:error, "#{path}: expected #{expected}"}
  end

  defp at(value, type, path, forms) do
    if valid?(value, type, path, forms), do: :ok, else: throw({:invalid, path, describe(type)})
  end

  defp valid?(value, :boolean, _path, _forms), do: is_boolean(value)
  defp valid?(value, :string, _path, _forms), do: is_binary(value)

  defp valid?(value, {:string, pattern}, _path, _forms),
    do: is_binary(value) and Regex.match?(Regex.compile!(pattern), value)

  defp valid?(value, {:integer, min}, _path, _forms),
    do: is_integer(value) and (min == nil or value >= min)

  defp valid?(value, {:number, min, max}, _path, _forms),
    do: is_number(value) and (min == nil or value >= min) and (max == nil or value <= max)

  defp valid?(value, {:literal, literal}, _path, _forms), do: value === literal
  defp valid?(value, {:enum, values}, _path, _forms), do: value in values
  defp valid?(nil, {:nullable, _type}, _path, _forms), do: true
  defp valid?(value, {:nullable, type}, path, forms), do: valid?(value, type, path, forms)

  defp valid?(value, {:list, type}, path, forms) when is_list(value) do
    value
    |> Enum.with_index()
    |> Enum.each(fn {each, i} -> at(each, type, "#{path}[#{i}]", forms) end)

    true
  end

  defp valid?(value, {:tuple, types}, path, forms)
       when is_list(value) and length(value) == length(types) do
    value
    |> Enum.zip(types)
    |> Enum.with_index()
    |> Enum.each(fn {{each, type}, i} -> at(each, type, "#{path}[#{i}]", forms) end)

    true
  end

  defp valid?(value, {kind, fields}, path, forms)
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
          at(Map.fetch!(value, Atom.to_string(key)), type, "#{path}.#{key}", forms)
        end

        true
    end
  end

  defp valid?(value, {:union, types}, path, forms),
    do: Enum.any?(types, &(check_one(value, &1, path, forms) == :ok))

  defp valid?(value, {:ref, name}, path, forms),
    do: valid?(value, Map.fetch!(forms, name), path, forms)

  defp valid?(_value, _type, _path, _forms), do: false

  defp check_one(value, type, path, forms) do
    at(value, type, path, forms)
  catch
    {:invalid, _path, _expected} -> :error
  end

  defp describe({:ref, name}), do: Atom.to_string(name)
  defp describe({:union, _types}), do: "one of the forms of a union"
  defp describe(type), do: inspect(type)
end
