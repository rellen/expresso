defmodule Expresso.Template do
  @moduledoc """
  Functions for working with templates
  """

  use Temple.Component

  defmacro __using__(_) do
    quote do
      import Temple
      import unquote(__MODULE__)
    end
  end

  @doc """
  Render a slide template
  """
  @spec render_slide_template(assigns :: Keyword.t() | map()) :: term()
  def render_slide_template(assigns) do
    template = assigns[:slide].metadata[:template] || {:builtins, :default}

    assigns = Expresso.Slide.get_assigns(assigns[:slide])

    module = module_from_template_definition(:slide, template)

    temple do
      c(&do_render_template(module, &1), rest!: assigns)
    end
  end

  @doc """
  Render the header or the footer of a deck template

  The function reads the template from `deck.metadata[:template]`. The default
  value is `{:builtins, :default}`.
  """
  @spec render_deck_template(part :: :header | :footer, assigns :: Keyword.t() | map()) :: term()
  def render_deck_template(part, assigns) do
    template = deck_template(assigns[:deck])

    module = module_from_template_definition(:deck, template)

    temple do
      c(&do_render_deck_template(module, part, &1), rest!: assigns)
    end
  end

  defp deck_template(%Expresso.Deck{metadata: %{template: template}}), do: template

  defp deck_template(_deck), do: {:builtins, :default}

  defp do_render_template(module, assigns) do
    apply(module, :render, [assigns])
  end

  defp do_render_deck_template(module, part, assigns) do
    apply(module, part, [assigns])
  end

  defp module_from_template_definition(:slide, {:builtins, name}) do
    suffix = name |> Atom.to_string() |> :string.titlecase()
    Module.concat(Expresso.Builtins.Templates.Slides, suffix)
  end

  defp module_from_template_definition(:deck, {:builtins, name}) do
    suffix = name |> Atom.to_string() |> :string.titlecase()
    Module.concat(Expresso.Builtins.Templates.Decks, suffix)
  end

  defp module_from_template_definition(_part, module) when is_atom(module), do: module

  def render_elements(assigns) do
    temple do
      for %module{} = element <- assigns.elements do
        c(&do_render_element(module, &1), rest!: module.get_assigns(element))
      end
    end
  end

  defp do_render_element(module, assigns) do
    apply(module, :render, [assigns])
  end
end
