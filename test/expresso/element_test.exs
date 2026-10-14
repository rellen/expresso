defmodule Expresso.ElementTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder

  # The element modules of the application: each module under
  # `Expresso.Element` with `get_assigns/1` and `render/1`. A part of an
  # element, such as `Expresso.Element.Series`, has neither, and a module of a
  # chart, such as `Expresso.Element.Chart.Sankey`, has no `get_assigns/1`.
  defp element_modules do
    {:ok, modules} = :application.get_key(:expresso, :modules)

    for module <- modules,
        String.starts_with?(inspect(module), "Expresso.Element."),
        Code.ensure_loaded?(module),
        function_exported?(module, :get_assigns, 1),
        function_exported?(module, :render, 1),
        do: module
  end

  test "each element module declares the behaviour" do
    modules = element_modules()

    assert length(modules) >= 25

    for module <- modules do
      behaviours =
        module.module_info(:attributes) |> Keyword.get_values(:behaviour) |> List.flatten()

      assert Expresso.Element in behaviours,
             "#{inspect(module)} does not declare Expresso.Element"
    end
  end

  test "an element module has no copy of the component function of Temple" do
    for module <- element_modules() do
      refute function_exported?(module, :component, 3), inspect(module)
    end
  end

  test "an element module without render/1 gets a warning from the compiler" do
    source = """
    defmodule Expresso.ElementTest.NoRender do
      use Expresso.Element

      def get_assigns(_element), do: %{}
    end
    """

    {modules, diagnostics} = Code.with_diagnostics(fn -> Code.compile_string(source) end)

    for {module, _bytecode} <- modules do
      :code.purge(module)
      :code.delete(module)
    end

    assert [message] = for(%{severity: :warning, message: message} <- diagnostics, do: message)
    assert message =~ "render/1 required by behaviour Expresso.Element"
  end

  test "assigns/1 adds the class of the element to the assigns of its module" do
    [slide] =
      Builder.deck([
        Builder.slide("one", elements: [Builder.text_area(text: "Hi", class: "wide")])
      ]).slides

    [text_area] = slide.elements

    assigns = Expresso.Element.assigns(text_area)

    assert assigns.class == "wide"
    assert Map.delete(assigns, :class) == Expresso.Element.TextArea.get_assigns(text_area)
  end
end
