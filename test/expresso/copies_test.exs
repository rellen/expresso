defmodule Expresso.CopiesTest do
  use ExUnit.Case, async: true

  alias Expresso.{Builder, Copies}

  doctest Expresso.Copies

  test "next/0 counts from 1 in number/1, and the caller gets its count again after it" do
    assert Copies.next() == 1

    assert Copies.number(fn -> {Copies.next(), Copies.number(&Copies.next/0), Copies.next()} end) ==
             {1, 1, 2}

    assert Copies.next() == 2
  end

  test "the caller gets its count again after an exception" do
    Copies.next()

    assert_raise RuntimeError, fn ->
      Copies.number(fn ->
        Copies.next()
        raise "stop"
      end)
    end

    assert Copies.next() == 2
  end

  # The binary of Burrito and `Expresso.main/2` render a deck in different VMs.
  # Other work in the VM of `mix test`, such as the download of a NIF, takes
  # numbers of the VM first.
  test "a deck with a diagram and an arrow gives the same document after other work" do
    deck =
      Builder.deck(
        [
          Builder.slide("copies",
            elements: [
              Builder.diagram("test/fixtures/flow.svg"),
              Builder.shape(:arrow, from: ["5%", "50%"], to: ["40%", "60%"])
            ]
          )
        ],
        name: "copies"
      )

    first = Expresso.Deck.render(deck)

    Copies.next()
    System.unique_integer([:positive, :monotonic])
    System.unique_integer([:positive])

    assert Expresso.Deck.render(deck) == first
  end
end
