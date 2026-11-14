defmodule Expresso.ExportTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Export

  doctest Expresso.Export

  @moduletag :tmp_dir

  defp box(opts \\ []),
    do: Builder.text_box([elements: [Builder.text_area(text: "A box")]] ++ opts)

  describe "print_document/2" do
    @html ~s(<!DOCTYPE html>\n<html lang="en"><head><title>t</title></head><body></body></html>)

    test "marks the pages of the slides, with the default size and no margin" do
      html = Export.print_document(@html, Export.defaults())

      assert html =~ ~s(<html data-print="slides" lang="en">)
      assert html =~ "<style>@page { size: 1920px 1080px; margin: 0; }</style></head>"
      refute html =~ "data-print-steps"
    end

    test "marks a page for each step" do
      html = Export.print_document(@html, %{Export.defaults() | pdf_steps: :all})

      assert html =~ ~s(<html data-print="slides" data-print-steps="all" lang="en">)
    end

    test "gives the handout view no mark, and the paper of the option" do
      a4 = Export.print_document(@html, %{Export.defaults() | pdf_pages: :handout})

      assert a4 =~ ~s(<html lang="en">)
      assert a4 =~ "<style>@page { size: A4 landscape; margin: 1cm; }</style></head>"

      letter =
        Export.print_document(@html, %{
          Export.defaults()
          | pdf_pages: :handout,
            pdf_paper: :letter,
            pdf_steps: :all
        })

      assert letter =~ ~s(<html data-print-steps="all" lang="en">)
      assert letter =~ "@page { size: letter landscape; margin: 1cm; }"
    end

    test "changes only the first html tag and the first end of the head" do
      html = "<html><head></head><body><pre>&lt;html&gt; </head></pre></body></html>"
      printed = Export.print_document(html, Export.defaults())

      assert printed =~ "<pre>&lt;html&gt; </head></pre>"
      assert length(String.split(printed, "@page")) == 2
    end
  end

  describe "shots/2" do
    test "gives each number the digits of the largest number" do
      slides = for number <- 1..10, do: Builder.slide("s#{number}", elements: [box()])
      steps = Builder.slide("steps", elements: for(step <- 1..12, do: box(at: [from: step])))
      deck = Builder.deck(slides ++ [steps])

      names = fn shots -> Enum.map(shots, &elem(&1, 2)) end

      assert deck |> Export.shots(:last) |> names.() |> Enum.take(2) == [
               "slide-01.png",
               "slide-02.png"
             ]

      assert deck |> Export.shots(:last) |> List.last() == {11, 12, "slide-11.png"}

      all = Export.shots(deck, :all)
      assert length(all) == 22
      assert hd(all) == {1, 1, "slide-01-step-01.png"}
      assert List.last(all) == {11, 12, "slide-11-step-12.png"}
      assert names.(all) == Enum.sort(names.(all))
    end

    test "leaves out a hidden slide, and keeps the number of each other slide" do
      deck =
        Builder.deck([
          Builder.slide("one", elements: [box()]),
          Builder.slide("backup", elements: [box()], hidden: true),
          Builder.slide("three", elements: [box()])
        ])

      assert Export.shots(deck, :last) == [{1, 1, "slide-1.png"}, {3, 1, "slide-3.png"}]
    end

    test "keeps a hidden slide with handout_hidden true" do
      deck =
        Builder.deck(
          [
            Builder.slide("one", elements: [box()]),
            Builder.slide("backup", elements: [box()], hidden: true)
          ],
          handout_hidden: true
        )

      assert Export.shots(deck, :last) == [{1, 1, "slide-1.png"}, {2, 1, "slide-2.png"}]
    end

    test "gives no file for a deck with no slide" do
      assert Export.shots(Builder.deck([]), :all) == []
    end
  end

  describe "export/4" do
    test "gives the error of the browser before it reads the deck", %{tmp_dir: dir} do
      env = %{"EXPRESSO_CHROMIUM" => Path.join(dir, "none")}
      options = %{Export.defaults() | pdf: Path.join(dir, "deck.pdf")}

      assert {:error, message} = Export.export(Path.join(dir, "no-deck.exs"), nil, options, env)
      assert message =~ "EXPRESSO_CHROMIUM gives"
      assert message =~ "that file does not exist"
      refute File.exists?(options.pdf)
    end
  end
end
