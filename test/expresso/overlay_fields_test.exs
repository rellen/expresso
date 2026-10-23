defmodule Expresso.OverlayFieldsTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.{Lines, On, TocEntry}
  alias Expresso.Overlay

  # The overlay options of the DSL. The fields `steps` and `el` have no
  # option, because the transformer and the renderer write them, and `on` is a
  # child entity.
  @options [:at, :effect, :speed, :easing, :morph]

  # Each entity of the tree of the DSL, with the copies of a recursive entity.
  defp descendants(entities) do
    Enum.flat_map(entities, fn entity ->
      [entity | entity.entities |> Keyword.values() |> List.flatten() |> descendants()]
    end)
  end

  # The entities of the elements: each entity with the `at` option, except the
  # `on` entity, which is not an element.
  defp entities do
    [section] = Expresso.Extension.sections()

    section.entities
    |> descendants()
    |> Enum.uniq_by(& &1.name)
    |> Enum.filter(&(Keyword.has_key?(&1.schema, :at) and &1.target != On))
  end

  defp fields(module), do: module.__struct__() |> Map.from_struct() |> Map.keys()

  defp overlay_fields do
    Enum.map(Overlay.fields(), fn
      {key, _default} -> key
      key -> key
    end)
  end

  test "each element entity has the overlay options and an on child" do
    assert length(entities()) == 30

    for entity <- entities() do
      assert @options -- Keyword.keys(entity.schema) == [], inspect(entity.name)

      assert [%Spark.Dsl.Entity{target: On}] = List.wrap(entity.entities[:on]),
             "#{inspect(entity.name)} has no on child"
    end
  end

  # Lines and TocEntry are not entities of the DSL. The code element and the
  # section transformer make them.
  test "the struct of each element has the overlay fields" do
    structs = Enum.map(entities(), & &1.target) ++ [Lines, TocEntry]

    assert length(structs) == 32

    for module <- structs do
      assert overlay_fields() -- fields(module) == [], inspect(module)
      assert struct(module).on == [], inspect(module)
    end
  end
end
