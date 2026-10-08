defmodule Expresso.Presenter.DslTest do
  use ExUnit.Case, async: true

  import Spark.Test, only: [dsl_errors: 1]

  alias Expresso.Presenter.Definition

  doctest Expresso.Presenter.Commands
  doctest Expresso.Presenter.Projection

  @state """
  state index: 0, view: :present, blank: false, help: false, digits: "",
        overview: false, selected: 1, progress: true, every: false, undim: false

  sync [:blank]
  reset [:undim]
  """

  # Compile a module that uses the DSL, with a body. Each module gets its own
  # name, so the tests can run at the same time. `Module.create/3` compiles in
  # the test process, where `Spark.Test` collects the errors.
  defp compile(body) do
    name = Module.concat(__MODULE__, "M#{System.unique_integer([:positive])}")

    quoted =
      Code.string_to_quoted!("""
      use Expresso.Presenter.Dsl
      #{body}
      """)

    {:module, module, _binary, _result} = Module.create(name, quoted, __ENV__)
    module
  end

  # Verifier errors become warnings of the compiler, so `Spark.Test` collects
  # them.
  defp error(body) do
    assert [{_module, [error | _errors]}] = dsl_errors(do: compile(body))
    Exception.message(error)
  end

  describe "the DSL" do
    test "makes a definition from the options and the entities" do
      module =
        compile("""
        #{@state}
        mode :blank, match: [blank: true], any: set(:blank, false)

        mode :present do
          match view: :present
          each clear(:digits)
          other true

          key ["j", " "], step(1), "Next step"
          key ~w(0 1), append(:digits), "Type a slide number", label: "0 to 1", each: false
          event [click: :right, swipe: :left], step(1), "Next step", label: "Click"
        end
        """)

      definition = Definition.from(module)

      assert definition.state.view == :present
      assert definition.sync == [:blank]
      assert definition.reset == [:undim]

      assert [blank, present] = definition.modes
      assert blank.when == [blank: true]
      assert blank.any == [{:set, :blank, false}]
      assert present.each == [{:clear, :digits}]

      assert [next, digits, click] = present.bindings
      assert next.on == [key: "j", key: " "]
      assert next.commands == [{:step, 1}]
      assert digits.each == false
      assert click.on == [click: :right, swipe: :left]
      assert click.label == "Click"
    end

    test "reads the projections in the order of the module" do
      module =
        compile("""
        #{@state}
        attribute :view, "data-view"
        attribute :blank, "data-blank", flag: true
        property "--fraction", :fraction
        mark "data-speaker", ".handout-page", :index, [{"current", :index, 0}, {"next", :index, 1}]
        """)

      assert %{attributes: [view, blank], properties: [fraction], marks: [speaker]} =
               Definition.from(module).project

      assert {view.field, view.name, view.flag} == {:view, "data-view", false}
      assert blank.flag
      assert {fraction.name, fraction.entry} == {"--fraction", :fraction}
      assert speaker.values == [{"current", :index, 0}, {"next", :index, 1}]
    end

    test "Expresso.Presenter.Default holds each mode of the presenter" do
      assert Enum.map(Definition.presenter().modes, & &1.name) ==
               [:blank, :help, :overview, :present, :speaker, :handout]
    end
  end

  describe "the verifier" do
    test "refuses a state without each field" do
      message =
        error("""
        state index: 0
        sync []
        """)

      assert message =~ "the state must hold exactly the fields"
    end

    test "refuses a value of the wrong type in the state" do
      message =
        error("""
        state index: 0, view: :stage, blank: false, help: false, digits: "",
              overview: false, selected: 1, progress: true, every: false, undim: false
        sync []
        """)

      assert message =~ "the field view cannot have the value :stage"
    end

    test "refuses a value that the form of its kind in the schema refuses" do
      for {field, value} <- [digits: ~s("12\\n"), view: ~s("present"), selected: "0"] do
        state =
          [index: "0", view: ":present", blank: "false", help: "false", digits: ~s("")]
          |> Keyword.merge(overview: "false", selected: "1", progress: "true", every: "false")
          |> Keyword.put(:undim, "false")
          |> Keyword.put(field, value)
          |> Enum.map_join(", ", fn {key, text} -> "#{key}: #{text}" end)

        message = error("state #{state}\nsync []\n")

        assert message =~ "the field #{field} cannot have the value"
      end
    end

    test "refuses an unknown field in the option sync or in the option reset" do
      for {option, fields} <- [sync: "sync [:blank]", reset: "reset [:undim]"] do
        message = error(String.replace(@state, fields, "#{option} [:blank, :color]"))
        assert message =~ "the option #{option} names the unknown fields [:color]"
      end
    end

    test "refuses the field index in the option sync or in the option reset" do
      for {option, fields} <- [sync: "sync [:blank]", reset: "reset [:undim]"] do
        message = error(String.replace(@state, fields, "#{option} [:index]"))
        assert message =~ "the option #{option} cannot name the field index"
      end
    end

    test "refuses two modes with the same name" do
      message =
        error("""
        #{@state}
        mode :blank, match: [blank: true], any: set(:blank, false)
        mode :blank, match: [help: true], any: set(:help, false)
        """)

      assert message =~ "two modes have the name :blank"
    end

    test "refuses a condition on an unknown field or with a wrong value" do
      assert error("""
             #{@state}
             mode :color, match: [color: :red], any: set(:blank, false)
             """) =~ "the condition color: :red is not valid"

      assert error("""
             #{@state}
             mode :stage, match: [view: :stage], any: set(:blank, false)
             """) =~ "the condition view: :stage is not valid"
    end

    test "refuses a command that the script does not know, or a value of the wrong type" do
      for {command, text} <- [
            {"set(:view, :stage)", "{:set, :view, :stage}"},
            {"set(:selected, 0)", "{:set, :selected, 0}"},
            {"toggle(:digits)", "{:toggle, :digits}"},
            {"builtin(:print)", "{:builtin, :print}"},
            {"select_by(columns(2))", "{:select_by, {:columns, 2}}"},
            {"{:jump, 1}", "{:jump, 1}"}
          ] do
        message =
          error("""
          #{@state}
          mode :present do
            match view: :present
            key "x", #{command}, "A key"
          end
          """)

        assert message =~ "#{text} is not a valid command", command
      end
    end

    test "refuses a mode with the option any and a binding" do
      message =
        error("""
        #{@state}
        mode :blank do
          match blank: true
          any set(:blank, false)
          key "j", step(1), "Next step"
        end
        """)

      assert message =~ "a mode with the option any cannot have bindings"
    end

    test "refuses an event with two bindings in one mode" do
      message =
        error("""
        #{@state}
        mode :present do
          match view: :present
          key ["j", "ArrowRight"], step(1), "Next step"
          key "ArrowRight", step(-1), "Previous step"
        end
        """)

      assert message =~ ~s(the event {:key, "ArrowRight"} has two bindings)
      assert message =~ "mode -> present"
    end

    test "accepts the same event in two modes" do
      module =
        compile("""
        #{@state}
        mode :present do
          match view: :present
          key "j", step(1), "Next step"
        end

        mode :handout do
          match view: :handout
          key "j", step(1), "Next step"
        end
        """)

      assert length(Definition.from(module).modes) == 2
    end

    test "refuses the event :element in a mode without the option element" do
      message =
        error("""
        #{@state}
        mode :present do
          match view: :present
          event :element, [], "A slide", label: "Click a slide"
        end
        """)

      assert message =~ "the event :element needs the option element: true"
    end

    test "refuses a projection with an unknown field or a wrong name" do
      for {projection, text} <- [
            {~s(attribute :color, "data-color"), "is not valid"},
            {~s(attribute :digits, "data-digits", flag: true), "is not valid"},
            {~s(attribute :view, "view"), "must start with data-"},
            {~s(property "fraction", :fraction), "is not valid"},
            {~s(mark "data-a", ".page", :slide, [{"", :view, 0}]), "is not valid"},
            {~s(mark "data-a", ".page", :slide, []), "is not valid"},
            {~s(mark "a", ".page", :slide, [{"", :selected, 0}]), "must start with data-"}
          ] do
        assert error("""
               #{@state}
               #{projection}
               """) =~ text,
               projection
      end
    end

    test "refuses two projections for one attribute" do
      message =
        error("""
        #{@state}
        attribute :blank, "data-blank", flag: true
        attribute :help, "data-blank", flag: true
        """)

      assert message =~ "two projections write the attribute data-blank"
    end
  end
end
