defmodule Expresso.ElementPagesTest do
  # The capture of the standard error is global, so a test that runs at the
  # same time could put its warnings into it.
  use ExUnit.Case, async: false

  import Expresso.Test.HTML

  import ExUnit.CaptureIO

  # The reference pages of the elements whose code blocks are slides. The code
  # element, the embed element and the video element have tests of their own.
  # The test copies the files that the code blocks read into the root of the
  # deck.
  @pages ~w(text-box text-area image list table quotation spacer columns math diagram qr-code footnote audio shape chart tree callout toc stat icon)

  # The Elixir code blocks of a page, in order.
  defp blocks(page) do
    for [code] <- Regex.scan(~r/```elixir\n(.*?)```/s, File.read!(page), capture: :all_but_first),
        do: code
  end

  # Remove the modules that a test compiled. `mix test --repeat-until-failure`
  # runs the suite again in the same VM, and a second compile of a loaded
  # module writes a warning.
  defp remove(compiled) do
    for {module, _bytecode} <- compiled do
      :code.purge(module)
      :code.delete(module)
    end
  end

  # The files that the code blocks read, in the root of the deck.
  defp files(root) do
    File.cp!("examples/logo.png", Path.join(root, "logo.png"))
    File.cp!("examples/logo.png", Path.join(root, "map.png"))
    File.cp!("examples/flow.svg", Path.join(root, "flow.svg"))
    File.cp!("examples/animations/chime.ogg", Path.join(root, "chime.ogg"))
    File.cp!("examples/animations/visitors.csv", Path.join(root, "visitors.csv"))

    for path <- ["assets/logo.svg", "icons/espresso.svg"] do
      File.mkdir_p!(Path.join(root, Path.dirname(path)))
      File.cp!("examples/animations/icons/espresso.svg", Path.join(root, path))
    end
  end

  for page <- @pages do
    @tag :tmp_dir
    test "each code block of the page of the #{page} element compiles with no warning and renders",
         %{tmp_dir: tmp_dir} do
      files(tmp_dir)
      path = "docs/reference/#{unquote(page)}-element.md"
      blocks = blocks(path)
      assert blocks != [], "#{path} has no code block"

      for {block, index} <- Enum.with_index(blocks) do
        module =
          Module.concat([Expresso.ElementPagesTest, Macro.camelize(unquote(page)), "D#{index}"])

        code = """
        defmodule #{inspect(module)} do
          use Expresso
          name "page"
          root #{inspect(tmp_dir)}
        #{block}
        end
        """

        {compiled, warnings} = with_io(:stderr, fn -> Code.compile_string(code, path) end)
        on_exit(fn -> remove(compiled) end)
        assert warnings == "", "#{path}, block #{index + 1}:\n#{warnings}"

        assert {:ok, deck} = Expresso.to_deck(module)
        assert Expresso.Deck.render(deck) =~ "<html"
      end
    end
  end

  # The pages give no limit to the levels of a list, and `docs/architecture.md`
  # tells that the extension gives one definition of the list.
  test "a list of four levels renders in place" do
    code = """
    defmodule Expresso.ElementPagesTest.Nests do
      use Expresso
      name "nests"

      slide "s" do
        list do
          item "1" do
            list do
              item "2" do
                list do
                  item "3" do
                    list do
                      item "4"
                    end
                  end
                end
              end
            end
          end
        end

      end
    end
    """

    compiled = Code.compile_string(code)
    on_exit(fn -> remove(compiled) end)
    assert {:ok, deck} = Expresso.to_deck(Expresso.ElementPagesTest.Nests)
    html = document(deck)

    assert count(html, ".screen ul ul ul ul") == 1
  end
end
