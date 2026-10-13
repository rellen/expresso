defmodule Expresso.CodeGroupsTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Element.{Code, Lines}

  doctest Code, only: [reveal: 1]

  # A code element from a file, after `Expresso.PathTransformer` reads it.
  defp from_file(opts) do
    {:ok, code} = Code.build(struct!(Code, [src: "test/fixtures/code.js"] ++ opts))
    code
  end

  defp numbers(code), do: Enum.map(code.elements, & &1.numbers)

  describe "a group of texts" do
    test "runs from the line of the start text to the line of the end text" do
      code = Builder.code(text: "a\nb\nc\nd\ne", reveal: [[from: "b", to: "d"], [from: "e"]])

      assert numbers(code) == [[2, 3, 4], [5]]
    end

    test "takes the numbers of the file in an excerpt" do
      code =
        from_file(
          lines: [from: "function add", to: "export"],
          highlight: [[from: "return a + b"], [from: "function sum", to: "}"]]
        )

      assert [%Lines{numbers: [6]}, %Lines{numbers: [9, 10, 11]} | _rest] = code.elements
    end

    test "with to: :block, runs to the closing line of the block at the indent of the start line" do
      text = """
      for (const a of all) {
        if (a.extra) {
          a.count += 1;
          if (a.count > 3) { break; }
        }
        a.done = true;
      }
      """

      code =
        Builder.code(
          text: text,
          highlight: [[from: "if (a.extra) {", to: :block], [from: "a.done", to: :block]]
        )

      assert [[2, 3, 4, 5], [6] | _rest] = numbers(code)
    end

    test "with to: :block, ends a block of Python at its last line with more indent" do
      text = "def f(a):\n    if a:\n        b()\n\n    c()\nf(1)\n"

      code =
        Builder.code(
          text: text,
          reveal: [[from: "if a:", to: :block], [from: "def f", to: :block]]
        )

      assert numbers(code) == [[2, 3], [1, 2, 3, 4, 5]]
    end

    test "can mix with numbers" do
      code = Builder.code(text: "a\nb\nc", reveal: [1, [from: "c"]])
      assert numbers(code) == [[1], [3]]
    end

    test "gives an error for a start text that is not in the code" do
      assert_raise ArgumentError,
                   ~r/the start text "x" of the reveal option is not in the code/,
                   fn ->
                     Builder.code(text: "a\nb", reveal: [[from: "x"]])
                   end
    end

    test "gives an error for a start text that is in the code two times" do
      assert_raise ArgumentError, ~r/is in the code 2 times/, fn ->
        Builder.code(text: "a\na", highlight: [[from: "a"]])
      end
    end

    test "gives an error for an end text that is not after the start text" do
      assert_raise ArgumentError,
                   ~r/the end text "a" of the highlight option is not in the code/,
                   fn ->
                     Builder.code(text: "a\nb", highlight: [[from: "b", to: "a"]])
                   end
    end

    test "needs a start text" do
      assert_raise ArgumentError, ~r/line numbers, ranges and texts/, fn ->
        Builder.code(text: "a\nb", reveal: [[to: "b"]])
      end
    end
  end

  describe "the relative option" do
    test "counts the numbers from the first line of the excerpt" do
      code = from_file(lines: 5..11, relative: true, reveal: [1..3, 5])
      assert numbers(code) == [[5, 6, 7], [9]]
    end

    test "changes nothing for a code with text, which starts at line 1" do
      code = Builder.code(text: "a\nb\nc", relative: true, reveal: [2..3])
      assert numbers(code) == [[2, 3]]
    end

    test "still gives an error for a number past the excerpt" do
      assert {:error, message} =
               Code.build(%Code{
                 src: "test/fixtures/code.js",
                 lines: 5..7,
                 relative: true,
                 reveal: [4]
               })

      assert message ==
               "the reveal option has the line 4 of the excerpt, and the code element shows 3 lines"
    end
  end

  test "the DSL takes groups of texts and the relative option" do
    defmodule TextGroupsDeck do
      use Expresso

      slide "code" do
        code "js" do
          src "test/fixtures/code.js"
          lines from: "function add", to: "export"
          relative true
          highlight [[from: "return a + b"], 5..7]
        end
      end
    end

    assert {:ok, deck} = Expresso.to_deck(TextGroupsDeck)
    [code] = hd(deck.slides).elements
    assert [%Lines{numbers: [6]}, %Lines{numbers: [9, 10, 11]} | _rest] = code.elements
  end
end
