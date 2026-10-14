defmodule Expresso.DslTest do
  use ExUnit.Case, async: true

  alias Expresso.Dsl
  alias Spark.Error.DslError

  doctest Dsl

  defmodule SpinDeck do
    use Expresso

    name "spin deck"

    css ~S([data-effect="spin"] { --enter-animation: spin; })

    slide "one" do
      text_box do
        at 1
        effect :spin
      end
    end
  end

  # A state of Spark with two slides, as Spark gives it to a transformer.
  defp state do
    %{
      [:deck] => %{entities: [%{name: "a", n: 1}, %{name: nil, n: 2}]},
      persist: %{module: SpinDeck}
    }
  end

  describe "map_slides/2" do
    test "returns the value of each slide, and nil for :ok" do
      assert Dsl.map_slides(state(), &{:ok, &1.n * 10}) == {:ok, [10, 20]}
      assert Dsl.map_slides(state(), fn _slide -> :ok end) == {:ok, [nil, nil]}
    end

    test "returns the first error with the module and the path of its slide" do
      assert {:error, %DslError{} = error} =
               Dsl.map_slides(state(), fn slide -> {:error, "bad #{slide.n}"} end)

      assert error.module == SpinDeck
      assert error.path == [:deck, :slide, "a"]
      assert error.message =~ "bad 1"
    end
  end

  test "put_slides/2 writes the slides back, and get_entities/2 reads them" do
    state = Dsl.put_slides(state(), [%{name: "c"}])

    assert Spark.Dsl.Transformer.get_entities(state, [:deck]) == [%{name: "c"}]
  end

  describe "the names of the CSS" do
    test "the transformer persists the names of the CSS of the deck" do
      assert {:ok, names} = Spark.Dsl.Extension.get_persisted(SpinDeck, :css_names)
      assert "spin" in names.effects
    end

    test "one compile scans the CSS of a deck one time" do
      source = """
      defmodule Expresso.DslTest.ScanDeck do
        use Expresso

        css ~S([data-effect="spin"] { --enter-animation: spin; } [data-transition="wipe"] { --x: 1; })

        slide "one" do
          transition :fade
        end
      end
      """

      # A process that counts the trace messages. The trace reaches only this
      # process and the processes that it starts, and a process does not get
      # the trace messages of its own calls.
      counter = spawn_link(&count/0)
      :erlang.trace_pattern({Expresso.Css, :scan, 1}, true, [:local])
      :erlang.trace(self(), true, [:call, :set_on_spawn, {:tracer, counter}])

      try do
        for {module, _bytecode} <- Code.compile_string(source) do
          :code.purge(module)
          :code.delete(module)
        end
      after
        :erlang.trace(self(), false, [:call, :set_on_spawn])
        :erlang.trace_pattern({Expresso.Css, :scan, 1}, false, [:local])
      end

      send(counter, {:count, self()})
      assert_receive {:scans, 1}
    end
  end

  defp count(scans \\ 0) do
    receive do
      {:trace, _pid, :call, {Expresso.Css, :scan, [_css]}} -> count(scans + 1)
      {:count, pid} -> send(pid, {:scans, scans})
    end
  end
end
