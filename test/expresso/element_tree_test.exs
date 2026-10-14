defmodule Expresso.ElementTreeTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.{Callout, Column, Columns, Pause, TextArea, TextBox, Tree}

  doctest Tree

  # A text box with a text, a pause and two columns, then a callout with
  # `nil` as its children. The names give the document order.
  defp tree do
    [
      %TextBox{
        class: "a",
        elements: [
          %TextArea{text: "b"},
          %Pause{},
          %Columns{
            class: "c",
            elements: [
              %Column{class: "d", elements: [%TextArea{text: "e"}]},
              %Column{class: "f", elements: []}
            ]
          }
        ]
      },
      %Callout{class: "g", elements: nil}
    ]
  end

  @order ["a", "b", "pause", "c", "d", "e", "f", "g"]

  defp name(%TextArea{text: text}), do: text
  defp name(%Pause{}), do: "pause"
  defp name(%{class: class}), do: class

  defp names(elements), do: elements |> Tree.descendants() |> Enum.map(&name/1)

  defp upcase(%TextArea{text: text} = text_area),
    do: %TextArea{text_area | text: String.upcase(text)}

  defp upcase(element), do: element

  defp number(%TextArea{} = text_area, count),
    do: {%TextArea{text_area | text: "#{count}"}, count + 1}

  defp number(element, count), do: {element, count}

  # A function that records the name of each element that it gets.
  defp recorder do
    {:ok, agent} = Agent.start_link(fn -> [] end)
    record = fn element -> Agent.update(agent, &[name(element) | &1]) end
    visited = fn -> agent |> Agent.get(& &1) |> Enum.reverse() end
    {record, visited}
  end

  describe "children/1" do
    test "returns the children, and an empty list for nil and for an element without the key" do
      [text_box, callout] = tree()

      assert length(Tree.children(text_box)) == 3
      assert Tree.children(callout) == []
      assert Tree.children(%Pause{}) == []
    end
  end

  describe "descendants/1" do
    test "returns each element in document order, with the pause" do
      assert names(tree()) == @order
    end

    test "returns an empty list for nil" do
      assert Tree.descendants(nil) == []
    end
  end

  describe "map/2" do
    test "changes each element in document order, and keeps the shape of the tree" do
      {record, visited} = recorder()

      mapped =
        Tree.map(tree(), fn element ->
          record.(element)
          upcase(element)
        end)

      assert visited.() == @order
      assert names(mapped) == ["a", "B", "pause", "c", "d", "E", "f", "g"]
    end

    test "walks the children of the element that the function returns" do
      fun = fn
        %TextBox{} = box -> %TextBox{box | elements: [%TextArea{text: "x"}]}
        element -> upcase(element)
      end

      assert names(Tree.map([%TextBox{class: "a"}], fun)) == ["a", "X"]
    end

    test "gives an empty list in place of nil children, and keeps a pause without the key" do
      mapped = Tree.map(tree(), & &1)

      assert List.last(mapped).elements == []
      assert %Pause{} = Enum.find(Tree.descendants(mapped), &is_struct(&1, Pause))

      refute Enum.any?(
               Tree.descendants(mapped),
               &(is_map_key(&1, :elements) and &1.elements == nil)
             )

      assert Tree.map(nil, & &1) == []
    end
  end

  describe "map_reduce/3" do
    test "carries the value through the elements in document order" do
      {mapped, count} = Tree.map_reduce(tree(), 0, &number/2)

      assert count == 2
      assert names(mapped) == ["a", "0", "pause", "c", "d", "1", "f", "g"]
    end
  end

  describe "map_deck/2 and map_reduce_deck/3" do
    defp deck, do: %{slides: [%{elements: tree()}, %{elements: [%TextArea{text: "h"}]}]}

    test "map_deck/2 changes the elements of each slide" do
      %{slides: [first, second]} = Tree.map_deck(deck(), &upcase/1)

      assert names(first.elements) == ["a", "B", "pause", "c", "d", "E", "f", "g"]
      assert names(second.elements) == ["H"]
    end

    test "map_reduce_deck/3 carries the value from one slide to the next" do
      {%{slides: [first, second]}, count} = Tree.map_reduce_deck(deck(), 0, &number/2)

      assert count == 3
      assert names(first.elements) == ["a", "0", "pause", "c", "d", "1", "f", "g"]
      assert names(second.elements) == ["2"]
    end
  end

  describe "map_ok/2" do
    test "returns the changed tree when each call returns ok" do
      assert {:ok, mapped} = Tree.map_ok(tree(), &{:ok, upcase(&1)})
      assert names(mapped) == ["a", "B", "pause", "c", "d", "E", "f", "g"]
      assert Tree.map_ok(nil, &{:ok, &1}) == {:ok, []}
    end

    test "returns the first error in document order, and calls the function on no element after it" do
      {record, visited} = recorder()

      fun = fn element ->
        record.(element)

        case element do
          %TextArea{text: text} -> {:error, "bad #{text}"}
          element -> {:ok, element}
        end
      end

      assert Tree.map_ok(tree(), fun) == {:error, "bad b"}
      assert visited.() == ["a", "b"]
    end
  end
end
