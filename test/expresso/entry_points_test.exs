defmodule Expresso.EntryPointsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  # A script that returns an `Expresso.Deck` struct. It needs no module, so two
  # runs of the same test give no warning for a module that Elixir redefines.
  @script """
  Expresso.Deck.new("a deck from a script")
  |> Expresso.Deck.add_slide("first", %{heading: "Hello"}, [
    Expresso.Element.TextBox.new("some text")
  ])
  """

  defp write_script(dir, name \\ "deck.exs", source \\ @script) do
    path = Path.join(dir, name)
    File.write!(path, source)
    path
  end

  describe "Expresso.main/2" do
    @tag :tmp_dir
    test "writes the HTML to the output path", %{tmp_dir: dir} do
      input = write_script(dir)
      output = Path.join(dir, "deck.html")

      assert Expresso.main(input, output) == :ok

      html = File.read!(output)

      assert String.starts_with?(html, "<!DOCTYPE html>\n")
      assert html =~ "a deck from a script"
      assert html =~ "some text"
    end

    @tag :tmp_dir
    test "writes the HTML to the standard output without an output path", %{tmp_dir: dir} do
      input = write_script(dir)

      output = capture_io(fn -> assert Expresso.main(input) == :ok end)

      assert output =~ "<!DOCTYPE html>"
      assert output =~ "some text"
    end

    test "writes the usage text without an input path" do
      output = capture_io(fn -> assert {:error, _message} = Expresso.main(nil) end)

      assert output =~ "Usage: mix expresso <input> [output]"
    end

    test "writes a message for an input path that is not present" do
      output = capture_io(fn -> assert {:error, _} = Expresso.main("no/such/deck.exs") end)

      assert output =~ "Couldn't find input file"
    end

    @tag :tmp_dir
    test "writes a message for a script that returns a different value", %{tmp_dir: dir} do
      input = write_script(dir, "number.exs", "42\n")

      output = capture_io(fn -> assert {:error, _} = Expresso.main(input) end)

      assert output =~ "must return an Expresso.Deck struct"
    end

    @tag :tmp_dir
    test "accepts a script that declares a module with the DSL", %{tmp_dir: dir} do
      source = """
      defmodule Expresso.EntryPointsTest.ScriptDeck do
        use Expresso

        name "a deck from a module"

        slide do
          text_box do
            text_area do
              text "from the DSL"
            end
          end
        end
      end
      """

      input = write_script(dir, "module_deck.exs", source)

      output = capture_io(fn -> assert Expresso.main(input) == :ok end)

      assert output =~ "a deck from a module"
      assert output =~ "from the DSL"
    end
  end

  describe "Mix.Tasks.Expresso.run/1" do
    @tag :tmp_dir
    test "reads the two paths of the arguments", %{tmp_dir: dir} do
      input = write_script(dir)
      output = Path.join(dir, "deck.html")

      capture_io(fn -> Mix.Tasks.Expresso.run([input, output]) end)

      assert File.read!(output) =~ "a deck from a script"
    end

    @tag :tmp_dir
    test "writes to the standard output with one argument", %{tmp_dir: dir} do
      input = write_script(dir)

      assert capture_io(fn -> Mix.Tasks.Expresso.run([input]) end) =~ "<!DOCTYPE html>"
    end

    test "writes the usage text with no argument" do
      assert capture_io(fn -> Mix.Tasks.Expresso.run([]) end) =~ "Usage: mix expresso"
    end
  end

  describe "Expresso.Example" do
    test "parses and renders" do
      html = Expresso.Example |> Expresso.parse() |> Expresso.Deck.render()

      assert html =~ "my presso"
      assert html =~ "hello, world!!!"
    end
  end
end
