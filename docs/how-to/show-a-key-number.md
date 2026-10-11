# Show a key number

This guide shows how to put a big number on a slide, how to make it count up, and how to
show several numbers in a row. For each option, see
[The stat element](../reference/stat-element.md).

## Show numbers that count up

Write a `stat` element with the value and a `label`. The `prefix` and the `suffix` go
around the number. `count true` counts from 0 to the value when the stat shows. Put the
stats in the columns of a `columns` element to show them in a row:

```elixir
defmodule Examples.Stat do
  use Expresso

  slide "intro" do
    heading "This year"
  end

  slide "results" do
    heading "This year"

    columns do
      column do
        stat 1250 do
          label "orders"
          count true
        end
      end

      column do
        stat 98.6 do
          label "on time"
          suffix "%"
          count true
        end
      end

      column do
        stat 4.2 do
          label "revenue"
          prefix "$"
          suffix "M"
          count true
          at from: 2
        end
      end
    end
  end
end

Examples.Stat
```

![Two stats count when the slide shows, and a third stat counts at step 2](https://raw.githubusercontent.com/rellen/expresso/media/stat.gif)

The first two stats count when their slide shows. The third stat has `at from: 2`, so it
shows and counts at step 2.

## Count from a number other than 0

The `from` option gives the start of the count. Use it to show a change, such as the
orders of this year after the orders of last year:

```elixir
stat 1250 do
  label "orders, 900 last year"
  count true
  from 900
end
```

## Give a number a fixed number of decimals

The number has the decimals of its value. The `decimals` option gives a fixed number of
decimals, such as `12.50` for a price:

```elixir
stat 12.5 do
  prefix "$"
  decimals 2
  label "for each month"
end
```

`group false` removes the comma between each group of three digits, such as for a year.
