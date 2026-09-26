defmodule Expresso.OverlayTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Expresso.Overlay
  alias Expresso.Test.Overlay, as: Gen

  defp spec(term) do
    {:ok, spec} = Overlay.new(term)
    spec
  end

  describe "new/1 accepts each form of the table" do
    test "an integer is one step" do
      assert Overlay.new(3) == {:ok, %Overlay{pairs: [{3, 3}]}}
    end

    test "a range is a closed range" do
      assert Overlay.new(2..4) == {:ok, %Overlay{pairs: [{2, 4}]}}
    end

    test "a list is a union" do
      assert Overlay.new([2, 5..7]) == {:ok, %Overlay{pairs: [{2, 2}, {5, 7}]}}
    end

    test "from: is an open range" do
      assert Overlay.new(from: 2) == {:ok, %Overlay{pairs: [{2, :max}]}}
    end

    test ":next is the counter" do
      assert Overlay.new(:next) == {:ok, %Overlay{pairs: [{:next, :next}]}}
    end

    test "from: :next is the counter and each step after it" do
      assert Overlay.new(from: :next) == {:ok, %Overlay{pairs: [{:next, :max}]}}
    end

    test "a list holds integers and a from: item" do
      assert Overlay.new([2, from: 5]) == {:ok, %Overlay{pairs: [{2, 2}, {5, :max}]}}
    end

    test "a struct comes back as it is" do
      overlay = %Overlay{pairs: [{1, 1}]}
      assert Overlay.new(overlay) == {:ok, overlay}
    end
  end

  describe "new/1 gives an error for a different term" do
    test "zero and a negative step" do
      assert {:error, message} = Overlay.new(0)
      assert message =~ "0 is not an overlay specification"
      assert {:error, _} = Overlay.new(-2)
    end

    test "a range that goes down, or with a step" do
      assert {:error, message} = Overlay.new(4..2//-1)
      assert message =~ "a range goes up with a step of 1"
      assert {:error, _} = Overlay.new(1..9//2)
    end

    test "a range from zero" do
      assert {:error, _} = Overlay.new(0..3)
    end

    test "an empty list" do
      assert {:error, message} = Overlay.new([])
      assert message =~ "empty list"
    end

    test "a string, because a specification is a term" do
      assert {:error, message} = Overlay.new("2-4")
      assert message =~ "expected an integer, a range, :next"
    end

    test "a list with a bad item names the item" do
      assert {:error, message} = Overlay.new([2, :later])
      assert message =~ ":later is not an overlay specification"
    end

    test "a from: item with a bad value" do
      assert {:error, _} = Overlay.new(from: 0)
      assert {:error, _} = Overlay.new(from: "2")
    end
  end

  describe "the properties of a specification" do
    defp resolve(term, counter) do
      {:ok, spec} = Overlay.new(term)
      Overlay.resolve_next(spec, counter)
    end

    defp next?(item), do: item in [:next, {:from, :next}]

    defp model(term, counter, max) do
      term
      |> List.wrap()
      |> Enum.flat_map(fn
        step when is_integer(step) -> [step]
        first..last//1 -> Enum.to_list(first..last//1)
        {:from, :next} -> Enum.to_list(counter..max//1)
        {:from, step} -> Enum.to_list(step..max//1)
        :next -> [counter]
      end)
      |> Enum.uniq()
      |> Enum.sort()
    end

    defp explicit(term, counter) do
      Enum.flat_map(List.wrap(term), fn
        step when is_integer(step) -> [step]
        first..last//1 -> [first, last]
        {:from, :next} -> [counter]
        {:from, step} -> [step]
        :next -> [counter]
      end)
    end

    property "new/1 accepts each form, with one pair for each item" do
      check all term <- Gen.spec() do
        assert {:ok, %Overlay{pairs: pairs}} = Overlay.new(term)
        assert length(pairs) == length(List.wrap(term))
      end
    end

    property "new/1 refuses each other term with a message" do
      check all term <- Gen.invalid() do
        assert {:error, message} = Overlay.new(term)
        assert is_binary(message) and message != ""
      end
    end

    property "a specification is relative when it holds :next" do
      check all term <- Gen.spec() do
        assert Overlay.relative?(spec(term)) == Enum.any?(List.wrap(term), &next?/1)
      end
    end

    property "resolve_next/2 moves the counter one time for a relative specification" do
      check all term <- Gen.spec(), counter <- Gen.step() do
        {resolved, next} = resolve(term, counter)
        relative? = Enum.any?(List.wrap(term), &next?/1)

        assert next == if(relative?, do: counter + 1, else: counter)
        refute Overlay.relative?(resolved)
      end
    end

    property "first_step/1 is the smallest explicit first step" do
      check all term <- Gen.spec() do
        firsts =
          for item <- List.wrap(term), not next?(item) do
            case item do
              first.._last//1 -> first
              {:from, step} -> step
              step -> step
            end
          end

        assert Overlay.first_step(spec(term)) == Enum.min(firsts, fn -> nil end)
      end
    end

    property "max_step/1 is the largest explicit step after resolve_next/2" do
      check all term <- Gen.spec(), counter <- Gen.step() do
        {resolved, _next} = resolve(term, counter)

        assert Overlay.max_step(resolved) == Enum.max(explicit(term, counter), fn -> nil end)
      end
    end

    property "steps/2 gives the union of the items, in order, within the maximum" do
      check all term <- Gen.spec(), counter <- Gen.step(), max <- Gen.max() do
        {resolved, _next} = resolve(term, counter)
        too_large = Enum.filter(explicit(term, counter), &(&1 > max))

        case Overlay.steps(resolved, max) do
          {:ok, steps} ->
            assert too_large == []
            assert steps == model(term, counter, max)
            assert Enum.all?(steps, &(&1 in 1..max))

          {:error, message} ->
            assert too_large != []
            assert message =~ "is more than the maximum step #{max}"
        end
      end
    end

    property "steps/2 refuses a specification with an unresolved :next" do
      check all term <- Gen.relative_spec(), max <- Gen.max() do
        assert {:error, _message} = Overlay.steps(spec(term), max)
      end
    end

    test "steps/2 names the :next when it is the first defect" do
      assert {:error, message} = Overlay.steps(spec(:next), 3)
      assert message =~ "holds :next"
    end
  end
end
