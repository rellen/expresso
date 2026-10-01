defmodule Expresso.Test.DeckTree do
  @moduledoc """
  Makes one deck from the DSL and from `Expresso.Builder`, for the parity tests

  A tree describes an entity as `{name, args, opts, children}`. `args` holds
  the arguments of the entity, `opts` holds its options, and `children` is a
  keyword list such as `[elements: [tree], on: [tree]]`. A deck is a keyword
  list of options and a list of slide trees.

  `dsl/3` writes a module that uses the DSL, with each option in the `do`
  block of its entity, and it compiles the module. `builder/2` calls the
  function of each entity. `slide/0` and `deck/0` are StreamData generators of
  valid decks.
  """

  import StreamData

  alias Expresso.Builder

  @typedoc "An entity, with its arguments, its options and its children"
  @type tree :: {atom(), list(), keyword(), keyword([tree()])}

  @doc "Make the deck with the DSL, in a module with the name `module`"
  @spec dsl(module(), keyword(), [tree()]) :: Expresso.Deck.t()
  def dsl(module, opts, slides) do
    body =
      Enum.map(opts, fn {key, value} -> {key, [], [Macro.escape(value)]} end) ++
        Enum.map(slides, &quoted/1)

    quoted =
      quote do
        defmodule unquote(module) do
          use Expresso
          unquote_splicing(body)
        end
      end

    [{^module, _binary}] = Code.compile_quoted(quoted)
    Expresso.parse(module)
  end

  defp quoted({name, args, opts, children}) do
    block =
      Enum.map(opts, fn {key, value} -> {key, [], [Macro.escape(value)]} end) ++
        Enum.flat_map(children, fn {_key, trees} -> Enum.map(trees, &quoted/1) end)

    args = Enum.map(args, &Macro.escape/1)

    case block do
      [] -> {name, [], args}
      _block -> {name, [], args ++ [[do: {:__block__, [], block}]]}
    end
  end

  @doc "Make the deck with the functions of `Expresso.Builder`"
  @spec builder(keyword(), [tree()]) :: Expresso.Deck.t()
  def builder(opts, slides), do: Builder.deck(Enum.map(slides, &built/1), opts)

  defp built({name, args, opts, children}) do
    children = for {key, trees} <- children, do: {key, Enum.map(trees, &built/1)}
    apply(Builder, name, args ++ [opts ++ children])
  end

  @doc "Make the tree of an entity"
  @spec entity(atom(), list(), keyword(), keyword()) :: tree()
  def entity(name, args \\ [], opts \\ [], children \\ []), do: {name, args, opts, children}

  @doc "Generate a list of valid slides"
  @spec slides() :: StreamData.t([tree()])
  def slides do
    slide()
    |> list_of(min_length: 1, max_length: 4)
    |> map(fn slides ->
      slides
      |> Enum.with_index(1)
      |> Enum.map(fn {{name, [_name], opts, children}, index} ->
        {name, ["slide #{index}"], opts, children}
      end)
    end)
  end

  @doc "Generate a valid slide"
  @spec slide() :: StreamData.t(tree())
  def slide do
    {boolean(), list_of(element(), min_length: 1, max_length: 4), boolean()}
    |> tuple()
    |> map(fn {auto_reveal, elements, pause?} ->
      elements =
        if pause? and length(elements) > 1,
          do: List.insert_at(elements, 1, entity(:pause)),
          else: elements

      entity(:slide, ["slide"], [auto_reveal: auto_reveal], elements: elements)
    end)
  end

  defp element do
    one_of([
      text_box(),
      list(),
      table(),
      code(),
      quotation(),
      columns(),
      constant(entity(:spacer))
    ])
  end

  defp at, do: member_of([[], [at: [from: :next]]])

  defp text_box do
    {at(), list_of(string(:alphanumeric, min_length: 1), min_length: 1, max_length: 2)}
    |> tuple()
    |> map(fn {at, texts} ->
      entity(:text_box, [], at, elements: Enum.map(texts, &entity(:text_area, [], text: &1)))
    end)
  end

  defp list do
    {at(), boolean(), boolean(), boolean(), integer(1..3)}
    |> tuple()
    |> map(fn {at, ordered, reveal, dim, count} ->
      items = for i <- 1..count, do: entity(:item, ["item #{i}"])
      entity(:list, [], at ++ [ordered: ordered, reveal: reveal, dim: dim], elements: items)
    end)
  end

  defp table do
    {at(), boolean(), boolean(), integer(1..3)}
    |> tuple()
    |> map(fn {at, header, reveal, count} ->
      rows = for i <- 1..count, do: entity(:row, [["a#{i}", "b#{i}"]])
      entity(:table, [], at ++ [header: header, reveal: reveal], elements: rows)
    end)
  end

  defp code do
    {at(), member_of([nil, [1, 2..3]]), boolean()}
    |> tuple()
    |> map(fn {at, reveal, dim} ->
      reveal = if reveal, do: [reveal: reveal, dim: dim], else: []
      entity(:code, ["elixir"], at ++ [text: "a = 1\nb = 2\nc = 3"] ++ reveal)
    end)
  end

  defp quotation do
    map(at(), &entity(:quotation, ["A quotation"], &1 ++ [by: "Someone"]))
  end

  defp columns do
    map(at(), fn at ->
      column = fn text ->
        entity(:column, [], [],
          elements: [entity(:text_box, [], [], elements: [entity(:text_area, [], text: text)])]
        )
      end

      entity(:columns, [], at, elements: [column.("left"), column.("right")])
    end)
  end
end
