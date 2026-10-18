defmodule Expresso.VerifierTransformerTest do
  # The check writes to the standard error, so the tests do not run with a
  # test that captures it.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Expresso.Check

  doctest Expresso.VerifierTransformer

  @moduletag :tmp_dir

  # Each kind of error of a check in `Expresso.VerifierTransformer`: the
  # slides of a deck with the error, and a part of the message.
  @errors [
    effect: {
      """
      slide "one" do
        text_area(text: "spins", at: 2, effect: :spin)
      end
      """,
      "the effect :spin has no rule in the theme or in the CSS of the deck"
    },
    transition: {
      """
      transition :spin
      slide "one" do
        text_area(text: "a")
      end
      """,
      "the transition :spin has no rule"
    },
    pause: {
      """
      slide "one" do
        text_box do
          text_area(text: "a")
          pause()
        end
      end
      """,
      "a pause entity is inside a text_box"
    },
    child: {
      """
      slide "one" do
        text_box do
          at 2
          text_area(text: "a", at: 1)
        end
      end
      """,
      "the text_area has the step 1, and the text_box does not show at that step"
    },
    highlight: {
      """
      slide "one" do
        chart :bar do
          title "Orders"
          categories ["2023", "2024"]
          at 2
          highlight ["Orders", "Returns"]
          series "Orders", [1, 2]
          series "Returns", [3, 4]
        end
      end
      """,
      "the group of the highlight option has the step 3, and the chart does not show at that step"
    },
    goto: {
      """
      slide "one" do
        text_area(text: "Next", goto: [slide: 5])
      end
      """,
      "goto names the slide 5, and the deck has 1 slides"
    },
    css: {
      """
      css "missing.css"
      slide "one" do
        text_area(text: "a")
      end
      """,
      ~s(cannot read the CSS file "missing.css")
    }
  ]

  # The source of a deck module with the slides.
  defp source(kind, slides) do
    module = "Expresso.VerifierTransformerTest.#{Macro.camelize(Atom.to_string(kind))}"
    "defmodule #{module} do\n  use Expresso\n\n#{slides}end\n"
  end

  describe "the compile of a deck module" do
    for {kind, {slides, message}} <- @errors do
      test "stops for an error of the kind #{kind}" do
        source = source(unquote(kind), unquote(slides))
        error = assert_raise Spark.Error.DslError, fn -> Code.compile_string(source) end
        assert Exception.message(error) =~ unquote(message)
      end
    end

    test "gives the message of each error when a deck has more than one error" do
      source = """
      defmodule Expresso.VerifierTransformerTest.Two do
        use Expresso

        slide "one" do
          text_area(text: "spins", at: 2, effect: :spin, goto: [slide: 5])
        end
      end
      """

      error = assert_raise Spark.Error.DslError, fn -> Code.compile_string(source) end
      message = Exception.message(error)

      assert message =~ "2 errors occurred"
      assert message =~ "goto names the slide 5, and the deck has 1 slides"
      assert message =~ "the effect :spin has no rule"
    end
  end

  describe "mix expresso" do
    test "raises the error of a check, and writes no HTML", %{tmp_dir: dir} do
      {slides, message} = @errors[:effect]
      input = Path.join(dir, "talk.exs")
      output = Path.join(dir, "talk.html")
      File.write!(input, source(:command_effect, slides))

      error =
        assert_raise Spark.Error.DslError, fn ->
          Expresso.CommandLine.run([input, output], "mix expresso", "")
        end

      assert Exception.message(error) =~ message
      refute File.exists?(output)
    end
  end

  describe "--check" do
    for {kind, {slides, message}} <- @errors do
      test "reports an error of the kind #{kind} with the exit status 1", %{tmp_dir: dir} do
        input = Path.join(dir, "talk.exs")
        File.write!(input, source(:"check_#{unquote(kind)}", unquote(slides)))

        error =
          capture_io(:stderr, fn ->
            output = capture_io(fn -> send(self(), {:status, Check.run(input, nil, :basic)}) end)
            send(self(), {:output, output})
          end)

        assert_received {:status, 1}
        assert_received {:output, ""}
        assert error =~ "Spark.Error.DslError"
        assert error =~ unquote(message)
      end
    end
  end
end
