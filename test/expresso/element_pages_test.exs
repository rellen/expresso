defmodule Expresso.ElementPagesTest do
  # The capture of the standard error is global, so a test that runs at the
  # same time could put its warnings into it.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  # The reference pages of the elements whose code blocks are slides. The code
  # element, the embed element and the video element have tests of their own.
  # The test copies the files that the code blocks read into the root of the
  # deck.
  @pages ~w(text-box text-area image list table quotation spacer columns math diagram qr-code footnote audio shape)

  # The Elixir code blocks of a page, in order.
  defp blocks(page) do
    for [code] <- Regex.scan(~r/```elixir\n(.*?)```/s, File.read!(page), capture: :all_but_first),
        do: code
  end

  # The files that the code blocks read, in the root of the deck.
  defp files(root) do
    File.cp!("examples/logo.png", Path.join(root, "logo.png"))
    File.cp!("examples/logo.png", Path.join(root, "map.png"))
    File.cp!("examples/flow.svg", Path.join(root, "flow.svg"))
    File.cp!("examples/animations/chime.ogg", Path.join(root, "chime.ogg"))
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

        warnings = capture_io(:stderr, fn -> Code.compile_string(code, path) end)
        assert warnings == "", "#{path}, block #{index + 1}:\n#{warnings}"

        assert {:ok, deck} = Expresso.to_deck(module)
        assert Expresso.Deck.render(deck) =~ "<html"
      end
    end
  end

  # The pages give no limit to these nests, and `docs/architecture.md` tells
  # that the extension does not give some of them.
  test "a list of four levels, a text box in a text box and columns in a column render in place" do
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

        text_box do
          text_box do
            text_area(text: "inner")
          end
        end

        columns do
          column do
            text_box do
              columns do
                column do
                  text_area(text: "deep")
                end
              end
            end
          end
        end
      end
    end
    """

    Code.compile_string(code)
    assert {:ok, deck} = Expresso.to_deck(Expresso.ElementPagesTest.Nests)
    html = deck |> Expresso.Deck.render() |> Floki.parse_document!()

    assert html |> Floki.find(".screen ul ul ul ul") |> length() == 1
    assert html |> Floki.find(".screen .text-box .text-box") |> length() == 1
    assert html |> Floki.find(".screen .column .text-box .columns .column") |> length() == 1
  end
end
