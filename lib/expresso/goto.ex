defmodule Expresso.Goto do
  @moduledoc """
  A link from an element to a slide and a step of the deck

  The `goto` option of a text area, an image or an item takes a keyword list,
  such as `goto: [slide: 5]` or `goto: [slide: 5, step: 2]`. The slide is a
  number or the name of a slide, such as `goto: [slide: "summary"]`. The
  default step is 1. The render function of the element then puts its content
  into a link:

  ```html
  <a class="goto" href="#5.2" data-commands='[["goto",7]]'>
  ```

  The number 7 is the index of step 2 of slide 5 in the list of the steps. A
  click on the link in the present view runs the commands of the link with the
  program of the presenter, so the presenter goes to that step. The link is an
  HTML link, so the keyboard and a screen reader can use it. In the handout view
  and in the speaker view, the script does not run the commands.

  A name must belong to one slide of the deck. A link by name stays correct
  when a slide comes in front of its target, and a link by number does not.

  A link can only go to a slide and a step of the deck. Thus the handout view
  and the print show each state that a link can give. `Expresso.GotoVerifier`
  refuses a slide or a step that the deck does not have, and a name that no
  slide or more than one slide has. A deck from the
  imperative API can put a struct into the `goto` field of the element, and
  `resolve/1` raises for such a slide or step.
  """

  alias Expresso.{Deck, Steps}
  alias Expresso.Overlay.Render
  alias Expresso.Presenter.Program

  @typedoc """
  A link

  `commands` holds the JSON of the commands. `resolve/1` writes it, and it is
  `nil` before. `resolve/1` also replaces a name in `slide` with the number of
  the slide.
  """
  @type t :: %__MODULE__{
          slide: pos_integer() | String.t(),
          step: pos_integer(),
          commands: String.t() | nil
        }

  @enforce_keys [:slide]
  defstruct [:slide, :commands, step: 1]

  @doc """
  Make a link from the value of the `goto` option

      iex> Expresso.Goto.new(slide: 5, step: 2)
      {:ok, %Expresso.Goto{slide: 5, step: 2}}

      iex> Expresso.Goto.new(slide: "summary")
      {:ok, %Expresso.Goto{slide: "summary", step: 1}}

      iex> Expresso.Goto.new(slide: 0)
      {:error, "goto takes [slide: n] or [slide: n, step: n], with positive integers or the name of a slide"}
  """
  @spec new(term()) :: {:ok, t()} | {:error, String.t()}
  def new(value) do
    with true <- Keyword.keyword?(value),
         [] <- Keyword.keys(value) -- [:slide, :step],
         slide when (is_integer(slide) and slide >= 1) or (is_binary(slide) and slide != "") <-
           value[:slide],
         step when is_integer(step) and step >= 1 <- Keyword.get(value, :step, 1) do
      {:ok, %__MODULE__{slide: slide, step: step}}
    else
      _invalid ->
        {:error,
         "goto takes [slide: n] or [slide: n, step: n], with positive integers or the name of a slide"}
    end
  end

  @doc """
  Return the fragment of the address of a link, such as `#5.2`

  The browser follows this address when the program does not use the click,
  such as in the handout view.
  """
  @spec href(t()) :: String.t()
  def href(%__MODULE__{slide: slide, step: step}), do: "##{slide}.#{step}"

  @doc """
  Make sure that a slide and a step of a link are in the deck

  `slides` holds the name and the maximum step number of each slide, in slide
  order. The function returns the number of the slide of the link.
  """
  @spec check(t(), [{String.t() | nil, pos_integer()}]) ::
          {:ok, pos_integer()} | {:error, String.t()}
  def check(%__MODULE__{slide: slide, step: step}, slides) do
    with {:ok, number} <- number(slide, slides) do
      case Enum.at(slides, number - 1) do
        nil ->
          {:error, "goto names the slide #{slide}, and the deck has #{length(slides)} slides"}

        {_name, max} when step > max ->
          {:error,
           "goto names the step #{step} of the slide #{inspect_slide(slide)}, and it has #{max} steps"}

        _slide ->
          {:ok, number}
      end
    end
  end

  defp number(slide, _slides) when is_integer(slide), do: {:ok, slide}

  defp number(name, slides) do
    numbers =
      for {{^name, _max}, index} <- Enum.with_index(slides, 1), do: index

    case numbers do
      [number] ->
        {:ok, number}

      [] ->
        {:error, "goto names the slide #{inspect(name)}, and no slide has that name"}

      numbers ->
        {:error,
         "goto names the slide #{inspect(name)}, and #{length(numbers)} slides have that name: " <>
           "the slides #{Enum.join(numbers, ", ")}"}
    end
  end

  defp inspect_slide(slide) when is_integer(slide), do: slide
  defp inspect_slide(name), do: inspect(name)

  @doc """
  Write the commands of each link of a deck

  The commands go to the index of the step in the list of the steps.
  `Expresso.Renderer` calls this function before it renders the deck. The
  function raises an `ArgumentError` for a link to a slide or a step that the
  deck does not have.
  """
  @spec resolve(Deck.t()) :: Deck.t()
  def resolve(%Deck{slides: slides} = deck) do
    firsts = deck |> Steps.slides() |> Enum.map(& &1.first)
    link = &commands(&1, firsts, targets(slides))

    %Deck{deck | slides: Enum.map(slides, &%{&1 | elements: walk(&1.elements || [], link)})}
  end

  @doc """
  Return the name and the maximum step number of each slide, in slide order

  `check/2` takes this list.
  """
  @spec targets([Expresso.Slide.t()]) :: [{String.t() | nil, pos_integer()}]
  def targets(slides), do: Enum.map(slides, &{&1.name, Render.max_step(&1)})

  defp commands(goto, firsts, slides) do
    case check(goto, slides) do
      {:ok, number} ->
        index = Enum.at(firsts, number - 1) + goto.step - 1

        %__MODULE__{
          goto
          | slide: number,
            commands: index |> Program.link() |> Program.json_commands()
        }

      {:error, message} ->
        raise ArgumentError, message
    end
  end

  # Each element of the tree, with the commands of its link.
  defp walk(elements, link) do
    Enum.map(elements, fn element ->
      element
      |> update(:goto, fn goto -> goto && link.(goto) end)
      |> update(:elements, &walk(&1 || [], link))
    end)
  end

  defp update(element, key, fun) when is_map_key(element, key),
    do: Map.update!(element, key, fun)

  defp update(element, _key, _fun), do: element
end
