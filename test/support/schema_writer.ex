defmodule Expresso.Test.SchemaWriter do
  @moduledoc """
  Writes `assets/src/schema.ts` from the forms of `Expresso.Presenter.Schema`

  The file holds three things for each form:

    * a TypeScript type with the name of the form, such as `WrittenProgram`;
    * for a form of strings, a constant with each string, such as `VIEWS`;
    * a decoder from the functions of `assets/src/decode.ts`, such as
      `decodeWrittenProgram`.

  The test `Expresso.Presenter.SchemaTest` fails when the file does not agree
  with `typescript/0`. This command writes the file again:

      EXPRESSO_SCHEMA=write mix test test/expresso/presenter/schema_test.exs

  Prettier does not format the file, because this module writes it. Each call
  of a function of `decode.ts` has the annotation `@__PURE__`, so esbuild keeps
  in the bundle only the decoders that the script uses.
  """

  alias Expresso.Presenter.Schema

  @path "assets/src/schema.ts"

  @doc "Return the path of the file"
  @spec path() :: Path.t()
  def path, do: @path

  @doc "Return the text of the file"
  @spec typescript() :: String.t()
  def typescript do
    forms = Schema.types()

    Enum.join([header() | Enum.map(forms, &form/1)], "\n")
  end

  defp header do
    """
    // The types and the decoders of the values that Elixir writes for the script.
    //
    // `Expresso.Test.SchemaWriter` writes this file from the forms of
    // `Expresso.Presenter.Schema`. Do not change it by hand. After a change of a
    // form, write the file again:
    //
    //     EXPRESSO_SCHEMA=write mix test test/expresso/presenter/schema_test.exs

    import {
      boolean,
      integer,
      list,
      literal,
      nullable,
      number,
      object,
      oneOf,
      openObject,
      partial,
      string,
      tuple,
      union,
    } from "./decode.ts";
    import type { Decoder } from "./decode.ts";
    """
  end

  defp form({name, doc, {:enum, values}}) do
    """
    #{comment(doc)}
    export type #{type_name(name)} = #{Enum.map_join(values, " | ", &JSON.encode!/1)};
    export const #{constant(name)}: readonly #{type_name(name)}[] = [#{Enum.map_join(values, ", ", &JSON.encode!/1)}];
    export const #{decoder(name)}: Decoder<#{type_name(name)}> = #{call("oneOf", constant(name))};
    """
  end

  defp form({name, doc, {:union, types}}) do
    """
    #{comment(doc)}
    export type #{type_name(name)} =
    #{Enum.map_join(types, "\n", &("  | " <> ts(&1, 1)))};
    export const #{decoder(name)}: Decoder<#{type_name(name)}> = /* @__PURE__ */ union(
      #{JSON.encode!(Atom.to_string(name))},
    #{Enum.map_join(types, "\n", &("  " <> decode(&1, 1) <> ","))}
    );
    """
  end

  defp form({name, doc, type}) do
    """
    #{comment(doc)}
    export type #{type_name(name)} = #{ts(type, 0)};
    export const #{decoder(name)}: Decoder<#{type_name(name)}> = #{decode(type, 0)};
    """
  end

  # The TypeScript type of a form. An object puts each field on its own line,
  # one level deeper than `depth`.
  defp ts(:boolean, _depth), do: "boolean"
  defp ts(:string, _depth), do: "string"
  defp ts({:string, _pattern}, _depth), do: "string"
  defp ts({:integer, _min}, _depth), do: "number"
  defp ts({:number, _min, _max}, _depth), do: "number"
  defp ts({:literal, value}, _depth), do: JSON.encode!(value)
  defp ts({:enum, values}, _depth), do: Enum.map_join(values, " | ", &JSON.encode!/1)
  defp ts({:nullable, type}, depth), do: ts(type, depth) <> " | null"
  defp ts({:list, type}, depth), do: "readonly " <> element(ts(type, depth)) <> "[]"
  defp ts({:tuple, types}, depth), do: "readonly [#{Enum.map_join(types, ", ", &ts(&1, depth))}]"
  defp ts({:object, fields}, depth), do: shape(fields, "", depth)
  defp ts({:open_object, fields}, depth), do: shape(fields, "", depth)
  defp ts({:partial, fields}, depth), do: shape(fields, "?", depth)
  defp ts({:union, types}, depth), do: Enum.map_join(types, " | ", &ts(&1, depth))
  defp ts({:ref, name}, _depth), do: type_name(name)

  # A type with a space needs parentheses in front of `[]`.
  defp element(type), do: if(String.contains?(type, " "), do: "(#{type})", else: type)

  defp shape(fields, optional, depth) do
    lines =
      Enum.map(fields, fn {key, type} ->
        indent(depth + 1) <> "#{key}#{optional}: #{ts(type, depth + 1)};"
      end)

    "Readonly<{\n" <> Enum.join(lines, "\n") <> "\n" <> indent(depth) <> "}>"
  end

  # The decoder of a form. An object puts each field on its own line, one level
  # deeper than `depth`.
  defp decode(:boolean, _depth), do: "boolean"
  defp decode(:string, _depth), do: call("string", "")

  defp decode({:string, pattern}, _depth),
    do: call("string", "/#{String.replace(pattern, "/", "\\/")}/")

  defp decode({:integer, nil}, _depth), do: call("integer", "")
  defp decode({:integer, min}, _depth), do: call("integer", "#{min}")
  defp decode({:number, nil, nil}, _depth), do: call("number", "")
  defp decode({:number, min, max}, _depth), do: call("number", "#{bound(min)}, #{bound(max)}")
  defp decode({:literal, value}, _depth), do: call("literal", JSON.encode!(value))

  defp decode({:enum, values}, _depth),
    do: call("oneOf", "[#{Enum.map_join(values, ", ", &JSON.encode!/1)}]")

  defp decode({:nullable, type}, depth), do: call("nullable", decode(type, depth))
  defp decode({:list, type}, depth), do: call("list", decode(type, depth))

  defp decode({:tuple, types}, depth),
    do: call("tuple", Enum.map_join(types, ", ", &decode(&1, depth)))

  defp decode({:object, fields}, depth), do: call("object", fields(fields, depth))
  defp decode({:open_object, fields}, depth), do: call("openObject", fields(fields, depth))
  defp decode({:partial, fields}, depth), do: call("partial", fields(fields, depth))

  defp decode({:union, types} = type, depth) do
    name = JSON.encode!(ts(type, depth))
    call("union", "#{name}, #{Enum.map_join(types, ", ", &decode(&1, depth))}")
  end

  defp decode({:ref, name}, _depth), do: decoder(name)

  defp fields(fields, depth) do
    lines =
      Enum.map(fields, fn {key, type} ->
        indent(depth + 1) <> "#{key}: #{decode(type, depth + 1)},"
      end)

    "{\n" <> Enum.join(lines, "\n") <> "\n" <> indent(depth) <> "}"
  end

  defp indent(depth), do: String.duplicate("  ", depth)

  # A call of a function of `decode.ts`. esbuild removes a call with the
  # annotation when the bundle does not use its result.
  defp call(function, arguments), do: "/* @__PURE__ */ #{function}(#{arguments})"

  defp bound(nil), do: "undefined"
  defp bound(value), do: to_string(value)

  defp comment(doc) do
    doc
    |> String.split(" ")
    |> Enum.chunk_while(
      "//",
      fn word, line ->
        if String.length(line) + 1 + String.length(word) > 80,
          do: {:cont, line, "// " <> word},
          else: {:cont, line <> " " <> word}
      end,
      &{:cont, &1, nil}
    )
    |> Enum.join("\n")
  end

  defp type_name(name), do: Macro.camelize(Atom.to_string(name))
  defp decoder(name), do: "decode" <> type_name(name)
  defp constant(name), do: String.upcase(Atom.to_string(name)) <> "S"
end
