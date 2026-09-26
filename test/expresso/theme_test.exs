defmodule Expresso.ThemeTest do
  use ExUnit.Case, async: true

  alias Expresso.Theme

  # The assertions read the real `assets/style.css`. Therefore this file is also
  # the alarm for a difference between the theme and the check of the verifier.

  describe "uses?/1" do
    test "is true for a property that the theme registers" do
      assert Theme.uses?(:x)
      assert Theme.uses?(:y)
      assert Theme.uses?(:scale)
      assert Theme.uses?(:rotate)
      assert Theme.uses?(:opacity)
    end

    test "is true for a property that the theme reads and does not register" do
      assert Theme.uses?(:alert)
      assert Theme.uses?(:dim)
      assert Theme.uses?(:color)
      assert Theme.uses?(:dur)
      assert Theme.uses?(:ease)
    end

    test "is false for a property that the theme does not name" do
      refute Theme.uses?(:blur)
      refute Theme.uses?(:glow)
    end
  end

  describe "declares?/1" do
    test "is true for a property that the theme gives a value that is not a number" do
      assert Theme.declares?(:dur)
      assert Theme.declares?(:ease)
    end

    test "is false for a property that the theme reads or registers only" do
      refute Theme.declares?(:alert)
      refute Theme.declares?(:x)
      refute Theme.declares?(:dim)
    end
  end

  describe "syntax/1" do
    test "gives the descriptor of a property that the theme registers" do
      assert Theme.syntax(:x) == "<length>"
      assert Theme.syntax(:y) == "<length>"
      assert Theme.syntax(:scale) == "<number>"
      assert Theme.syntax(:rotate) == "<angle>"
      assert Theme.syntax(:opacity) == "<number>"
    end

    test "gives nil for a property that the theme does not register" do
      assert Theme.syntax(:alert) == nil
      assert Theme.syntax(:dim) == nil
      assert Theme.syntax(:color) == nil
    end
  end
end
