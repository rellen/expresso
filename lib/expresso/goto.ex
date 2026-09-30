defmodule Expresso.Goto do
  @moduledoc """
  A link from an element to a slide and a step of the deck

  The `goto` option of a text area, an image or an item takes a keyword list,
  such as `goto: [slide: 5]` or `goto: [slide: 5, step: 2]`. The default step
  is 1. The render function of the element then puts its content into a link:

  ```html
  <a class="goto" href="#5.2" data-commands='[["goto",7]]'>
  ```

  The number 7 is the index of step 2 of slide 5 in the list of the steps. A
  click on the link in the present view runs the commands of the link with the
  program of the presenter, so the presenter goes to that step. The link is an
  HTML link, so the keyboard and a screen reader can use it. In the handout view
  and in the speaker view, the script does not run the commands.

  A link can only go to a slide and a step of the deck. Thus the handout view
  and the print show each state that a link can give. `Expresso.GotoVerifier`
  refuses a slide or a step that the deck does not have. A deck from the
  imperative API can put a struct into the `goto` field of the element, and
  `resolve/1` raises for such a slide or step.
  """

  alias Expresso.{Deck, Steps}
  alias Expresso.Overlay.Render
  alias Expresso.Presenter.Program

  @typedoc """
  A link

  `commands` holds the JSON of the commands. `resolve/1` writes it, and it is
  `nil` before.
  """
  @type t :: %__MODULE__{
          slide: pos_integer(),
          step: pos_integer(),
          commands: String.t() | nil
        }

  @enforce_keys [:slide]
  defstruct [:slide, :commands, step: 1]

  @doc """
  Make a link from the value of the `goto` option

      iex> Expresso.Goto.new(slide: 5, step: 2)
      {:ok, %Expresso.Goto{slide: 5, step: 2}}

      iex> Expresso.Goto.new(slide: 0)
      {:error, "goto takes [slide: n] or [slide: n, step: n], with positive integers"}
  """
  @spec new(term()) :: {:ok, t()} | {:error, String.t()}
  def new(value) do
    with true <- Keyword.keyword?(value),
         [] <- Keyword.keys(value) -- [:slide, :step],
         slide when is_integer(slide) and slide >= 1 <- value[:slide],
         step when is_integer(step) and step >= 1 <- Keyword.get(value, :step, 1) do
      {:ok, %__MODULE__{slide: slide, step: step}}
    else
      _invalid -> {:error, "goto takes [slide: n] or [slide: n, step: n], with positive integers"}
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

  `max_steps` holds the maximum step number of each slide, in slide order.
  """
  @spec check(t(), [pos_integer()]) :: :ok | {:error, String.t()}
  def check(%__MODULE__{slide: slide, step: step}, max_steps) do
    case Enum.at(max_steps, slide - 1) do
      nil ->
        {:error, "goto names the slide #{slide}, and the deck has #{length(max_steps)} slides"}

      max when step > max ->
        {:error, "goto names the step #{step} of the slide #{slide}, and it has #{max} steps"}

      _max ->
        :ok
    end
  end

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
    max_steps = Enum.map(slides, &Render.max_step/1)
    link = &commands(&1, firsts, max_steps)

    %Deck{deck | slides: Enum.map(slides, &%{&1 | elements: walk(&1.elements || [], link)})}
  end

  defp commands(goto, firsts, max_steps) do
    case check(goto, max_steps) do
      :ok ->
        index = Enum.at(firsts, goto.slide - 1) + goto.step - 1
        %__MODULE__{goto | commands: index |> Program.link() |> Program.json_commands()}

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
