defmodule Expresso.OverlayTest do
  use ExUnit.Case, async: true

  alias Expresso.Overlay

  describe "validate/1 accepts each form of the table" do
    test "an integer is one step" do
      assert Overlay.validate(3) == {:ok, %Overlay{pairs: [{3, 3}]}}
    end

    test "a range is a closed range" do
      assert Overlay.validate(2..4) == {:ok, %Overlay{pairs: [{2, 4}]}}
    end

    test "a list is a union" do
      assert Overlay.validate([2, 5..7]) == {:ok, %Overlay{pairs: [{2, 2}, {5, 7}]}}
    end

    test "from: is an open range" do
      assert Overlay.validate(from: 2) == {:ok, %Overlay{pairs: [{2, :max}]}}
    end

    test ":next is the counter" do
      assert Overlay.validate(:next) == {:ok, %Overlay{pairs: [{:next, :next}]}}
    end

    test "from: :next is the counter and each step after it" do
      assert Overlay.validate(from: :next) == {:ok, %Overlay{pairs: [{:next, :max}]}}
    end

    test "a list holds integers and a from: item" do
      assert Overlay.validate([2, from: 5]) == {:ok, %Overlay{pairs: [{2, 2}, {5, :max}]}}
    end

    test "a struct comes back as it is" do
      overlay = %Overlay{pairs: [{1, 1}]}
      assert Overlay.validate(overlay) == {:ok, overlay}
    end
  end

  describe "validate/1 gives an error for a different term" do
    test "zero and a negative step" do
      assert {:error, message} = Overlay.validate(0)
      assert message =~ "0 is not an overlay specification"
      assert {:error, _} = Overlay.validate(-2)
    end

    test "a range that goes down, or with a step" do
      assert {:error, message} = Overlay.validate(4..2//-1)
      assert message =~ "a range goes up with a step of 1"
      assert {:error, _} = Overlay.validate(1..9//2)
    end

    test "a range from zero" do
      assert {:error, _} = Overlay.validate(0..3)
    end

    test "an empty list" do
      assert {:error, message} = Overlay.validate([])
      assert message =~ "empty list"
    end

    test "a string, because a specification is a term" do
      assert {:error, message} = Overlay.validate("2-4")
      assert message =~ "expected an integer, a range, :next"
    end

    test "a list with a bad item names the item" do
      assert {:error, message} = Overlay.validate([2, :later])
      assert message =~ ":later is not an overlay specification"
    end

    test "a from: item with a bad value" do
      assert {:error, _} = Overlay.validate(from: 0)
      assert {:error, _} = Overlay.validate(from: "2")
    end
  end

  describe "resolve_next/2" do
    test "replaces :next with the counter and increments the counter one time" do
      {:ok, overlay} = Overlay.validate(from: :next)

      assert Overlay.resolve_next(overlay, 3) == {%Overlay{pairs: [{3, :max}]}, 4}
    end

    test "gives the same value to each :next of one specification" do
      {:ok, overlay} = Overlay.validate([:next, from: :next])

      assert Overlay.resolve_next(overlay, 2) == {%Overlay{pairs: [{2, 2}, {2, :max}]}, 3}
    end

    test "leaves the counter alone without a :next" do
      {:ok, overlay} = Overlay.validate([2, from: 5])

      assert Overlay.resolve_next(overlay, 7) == {overlay, 7}
    end
  end

  describe "max_step/1" do
    test "gives the largest explicit step" do
      {:ok, overlay} = Overlay.validate([2, 5..7, from: 9])
      assert Overlay.max_step(overlay) == 9
    end

    test "ignores :max and gives nil with no explicit step" do
      {:ok, overlay} = Overlay.validate(from: :next)
      assert Overlay.max_step(overlay) == nil
    end
  end

  describe "steps/2" do
    test "enumerates a closed specification" do
      {:ok, overlay} = Overlay.validate([2, 5..7])
      assert Overlay.steps(overlay, 9) == {:ok, [2, 5, 6, 7]}
    end

    test "runs an open range to the maximum" do
      {:ok, overlay} = Overlay.validate(from: 2)
      assert Overlay.steps(overlay, 4) == {:ok, [2, 3, 4]}
    end

    test "gives each step one time, in order" do
      {:ok, overlay} = Overlay.validate([3, 1..4, 2])
      assert Overlay.steps(overlay, 4) == {:ok, [1, 2, 3, 4]}
    end

    test "gives an error for a step more than the maximum" do
      {:ok, overlay} = Overlay.validate([2, from: 5])
      assert {:error, message} = Overlay.steps(overlay, 3)
      assert message =~ "the step 5 is more than the maximum step 3"
    end

    test "gives an error for a :next that nothing resolved" do
      {:ok, overlay} = Overlay.validate(:next)
      assert {:error, message} = Overlay.steps(overlay, 3)
      assert message =~ "holds :next"
    end

    test "resolves :next and then :max in order" do
      {:ok, overlay} = Overlay.validate(from: :next)
      {overlay, 3} = Overlay.resolve_next(overlay, 2)
      assert Overlay.steps(overlay, 5) == {:ok, [2, 3, 4, 5]}
    end
  end
end
