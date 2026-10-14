defmodule Expresso.Template do
  @moduledoc """
  Functions for working with templates

  `use Expresso.Template` makes a slide template. It imports Temple and this
  module, and it declares the behaviour `Expresso.Template.Slide`, so a module
  without `render/1` gets a warning from the compiler. A deck template uses
  `Expresso.Template.Deck` in its place.
  """

  use Temple.Component

  # The built-in templates of each part, by name.
  @builtins %{
    slide: %{default: Expresso.Builtins.Templates.Slides.Default},
    deck: %{default: Expresso.Builtins.Templates.Decks.Default}
  }

  # The functions that each template module must export.
  @callbacks %{slide: [render: 1], deck: [header: 1, footer: 1]}

  defmacro __using__(_) do
    quote do
      import Temple
      import unquote(__MODULE__)

      @behaviour Expresso.Template.Slide
    end
  end

  @doc """
  Make sure that a template option gives a module or a built-in template

  This function is the custom type of the options `template` and
  `slide_template`. `part` is `:slide` or `:deck`. A module is not checked
  here, because a template in `./priv/templates/` compiles only before a
  render. `module/2` checks it at render.

      iex> Expresso.Template.validate({:builtins, :default}, :slide)
      {:ok, {:builtins, :default}}

      iex> Expresso.Template.validate(MyTemplate, :deck)
      {:ok, MyTemplate}

      iex> Expresso.Template.validate({:builtins, :fancy}, :slide)
      {:error, "{:builtins, :fancy} is not a built-in slide template. The built-in slide templates are {:builtins, :default}."}

      iex> {:error, _message} = Expresso.Template.validate("MyTemplate", :slide)
  """
  @spec validate(term(), :slide | :deck) :: {:ok, term()} | {:error, String.t()}
  def validate({:builtins, name} = value, part) when is_atom(name) do
    if Map.has_key?(@builtins[part], name),
      do: {:ok, value},
      else:
        {:error, "#{inspect(value)} is not a built-in #{part} template. #{builtin_list(part)}"}
  end

  def validate(module, _part) when is_atom(module) and module not in [nil, true, false],
    do: {:ok, module}

  def validate(value, part) do
    {:error,
     "a #{part} template is a module or {:builtins, name}, such as {:builtins, :default}, " <>
       "and #{inspect(value)} is neither"}
  end

  defp builtin_list(part) do
    names =
      @builtins[part]
      |> Map.keys()
      |> Enum.sort()
      |> Enum.map_join(", ", &inspect({:builtins, &1}))

    "The built-in #{part} templates are #{names}."
  end

  @doc """
  Return the module of a template, and make sure that it can render

  `part` is `:slide` or `:deck`, and `template` is a module or
  `{:builtins, name}`. A slide template must export `render/1`, and a deck
  template must export `header/1` and `footer/1`. The function raises an
  `ArgumentError` with the reason for a template that cannot render. A deck
  struct from data does not go through the DSL, so this check also covers a
  template that the DSL did not check.

      iex> Expresso.Template.module(:slide, {:builtins, :default})
      Expresso.Builtins.Templates.Slides.Default
  """
  @spec module(:slide | :deck, term()) :: module()
  def module(part, {:builtins, name} = template) do
    case @builtins[part] do
      %{^name => module} ->
        module

      _other ->
        raise ArgumentError,
              "#{inspect(template)} is not a built-in #{part} template. #{builtin_list(part)}"
    end
  end

  def module(part, module) when is_atom(module) and module not in [nil, true, false] do
    # `function_exported?/3` is false for a module that is not loaded yet, so
    # the module loads first.
    if not Code.ensure_loaded?(module) do
      raise ArgumentError,
            "the #{part} template #{inspect(module)} is not loaded. Compile it before the " <>
              "deck renders, or put it in ./priv/templates/#{part}s/."
    end

    missing =
      for {name, arity} <- @callbacks[part],
          not function_exported?(module, name, arity),
          do: "#{name}/#{arity}"

    if missing != [] do
      raise ArgumentError,
            "the #{part} template #{inspect(module)} has no #{Enum.join(missing, " and ")}. " <>
              "See docs/reference/template-option.md."
    end

    module
  end

  def module(part, value) do
    {:error, message} = validate(value, part)
    raise ArgumentError, message
  end

  @doc """
  Render a slide template

  The function reads the template from `slide.metadata[:template]`, then from
  `deck.metadata[:slide_template]`. The default value is `{:builtins, :default}`.
  """
  @spec render_slide_template(assigns :: Keyword.t() | map()) :: term()
  def render_slide_template(assigns) do
    template =
      assigns[:slide].metadata[:template] || slide_template(assigns[:deck]) ||
        {:builtins, :default}

    assigns = Expresso.Slide.get_assigns(assigns[:slide])

    module = module(:slide, template)

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

    module = module(:deck, template)

    temple do
      c(&do_render_deck_template(module, part, &1), rest!: assigns)
    end
  end

  defp deck_template(%Expresso.Deck{metadata: %{template: template}}) when template != nil,
    do: template

  defp deck_template(_deck), do: {:builtins, :default}

  defp slide_template(%Expresso.Deck{metadata: %{slide_template: template}}), do: template
  defp slide_template(_deck), do: nil

  defp do_render_template(module, assigns) do
    apply(module, :render, [assigns])
  end

  defp do_render_deck_template(module, part, assigns) do
    apply(module, part, [assigns])
  end

  @doc """
  Render each element of a slide

  The assigns hold the elements under the key `elements`. The function reads the
  module of each element from its struct, and it calls `get_assigns/1` and
  `render/1` of that module.
  """
  @spec render_elements(map()) :: Phoenix.HTML.safe()
  def render_elements(assigns) do
    temple do
      for %module{} = element <- assigns.elements,
          module not in [
            Expresso.Element.Pause,
            Expresso.Element.Footnote,
            Expresso.Element.Shape
          ] do
        c(&do_render_element(module, &1),
          rest!: element |> module.get_assigns() |> Map.put(:class, Map.get(element, :class))
        )
      end
    end
  end

  defp do_render_element(module, assigns) do
    apply(module, :render, [assigns])
  end
end
