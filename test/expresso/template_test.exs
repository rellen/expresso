defmodule Expresso.TemplateTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder

  doctest Expresso.Template

  # A deck template that writes its header with a Temple component. The
  # macro of `Expresso.Template.Deck` imported only itself before issue 251,
  # so `c/2` did not compile in a deck template.
  defmodule ComponentDeck do
    use Expresso.Template.Deck

    def label(assigns) do
      temple do
        span class: "component-label" do
          @text
        end
      end
    end

    @impl Expresso.Template.Deck
    def header(assigns) do
      temple do
        div do
          c(&label/1, text: @deck.name)
        end
      end
    end

    @impl Expresso.Template.Deck
    def footer(_assigns) do
      temple do
        div do
        end
      end
    end
  end

  defp render(deck), do: deck |> Expresso.Deck.render() |> LazyHTML.from_document()

  # The warnings of the compiler for a source, and the source compiled.
  defp warnings(source) do
    {modules, diagnostics} = Code.with_diagnostics(fn -> Code.compile_string(source) end)

    for {module, _bytecode} <- modules do
      :code.purge(module)
      :code.delete(module)
    end

    for %{severity: :warning, message: message} <- diagnostics, do: message
  end

  test "a deck template can write its header with a component" do
    document =
      render(Builder.deck([Builder.slide("first")], name: "the deck", template: ComponentDeck))

    assert document |> LazyHTML.query(".screen .component-label") |> LazyHTML.text() =~ "the deck"
  end

  test "a slide template without render/1 gets a warning from the compiler" do
    source = """
    defmodule Expresso.TemplateTest.Misspelled do
      use Expresso.Template

      def rendr(_assigns), do: "body"
    end
    """

    assert [message] = warnings(source)
    assert message =~ "render/1 required by behaviour Expresso.Template.Slide"
  end

  test "a deck template without footer/1 gets a warning from the compiler" do
    source = """
    defmodule Expresso.TemplateTest.NoFooter do
      use Expresso.Template.Deck

      def header(_assigns), do: "header"
    end
    """

    assert [message] = warnings(source)
    assert message =~ "footer/1 required by behaviour Expresso.Template.Deck"
  end

  test "the compiler refuses a built-in template that does not exist, and names the built-in templates" do
    source = """
    defmodule Expresso.TemplateTest.Fancy do
      use Expresso

      slide "one" do
        template {:builtins, :fancy}
      end
    end
    """

    error = assert_raise Spark.Error.DslError, fn -> Code.compile_string(source) end

    assert Exception.message(error) =~
             "{:builtins, :fancy} is not a built-in slide template. " <>
               "The built-in slide templates are {:builtins, :default}."
  end

  test "the builder refuses a template that is not a module or a built-in template" do
    assert_raise ArgumentError, ~r/a deck template is a module or \{:builtins, name\}/, fn ->
      Builder.deck([Builder.slide("first")], template: "MyTemplate")
    end

    assert_raise ArgumentError, ~r/not a built-in slide template/, fn ->
      Builder.slide("first", template: {:builtins, :fancy})
    end
  end

  describe "a template that cannot render" do
    test "a slide template without render/1 gives the reason at render" do
      deck = Builder.deck([Builder.slide("first", template: Enum)])

      assert_raise ArgumentError,
                   "the slide template Enum has no render/1. " <>
                     "See docs/reference/template-option.md.",
                   fn -> render(deck) end
    end

    test "a deck template that is not loaded gives the reason at render" do
      deck = Builder.deck([Builder.slide("first")], template: Expresso.TemplateTest.Missing)

      assert_raise ArgumentError,
                   ~r/the deck template Expresso.TemplateTest.Missing is not loaded/,
                   fn ->
                     render(deck)
                   end
    end

    test "a deck struct from data with a built-in template that does not exist gives the reason at render" do
      deck = Builder.deck([Builder.slide("first")])
      deck = %{deck | metadata: Map.put(deck.metadata, :template, {:builtins, :fancy})}

      assert_raise ArgumentError, ~r/not a built-in deck template/, fn -> render(deck) end
    end
  end
end
