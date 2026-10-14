defmodule Expresso.Dsl do
  @moduledoc """
  The helpers of the transformers and the verifiers of the deck DSL

  Each transformer and each verifier of `Expresso.Extension` reads the slides
  of the deck, and it reports an error with the path of a slide. These plain
  functions do the parts that they share:

  - `slide_path/1` returns the path of a slide for an error.
  - `error/3` and `slide_error/3` make a `Spark.Error.DslError`.
  - `map_slides/2` calls a function on each slide, and it gives the first
    error the path of its slide.
  - `put_slides/2` is the one place that writes the slides back to the state
    of Spark.
  - `css_names/1` returns the names of the CSS of the deck, which
    `Expresso.CssTransformer` scans one time for each compile.

  Spark delegates the read functions of `Spark.Dsl.Verifier` to
  `Spark.Dsl.Transformer`, so each function takes the state of a transformer
  or of a verifier.
  """

  alias Shoddy.Result
  alias Spark.Dsl.Transformer
  alias Spark.Error.DslError

  @typedoc "The path of an entity or of an option in the DSL, such as `[:deck, :slide, \"intro\"]`"
  @type path :: [atom() | String.t()]

  @typedoc "A slide, or a different map with the key `:name`"
  @type slide :: %{required(:name) => String.t() | nil, optional(atom()) => term()}

  @doc """
  Return the path of a slide for an error

      iex> Expresso.Dsl.slide_path(%{name: "intro"})
      [:deck, :slide, "intro"]
      iex> Expresso.Dsl.slide_path(%{name: nil})
      [:deck, :slide]
  """
  @spec slide_path(slide()) :: path()
  def slide_path(slide), do: [:deck, :slide | List.wrap(slide.name)]

  @doc """
  Make the error of a deck module at a path of the DSL
  """
  @spec error(module(), path(), String.t()) :: DslError.t()
  def error(module, path, message),
    do: DslError.exception(module: module, message: message, path: path)

  @doc """
  Make the error of a deck module at the path of a slide
  """
  @spec slide_error(module(), slide(), String.t()) :: DslError.t()
  def slide_error(module, slide, message), do: error(module, slide_path(slide), message)

  @doc """
  Call a function on each slide of the deck, and collect the results

  `fun` returns `{:ok, value}`, `:ok` or `{:error, message}`. The function
  returns `{:ok, values}`, with `nil` for an `:ok`, or the first error as a
  `Spark.Error.DslError` with the path of its slide. It calls `fun` on no
  slide after the first error.
  """
  @spec map_slides(map(), (slide() -> {:ok, value} | :ok | {:error, String.t()})) ::
          {:ok, [value | nil]} | {:error, DslError.t()}
        when value: term()
  def map_slides(dsl_state, fun) do
    module = Transformer.get_persisted(dsl_state, :module)

    dsl_state
    |> Transformer.get_entities([:deck])
    |> Stream.map(fn slide ->
      slide |> fun.() |> Result.map_error(&slide_error(module, slide, &1))
    end)
    |> Result.collect()
  end

  @doc """
  Write the slides of the deck back to the state of Spark

  Spark gives no function that replaces each entity of a section, so this
  function writes the key `:entities` of the section `[:deck]`. It is the one
  place that knows this shape of the state.
  """
  @spec put_slides(map(), [slide()]) :: map()
  def put_slides(dsl_state, slides),
    do: Map.replace_lazy(dsl_state, [:deck], &Map.put(&1, :entities, slides))

  @doc """
  Return the names of the CSS of the deck

  `Expresso.CssTransformer` resolves and scans the `css` option one time,
  and it persists the result. The function returns `{:ok, names}` with the
  names from `Expresso.Css.scan/1`, or `{:error, message}` for a file that
  the transformer cannot read. The names do not hold the names of the theme.
  """
  @spec css_names(map()) :: {:ok, Expresso.Css.names()} | {:error, String.t()}
  def css_names(dsl_state), do: Transformer.get_persisted(dsl_state, :css_names)
end
