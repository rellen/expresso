defmodule Expresso.Element.Diagram.D2 do
  @moduledoc """
  Draws a graph in the language of D2, and names its elements

  A `diagram` with a `.d2` file calls `draw!/2`. The function runs `d2` with
  the layout engine of the `layout` option, through
  `Expresso.Element.Diagram.Tool`, and it returns the SVG with a name for each
  shape, container and connection.

  D2 gives no `id` to a shape. It puts each shape, container and connection in
  a `g` element with one class: the key of the element in Base64, such as
  `YXBwLndlYg==` for `app.web`. The key of a connection holds its two ends and
  its index, such as `(app.api -> db)[0]`, and a connection inside a
  container has the key of the container in front, such as
  `app.(web -> api)[0]`. Therefore `name/1` gives each such `g` element an
  `id`:

  | Element | Key | Name |
  | --- | --- | --- |
  | A shape | `app.web` | `app.web` |
  | A container | `app` | `app` |
  | A connection | `(app.api -> db)[0]` | `app.api->db` |
  | A connection in a container | `app.(web -> api)[0]` | `app.web->app.api` |
  | A second connection between the same ends | `(app.api -> db)[1]` | `app.api->db:2` |

  The name of a connection has no spaces, and each end has its full key, so a
  part names a connection as the source names its ends. Each connection also
  gets the keys of its two ends, in the attributes `data-graph-from` and
  `data-graph-to`, for the `edges` option of `Expresso.Element.Diagram`.
  """

  alias Expresso.Element.Diagram.Tool

  @tool %{
    name: "D2",
    program: "d2",
    variable: "EXPRESSO_D2",
    install: "https://d2lang.com"
  }

  # The layout engines of D2 that its binary holds. The first one is the
  # default of the `layout` option.
  @layouts [:elk, :dagre]

  # The key of a connection: the key of its container, then the two ends, the
  # arrow and the index, such as `app.(web -> api)[0]`.
  @connection ~r/\A((?:.*\.)?)\((.+) (<->|->|<-|--) (.+)\)\[(\d+)\]\z/

  @doc "The layout engines of D2, for the `layout` option"
  @spec layouts() :: [atom()]
  def layouts, do: @layouts

  @doc """
  Run D2 on a source file, and return the SVG and the names

  The names are the `id` of each shape, container and connection, in the
  order of the file. The function raises an `ArgumentError` when D2 is not
  present and when D2 fails.
  """
  @spec draw!(Path.t(), atom()) :: {String.t(), [String.t()]}
  def draw!(src, layout) do
    args = &["--layout", "#{layout}", "--omit-version", "--pad", "0", src, &1]

    @tool
    |> Tool.run!(src, args)
    |> name()
  end

  @doc """
  Give each shape, container and connection of an SVG of D2 the name from its key

  The function returns the SVG and the names, in the order of the file.

      iex> svg = ~s(<svg><g class="YXBwLndlYg=="><g class="shape"></g></g></svg>)
      iex> Expresso.Element.Diagram.D2.name(svg)
      {~s(<svg><g id="app.web" class="YXBwLndlYg=="><g class="shape"></g></g></svg>), ["app.web"]}
  """
  @spec name(String.t()) :: {String.t(), [String.t()]}
  def name(svg) do
    {tree, {names, _counts}} =
      svg
      |> Floki.parse_fragment!()
      |> walk({[], %{}})

    {Floki.raw_html(tree), Enum.reverse(names)}
  end

  defp walk(nodes, acc) when is_list(nodes), do: Enum.map_reduce(nodes, acc, &walk/2)

  defp walk({"g", attrs, children}, acc) do
    {attrs, acc} =
      case {key(attrs), List.keyfind(attrs, "id", 0)} do
        {nil, _id} -> {attrs, acc}
        {key, nil} -> give_name(attrs, key, acc)
        {_key, {"id", _id}} -> {attrs, acc}
      end

    {children, acc} = walk(children, acc)
    {{"g", attrs, children}, acc}
  end

  defp walk({tag, attrs, children}, acc) when is_binary(tag) do
    {children, acc} = walk(children, acc)
    {{tag, attrs, children}, acc}
  end

  defp walk(node, acc), do: {node, acc}

  # The key of a `g` element: its one class, in Base64, when that class
  # decodes to a text. A class such as `shape` is not Base64.
  defp key(attrs) do
    with {"class", class} <- List.keyfind(attrs, "class", 0),
         [token] <- String.split(class),
         {:ok, text} <- Base.decode64(token),
         true <- String.printable?(text) do
      unescape(text)
    else
      _other -> nil
    end
  end

  defp give_name(attrs, key, {names, counts}) do
    {base, ends} = name_of(key)
    count = Map.get(counts, base, 0) + 1
    name = if count == 1, do: base, else: "#{base}:#{count}"
    {[{"id", name} | attrs] ++ ends, {[name | names], Map.put(counts, base, count)}}
  end

  # The name of a connection has its two ends with the key of their container,
  # and no spaces. The index of D2 does not go into the name, because
  # `give_name/3` counts the connections with the same ends. The function also
  # returns the attributes of the ends of a connection.
  defp name_of(key) do
    case Regex.run(@connection, key, capture: :all_but_first) do
      [container, from, arrow, to, _index] ->
        {container <> from <> arrow <> container <> to,
         [{"data-graph-from", container <> from}, {"data-graph-to", container <> to}]}

      nil ->
        {key, []}
    end
  end

  # D2 writes the `<` and the `>` of an arrow as entities in the key.
  defp unescape(text) do
    text
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace("&amp;", "&")
  end
end
