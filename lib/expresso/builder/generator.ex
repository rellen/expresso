defmodule Expresso.Builder.Generator do
  @moduledoc """
  Makes the functions of a builder from the definition of a Spark DSL

  A module that calls `use Expresso.Builder.Generator, extension: MyExtension`
  gets one function for each entity of the extension, at each level of the
  tree. The function has the name of the entity. It takes the required
  arguments of the entity, then its optional arguments, then a keyword list.
  You can leave out the optional arguments and the keyword list. The keyword
  list holds the options of the entity and its children, under the keys of the
  children, such as `elements:`.

  A function builds its struct with `Spark.Dsl.Entity.build/5`, which the
  macros of the DSL also call. Therefore the function validates the options
  with the schema of the entity, and it runs the transform of the entity. It
  also refuses a value that is not a child of the DSL. A function raises
  `ArgumentError` for an error.

  The module also gets `dsl_state/2`. It takes the entities and the options of
  the section, and it makes the state that a module of the DSL has. Then it
  runs the transformers and the verifiers of the extension on the state, in
  the order of Spark. The extension must have one section.

  A function accepts a struct under a key of the children when that key holds
  that kind of struct somewhere in the tree. The DSL is also less strict than
  its definitions: in a nested block, the macros of the outer entities stay in
  scope. The verifiers then refuse a child in a wrong place, such as a `pause`
  in a text box.

  `docs/overlays.md` gives the reasons for this design.
  """

  @doc false
  defmacro __using__(opts) do
    extension = opts |> Keyword.fetch!(:extension) |> Macro.expand(__CALLER__)
    Code.ensure_compiled!(extension)
    section = section(extension)
    entities = entities(section)
    children = children(section)

    functions = for {name, entity} <- Enum.sort(entities), do: functions(name, entity)

    # The definition of each entity, once, with the keys of its children and
    # not their definitions. A module attribute in a function body copies its
    # value into each function, and the definitions nest deeply.
    definitions =
      for {name, entity} <- entities do
        entity = %{entity | entities: for({key, _definitions} <- entity.entities, do: {key, []})}

        quote do
          defp entity(unquote(name)), do: unquote(Macro.escape(entity))
        end
      end

    section = Map.take(section, [:name, :schema, :entities])
    section = %{section | entities: Enum.map(section.entities, & &1.target)}

    quote do
      require unquote(extension)

      unquote_splicing(functions)
      unquote_splicing(definitions)

      defp children, do: unquote(Macro.escape(children))

      @doc """
      Make the state of a DSL module from the entities and the options of the section

      The function validates the options, then it runs the transformers and the
      verifiers of the extension. It returns the state and the warnings of the
      verifiers. It raises an exception for an error.
      """
      @spec dsl_state([struct()], keyword()) :: {map(), [String.t()]}
      def dsl_state(entities, opts) do
        Expresso.Builder.Generator.dsl_state(
          unquote(extension),
          unquote(Macro.escape(section)),
          __MODULE__,
          entities,
          opts
        )
      end
    end
  end

  defp section(extension) do
    case extension.sections() do
      [section] ->
        section

      sections ->
        raise ArgumentError, "the extension must have 1 section, not #{length(sections)}"
    end
  end

  # Each entity of the tree, one time for each name. An entity can come more
  # than one time: as the child of two parents, or one time for each level of
  # a recursive entity, such as a list in an item. The copies must agree on the
  # target, the arguments and the schema.
  defp entities(section) do
    section.entities
    |> descendants()
    |> Enum.group_by(& &1.name)
    |> Map.new(fn {name, [entity | _copies] = copies} ->
      if copies |> Enum.map(&{&1.target, &1.args, &1.schema}) |> Enum.uniq() |> length() > 1 do
        raise ArgumentError, "two entities have the name #{inspect(name)}"
      end

      {name, entity}
    end)
  end

  # The structs that each key of the children accepts, in the whole tree. In
  # the DSL, the macros of the outer entities stay in scope in a nested block,
  # and a child goes under the key of its own definition. Thus the DSL accepts
  # a text box in a column, although the definition of a column does not name
  # it. A function cannot know the outer entities, so it accepts each struct
  # that the key accepts somewhere in the tree.
  defp children(section) do
    for entity <- descendants(section.entities),
        {key, definitions} <- entity.entities,
        definition <- List.flatten([definitions]),
        reduce: %{} do
      children ->
        Map.update(children, key, [definition.target], &Enum.uniq([definition.target | &1]))
    end
  end

  defp descendants(entities) do
    Enum.flat_map(entities, fn entity ->
      [entity | entity.entities |> Keyword.values() |> List.flatten() |> descendants()]
    end)
  end

  # The functions of one entity, with one arity for each count of the given
  # optional arguments. The keyword list and the next optional argument can
  # have the same position, and a list in that position is the keyword list.
  # Only the arity with each argument has documentation.
  defp functions(name, entity) do
    required = for arg <- entity.args, is_atom(arg), do: arg
    optional = for arg <- entity.args, is_tuple(arg), do: elem(arg, 1)
    vars = Enum.map(required, &Macro.var(&1, __MODULE__))
    last = length(optional) + 1

    for count <- 0..last do
      given = Enum.take(optional, max(count - 1, 0))
      next = Enum.take(optional, count)
      types = List.duplicate(quote(do: term()), length(required) + count)

      doc =
        if count == last,
          do: doc(name, entity, required, optional),
          else: false

      quote do
        @doc unquote(doc)
        @spec unquote(name)(unquote_splicing(types)) :: struct()
        unquote(if count > 0, do: with_opts(name, required ++ given, vars))
        unquote(if count < last, do: without_opts(name, required ++ next, vars))
      end
    end
  end

  defp with_opts(name, names, required_vars) do
    vars =
      required_vars ++
        Enum.map(Enum.drop(names, length(required_vars)), &Macro.var(&1, __MODULE__))

    quote do
      def unquote(name)(unquote_splicing(vars), opts) when is_list(opts) do
        Expresso.Builder.Generator.build(
          entity(unquote(name)),
          Enum.zip(unquote(names), unquote(vars)) ++ opts,
          children()
        )
      end
    end
  end

  defp without_opts(name, names, required_vars) do
    vars =
      required_vars ++
        Enum.map(Enum.drop(names, length(required_vars)), &Macro.var(&1, __MODULE__))

    quote do
      def unquote(name)(unquote_splicing(vars)) do
        Expresso.Builder.Generator.build(
          entity(unquote(name)),
          Enum.zip(unquote(names), unquote(vars)),
          children()
        )
      end
    end
  end

  defp doc(name, entity, required, optional) do
    arguments =
      case Enum.map(required ++ optional, &"`#{&1}`") do
        [] -> "The function takes a keyword list."
        names -> "The function takes #{Enum.join(names, ", ")}, then a keyword list."
      end

    children =
      case entity.entities |> Keyword.keys() |> Enum.uniq() do
        [] -> ""
        [key] -> " The key `#{key}` takes the children."
        keys -> " The keys #{Enum.map_join(keys, " and ", &"`#{&1}`")} take the children."
      end

    optional =
      if optional == [],
        do: "You can leave out the keyword list.",
        else: "You can leave out the optional arguments and the keyword list."

    """
    Make the `#{name}` entity of the DSL

    #{arguments}#{children} #{optional} These are the options:

    #{Spark.Options.docs(entity.schema)}
    """
  end

  @doc false
  @spec build(Spark.Dsl.Entity.t(), keyword(), %{atom() => [module()]}) :: struct()
  def build(entity, opts, accepted) do
    keys = entity.entities |> Keyword.keys() |> Enum.uniq()
    {children, opts} = Keyword.split(opts, keys)
    children = for key <- keys, do: {key, children |> Keyword.get_values(key) |> List.flatten()}

    with :ok <- check_children(children, accepted),
         {:ok, built} <- Spark.Dsl.Entity.build(entity, opts, children, nil, nil) do
      built
    else
      {:error, error} -> raise ArgumentError, "#{entity.name}: #{message(error)}"
    end
  end

  defp check_children(children, accepted) do
    Enum.find_value(children, :ok, fn {key, values} ->
      targets = Map.get(accepted, key, [])

      case Enum.reject(values, &(is_struct(&1) and &1.__struct__ in targets)) do
        [] -> nil
        [value | _values] -> {:error, "#{describe(value)} cannot go in #{key}"}
      end
    end)
  end

  defp describe(%module{}), do: inspect(module)
  defp describe(value), do: inspect(value)

  defp message(error) when is_binary(error), do: error
  defp message(error) when is_exception(error), do: Exception.message(error)
  defp message(error), do: inspect(error)

  @doc false
  @spec dsl_state(module(), map(), module(), [struct()], keyword()) :: {map(), [String.t()]}
  def dsl_state(extension, section, module, entities, opts) do
    case Enum.reject(entities, &(is_struct(&1) and &1.__struct__ in section.entities)) do
      [] -> :ok
      [value | _values] -> raise ArgumentError, "#{describe(value)} cannot go in #{section.name}"
    end

    opts =
      case Spark.Options.validate(opts, section.schema) do
        {:ok, opts} -> opts
        {:error, error} -> raise ArgumentError, "#{section.name}: #{message(error)}"
      end

    state = %{
      [section.name] => %{entities: entities, opts: opts, opts_anno: [], section_anno: nil},
      persist: %{
        module: module,
        file: nil,
        extensions: [extension],
        spark_extensions: [extension]
      }
    }

    {state, warnings} = transform(extension, state)
    {state, warnings ++ verify(extension, state)}
  end

  defp transform(extension, state) do
    extension.transformers()
    |> Spark.Dsl.Transformer.sort()
    |> Enum.reduce({state, []}, fn transformer, {state, warnings} ->
      case transformer.transform(state) do
        :ok -> {state, warnings}
        :halt -> {state, warnings}
        {:ok, state} -> {state, warnings}
        {:warn, state, more} -> {state, warnings ++ Enum.map(List.wrap(more), &warning/1)}
        {:error, error} -> raise error
      end
    end)
  end

  defp verify(extension, state) do
    Enum.flat_map(extension.verifiers(), fn verifier ->
      case verifier.verify(state) do
        :ok -> []
        {:warn, warnings} -> warnings |> List.wrap() |> Enum.map(&warning/1)
        {:error, error} -> raise error
      end
    end)
  end

  defp warning({message, _location}), do: message
  defp warning(message), do: message
end
