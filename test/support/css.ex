defmodule Expresso.Test.CSS do
  @moduledoc """
  Generators of CSS values for the property tests

  The generators follow CSS Values and Units 4, CSS Box Sizing 3 and 4, and CSS
  Cascade 5. Each value from `width/0` is a value that the `width` property
  permits. A generator makes the text of the value, because the DSL holds a
  width as a string.

  `percentage/0` makes one number and a percent sign. This is the form that
  `Expresso.Element.Image` rewrites, and `other_width/0` makes each other form.
  The `width` property takes a value that is not less than zero, so a number
  from `number/0` has no minus sign.

  The generators make no `attr()` and no `anchor-size()`. The browser of the
  floor of this project does not support these functions.
  """

  import ExUnitProperties, only: [gen: 2]
  import StreamData

  # Absolute units.
  @absolute ~w(px cm mm Q in pt pc)

  # Units of the font of the element, and units of the font of the root element.
  @font ~w(em rem ex rex ch rch ic ric lh rlh cap rcap)

  # Units of the viewport. The first part gives which viewport size the unit
  # reads, and the last part gives the axis.
  @viewport (for size <- ~w(v sv lv dv), axis <- ~w(w h i b min max) do
               size <> axis
             end)

  # Units of the query container.
  @container ~w(cqw cqh cqi cqb cqmin cqmax)

  @units @absolute ++ @font ++ @viewport ++ @container

  # Keywords of the `width` property.
  @keywords ~w(auto min-content max-content fit-content stretch)

  # Keywords that each property takes.
  @global ~w(inherit initial unset revert revert-layer)

  @doc """
  A value that the `width` property permits
  """
  @spec width() :: StreamData.t(String.t())
  def width, do: one_of([percentage(), other_width()])

  @doc """
  A value that the `width` property permits, but not one number in percent

  A value from this generator can hold a percentage inside a function, such as
  `fit-content(50%)`.
  """
  @spec other_width() :: StreamData.t(String.t())
  def other_width do
    one_of([length(), keyword(), variable(), fit_content(), math()])
  end

  @doc """
  One number and a percent sign, such as `60%`
  """
  @spec percentage() :: StreamData.t(String.t())
  def percentage, do: map(number(), &(&1 <> "%"))

  @doc """
  A CSS number, with an optional decimal part and an optional exponent
  """
  @spec number() :: StreamData.t(String.t())
  def number do
    gen all sign <- frequency([{3, constant("")}, {1, constant("+")}]),
            digits <- digits(),
            exponent <- exponent() do
      sign <> digits <> exponent
    end
  end

  @doc """
  Space characters, which a declaration permits before and after the value
  """
  @spec space() :: StreamData.t(String.t())
  def space, do: string([?\s, ?\t, ?\n], max_length: 2)

  defp digits do
    one_of([
      map(integer(0..9999), &Integer.to_string/1),
      map(tuple({integer(0..9999), integer(0..999)}), fn {whole, part} -> "#{whole}.#{part}" end),
      map(integer(0..999), &".#{&1}")
    ])
  end

  defp exponent do
    one_of([
      constant(""),
      gen all letter <- member_of(["e", "E"]),
              sign <- member_of(["", "+", "-"]),
              power <- integer(0..3) do
        letter <> sign <> Integer.to_string(power)
      end
    ])
  end

  defp length do
    gen all number <- number(), unit <- member_of(@units) do
      number <> unit
    end
  end

  defp keyword, do: member_of(@keywords ++ @global)

  defp variable do
    gen all name <- string(?a..?z, min_length: 1, max_length: 8),
            fallback <- one_of([constant(nil), length(), percentage()]) do
      if fallback, do: "var(--#{name}, #{fallback})", else: "var(--#{name})"
    end
  end

  defp fit_content do
    map(one_of([length(), percentage()]), &"fit-content(#{&1})")
  end

  # A math function, which takes a math function in each position of a value. The
  # outer value is always a function, and therefore it is not one number in
  # percent.
  defp math do
    one_of([length(), percentage(), variable()])
    |> tree(&function/1)
    |> function()
  end

  defp function(value) do
    one_of([sum(value), product(value), comparison(value), clamp(value)])
  end

  defp sum(value) do
    gen all left <- value, operator <- member_of(["+", "-"]), right <- value do
      "calc(#{left} #{operator} #{right})"
    end
  end

  defp product(value) do
    gen all left <- value, operator <- member_of(["*", "/"]), factor <- integer(1..99) do
      "calc(#{left} #{operator} #{factor})"
    end
  end

  defp comparison(value) do
    gen all name <- member_of(["min", "max"]),
            values <- list_of(value, min_length: 2, max_length: 3) do
      "#{name}(#{Enum.join(values, ", ")})"
    end
  end

  defp clamp(value) do
    gen all low <- value, middle <- value, high <- value do
      "clamp(#{low}, #{middle}, #{high})"
    end
  end
end
