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

  describe "kinds/0" do
    test "holds each element module, but an item, a row and a spacer" do
      modules =
        for {module, _class, _kind, _content} <- Expresso.Element.kinds(), module, do: module

      parts = [Expresso.Element.Item, Expresso.Element.Row, Expresso.Element.Spacer]

      assert Enum.sort(modules ++ parts) == Enum.sort(element_modules())
    end

    # One element of each module, with the class `sample` on its root tag.
    defp samples do
      sample = [class: "sample"]
      poster = "examples/animations/clip.png"

      [
        {Builder.text_box(sample ++ [elements: [Builder.text_area(text: "a")]]),
         Expresso.Element.TextBox},
        {Builder.text_area(sample ++ [text: "a"]), Expresso.Element.TextArea},
        {Builder.image(poster, sample), Expresso.Element.Image},
        {Builder.list(sample ++ [elements: [Builder.item("a")]]), Expresso.Element.List},
        {Builder.table(sample ++ [elements: [Builder.row(["a", "b"])]]), Expresso.Element.Table},
        {Builder.quotation("a", sample), Expresso.Element.Quotation},
        {Builder.code("elixir", sample ++ [text: "x = 1"]), Expresso.Element.Code},
        {Builder.math("<math><mi>x</mi></math>", sample), Expresso.Element.Math},
        {Builder.diagram("test/fixtures/flow.svg", sample ++ [alt: "a"]),
         Expresso.Element.Diagram},
        {Builder.video("examples/animations/clip.webm", sample ++ [title: "a", poster: poster]),
         Expresso.Element.Video},
        {Builder.embed("https://example.com/", sample ++ [title: "a"]), Expresso.Element.Embed},
        {Builder.audio("examples/animations/chime.ogg", sample ++ [title: "a"]),
         Expresso.Element.Audio},
        {Builder.qr_code("https://example.com/", sample), Expresso.Element.QrCode},
        {Builder.shape(:rect, sample ++ [x: "10%", y: "10%", width: "20%", height: "20%"]),
         Expresso.Element.Shape},
        {Builder.chart(
           :bar,
           sample ++ [title: "a", categories: ["a"], elements: [Builder.series("a", [1])]]
         ), Expresso.Element.Chart},
        {Builder.callout(:tip, sample), Expresso.Element.Callout},
        {Builder.toc(sample), Expresso.Element.Toc},
        {Builder.stat(1, sample), Expresso.Element.Stat},
        {Builder.icon("check", sample), Expresso.Element.Icon},
        {Builder.columns(sample ++ [elements: [Builder.column()]]), Expresso.Element.Columns},
        {Builder.columns(elements: [Builder.column(sample)]), Expresso.Element.Column},
        {Builder.footnote("a", sample), Expresso.Element.Footnote}
      ]
    end

    # The first kind whose class the tag has, as `assets/src/morph.ts` and
    # `assets/src/layout.ts` find it.
    defp kind_of(tag) do
      classes = tag |> Floki.attribute("class") |> Enum.flat_map(&String.split/1)

      Enum.find(Expresso.Element.kinds(), fn {_module, class, _kind, _content} ->
        class in classes
      end)
    end

    defp present(element) do
      [Builder.slide("one", heading: "Kinds", section: "Kinds", elements: [element])]
      |> Builder.deck(name: "kinds")
      |> Expresso.Deck.render()
      |> Floki.parse_document!()
      |> Floki.find(".screen")
    end

    test "the script finds the kind of each element from the class of its root tag" do
      samples = samples()
      assert length(samples) == length(Expresso.Element.kinds()) - 1

      for {element, module} <- samples do
        [root] = element |> present() |> Floki.find(".sample")
        assert {^module, _class, _kind, _content} = kind_of(root)
      end

      [container] =
        Builder.text_area(text: "a") |> present() |> Floki.find(".slide-heading-container")

      assert {nil, _class, "heading", :text} = kind_of(container)
    end
  end
end
