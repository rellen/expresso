defmodule Expresso.Presenter.Commands do
  @moduledoc """
  Makes the commands of the presenter DSL

  `Expresso.Presenter.Extension` imports these functions into a module that
  uses `Expresso.Presenter.Dsl`. Each function returns one command of
  `Expresso.Presenter.Definition`, so `step(1)` returns `{:step, 1}`. The
  section "The commands" of `Expresso.Presenter.Definition` tells what each
  command does.

  `Expresso.Presenter.Verifier` makes sure of each field and each value when
  the module compiles.
  """

  alias Expresso.Presenter.Definition

  @doc "Set a field to a value"
  @spec set(Definition.field(), term()) :: Definition.command()
  def set(field, value), do: {:set, field, value}

  @doc "Change a field from true to false, or from false to true"
  @spec toggle(Definition.field()) :: Definition.command()
  def toggle(field), do: {:toggle, field}

  @doc "Set a field to its first value"
  @spec clear(Definition.field()) :: Definition.command()
  def clear(field), do: {:clear, field}

  @doc """
  Set a field to a value of the current entry of the list of the steps

      iex> Expresso.Presenter.Commands.assign(:selected, Expresso.Presenter.Commands.entry(:slide))
      {:assign, :selected, {:entry, :slide}}
  """
  @spec assign(:selected, {:entry, :slide}) :: Definition.command()
  def assign(field, value), do: {:assign, field, value}

  @doc "Return a value of the current entry of the list of the steps, for `assign/2`"
  @spec entry(:slide) :: {:entry, :slide}
  def entry(key), do: {:entry, key}

  @doc "Add the key to a field, such as the typed digits"
  @spec append(:digits) :: Definition.command()
  def append(field), do: {:append, field}

  @doc "Move forward or back by a number of steps"
  @spec step(integer()) :: Definition.command()
  def step(count), do: {:step, count}

  @doc "Go to the step at an index in the deck, or to step 1 of `last_slide/0`"
  @spec goto(non_neg_integer() | :last_slide) :: Definition.command()
  def goto(index), do: {:goto, index}

  @doc "Go to step 1 of a slide, or of the selected slide with `:selected`"
  @spec goto_slide(pos_integer() | :selected) :: Definition.command()
  def goto_slide(slide), do: {:goto_slide, slide}

  @doc "Select a slide in the overview"
  @spec select(pos_integer() | :last_slide) :: Definition.command()
  def select(slide), do: {:select, slide}

  @doc "Move the selection in the overview by a number of slides, or by `columns/1`"
  @spec select_by(integer() | {:columns, 1 | -1}) :: Definition.command()
  def select_by(count), do: {:select_by, count}

  @doc "Set a field that holds the index of a step to the value of another such field"
  @spec copy(Definition.field(), Definition.field()) :: Definition.command()
  def copy(to, from), do: {:copy, to, from}

  @doc "Move a field that holds the index of a step by a number of steps"
  @spec move(Definition.field(), integer()) :: Definition.command()
  def move(field, count), do: {:move, field, count}

  @doc "Go to the step at the index that a field holds"
  @spec go(Definition.field()) :: Definition.command()
  def go(field), do: {:go, field}

  @doc "Go to step 1 of the slide that the typed digits give, and remove the digits"
  @spec go_typed() :: Definition.command()
  def go_typed, do: :go_typed

  @doc "Call a built-in function of the browser"
  @spec builtin(:open_speaker | :fullscreen | :reset_timer | :switch_scheme) ::
          Definition.command()
  def builtin(name), do: {:builtin, name}

  @doc """
  Return the symbol of the last slide

  `Expresso.Presenter.Program` changes it into a number for each deck.
  """
  @spec last_slide() :: :last_slide
  def last_slide, do: :last_slide

  @doc """
  Return the symbol of the number of columns of the overview, with a sign

  `Expresso.Presenter.Program` changes it into a number for each deck.
  """
  @spec columns(1 | -1) :: {:columns, 1 | -1}
  def columns(sign), do: {:columns, sign}
end
