defmodule Expresso.UsageRulesTest do
  # The capture of the standard error is global, so a test that runs at the
  # same time could put its warnings into it.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  # `usage-rules.md` gives an agent the rules of Expresso. The package
  # `usage_rules` copies the file into the project of a user. An example that
  # does not compile teaches an agent a wrong form, so the tests compile and
  # render each example.
  @rules "usage-rules.md"

  # Each Elixir code block of the file that is a module, in order.
  defp modules do
    for [code] <-
          Regex.scan(~r/```elixir\n(.*?)```/s, File.read!(@rules), capture: :all_but_first),
        String.starts_with?(code, "defmodule "),
        do: code
  end

  defp remove(compiled) do
    for {module, _bytecode} <- compiled do
      :code.purge(module)
      :code.delete(module)
    end
  end

  @tag :tmp_dir
  test "each module of the file compiles with no warning, and each deck renders", %{
    tmp_dir: tmp_dir
  } do
    blocks = modules()
    assert length(blocks) >= 3

    for {block, index} <- Enum.with_index(blocks) do
      # The name of each module has a prefix, so it does not replace a module
      # of the tests.
      code =
        String.replace(block, "defmodule ", "defmodule Expresso.UsageRulesTest.", global: false)

      path = Path.join(tmp_dir, "rules_#{index}.exs")

      {compiled, warnings} = with_io(:stderr, fn -> Code.compile_string(code, path) end)
      on_exit(fn -> remove(compiled) end)
      assert warnings == "", "#{@rules}, block #{index + 1}:\n#{warnings}"

      [{module, _bytecode} | _rest] = compiled

      deck =
        if function_exported?(module, :deck, 0),
          do: module.deck(),
          else: Expresso.parse(module)

      assert Expresso.Deck.render(deck) =~ "<html"
    end
  end

  test "each short form of the table of the elements names an element of the DSL" do
    text = File.read!(@rules)
    [table] = Regex.run(~r/## The elements\n\n(.*?)\n\n/s, text, capture: :all_but_first)

    names =
      for [cell] <- Regex.scan(~r/^\| ([^|]+) \|/m, table, capture: :all_but_first),
          [name] <- Regex.scan(~r/`([a-z_]+)`/, cell, capture: :all_but_first),
          do: name

    assert length(names) >= 25
    Code.ensure_loaded!(Expresso.Builder)

    for name <- names do
      assert function_exported?(Expresso.Builder, String.to_atom(name), 0) or
               function_exported?(Expresso.Builder, String.to_atom(name), 1) or
               function_exported?(Expresso.Builder, String.to_atom(name), 2),
             "#{name} is not an entity of the DSL"
    end
  end

  # The files that the short forms read, in the root of the deck.
  defp files(root) do
    File.cp!("examples/logo.png", Path.join(root, "photo.jpg"))
    File.cp!("examples/logo.png", Path.join(root, "demo.png"))
    File.cp!("examples/logo.png", Path.join(root, "page.png"))
    File.cp!("examples/flow.svg", Path.join(root, "flow.svg"))
    File.cp!("test/fixtures/clip.webm", Path.join(root, "demo.webm"))
    File.mkdir_p!(Path.join(root, "lib"))
    File.write!(Path.join(root, "lib/app.ex"), "defmodule App do\nend\n")
  end

  @tag :tmp_dir
  test "each short form of the table of the elements compiles in a slide and renders", %{
    tmp_dir: tmp_dir
  } do
    files(tmp_dir)
    text = File.read!(@rules)
    [table] = Regex.run(~r/## The elements\n\n(.*?)\n\n/s, text, capture: :all_but_first)

    forms =
      for [cell] <- Regex.scan(~r/^\|[^|]+\|[^|]+\| (.+) \|$/m, table, capture: :all_but_first),
          [form] <- Regex.scan(~r/\A`(.+)`\z/, cell, capture: :all_but_first),
          do: form

    assert length(forms) == 16

    for {form, index} <- Enum.with_index(forms) do
      code = """
      defmodule Expresso.UsageRulesTest.Form#{index} do
        use Expresso
        root #{inspect(tmp_dir)}

        slide do
          heading "A form"
          #{form}
        end
      end
      """

      {compiled, warnings} = with_io(:stderr, fn -> Code.compile_string(code, @rules) end)
      on_exit(fn -> remove(compiled) end)
      assert warnings == "", "#{form}:\n#{warnings}"

      [{module, _bytecode} | _rest] = compiled

      # A formula in LaTeX needs Temml in Node, so the test only compiles it.
      if not String.contains?(form, "tex:"),
        do: assert(Expresso.Deck.render(Expresso.parse(module)) =~ "<html", form)
    end
  end

  test "each document that the file names is in the repository" do
    text = File.read!(@rules)

    paths =
      ~r/`(docs\/[a-z\/-]+(?:\.md|\/))`/
      |> Regex.scan(text, capture: :all_but_first)
      |> List.flatten()
      |> Enum.uniq()

    assert length(paths) >= 5
    for path <- paths, do: assert(File.exists?(path), "#{path} is not there")
  end

  test "each line of the file has no more than 100 characters, apart from a table" do
    for {line, number} <- @rules |> File.read!() |> String.split("\n") |> Enum.with_index(1),
        not String.starts_with?(line, "|") do
      assert String.length(line) <= 100, "line #{number} has #{String.length(line)} characters"
    end
  end
end
