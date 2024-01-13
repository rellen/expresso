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

    assigns = [metadata: assigns[:slide].metadata] |> Keyword.merge(assigns[:slide].data)

    module = module_from_template_definition(:slide, template)

    temple do
      c(&do_render_template(module, &1), rest!: assigns)
    end
  end

  @doc """
  Render a deck template
  """
  @spec render_deck_template(part :: :header | :footer, assigns :: Keyword.t() | map()) :: term()
  def render_deck_template(part, assigns) do
    template = assigns[:template] || {:builtins, :default}

    module = module_from_template_definition(:deck, template)

    temple do
      c(&do_render_deck_template(module, part, &1), rest!: assigns)
    end
  end

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
end
