defmodule Expresso.Renderer do
  @moduledoc """
  The renderer

  It makes one HTML document from a deck. The document holds the present view, the
  handout view, the styles, the generated rules of the overlays and the script of
  the presenter.

  The present view holds one `section` for each slide. The handout view holds one
  `section` for each step of each slide, with the notes of the speaker under each
  page. `docs/overlays.md` gives the reason for the second view.
  """

  import Temple

  use Temple.Component

  alias Expresso.Element.Footnote
  alias Expresso.Presenter.{Definition, Help, Program}

  @external_resource "./assets/style.css"

  # `Mix.Tasks.Compile.Presenter` makes the bundle from these sources before
  # this module compiles. A change to a source starts a new compile here.
  for source <- Path.wildcard("./assets/src/**/*.ts") do
    @external_resource source
  end

  @style File.read!("./assets/style.css")
  @presenter File.read!("./priv/static/presenter.js")

  defp fonts do
    Expresso.Font.css()
  end

  defp style do
    @style
  end

  # The custom properties of the theme of the deck. Paper gets the default
  # theme, because a printer gives a white sheet and a dark theme on it wastes
  # ink. `docs/reference/theme-option.md` gives the reasons.
  #
  # A theme with a light and a dark variant gives the light roles to `:root`,
  # and the dark roles to a screen that asks for a dark scheme. The key `t`
  # writes `data-scheme` on the `html` element, and that attribute wins over
  # the scheme of the screen. The rule of paper names the attribute too, so it
  # wins over each variant.
  defp theme(deck) do
    print = Expresso.Palette.Builtin.fetch!(:default)

    roles =
      case variants(deck) do
        [{nil, palette}] ->
          ":root { #{declarations(palette)} }"

        [light: light, dark: dark] ->
          ":root { #{declarations(light)} }\n" <>
            "@media (prefers-color-scheme: dark) { :root { #{declarations(dark)} } }\n" <>
            ":root[data-scheme=\"light\"] { #{declarations(light)} }\n" <>
            ":root[data-scheme=\"dark\"] { #{declarations(dark)} }"
      end

    roles <> "\n@media print { :root, :root[data-scheme] { #{declarations(print)} } }"
  end

  defp variants(deck), do: Expresso.Palette.variants((deck.metadata || %{})[:theme])

  defp declarations(palette), do: Expresso.Palette.declarations(palette)

  # The presenter changes the variant with the key `t` only in a document with two variants.
  defp two_variants?(deck), do: length(variants(deck)) == 2

  defp deck_css(deck) do
    metadata = deck.metadata || %{}

    case Expresso.Css.render(metadata[:css], metadata[:root]) do
      {:ok, ""} -> nil
      {:ok, css} -> Expresso.Css.escape(css)
      {:error, message} -> raise ArgumentError, message
    end
  end

  defp presenter do
    @presenter
  end

  # The commands of the page of the last step of a slide. In the overview, a
  # click on the page goes to step 1 of the slide.
  defp page_commands(slide),
    do: slide.metadata.slide_number |> Program.element() |> Program.json_commands()

  # The menu of the slides and their steps. `m` shows it. A row of a slide
  # holds a small copy of the last step of the slide, and the overlay rules
  # show that step because the copy is a `section` with `data-step`. A row of
  # a step holds its number and its label. A slide with one step and no label
  # gets `data-single` on the row of its step, and the style sheet puts that
  # row over the row of the slide. A click on a row runs its
  # `data-commands`, which go to the step and close the menu. The marks of the
  # program write `data-cursor` and `data-current` on the rows of the steps.
  defp menu(assigns) do
    temple do
      nav id: "menu", aria_label: "Slides and steps" do
        ol do
          for {slide, %{first: first, steps: steps}} <-
                Enum.zip(@deck.slides, Expresso.Steps.slides(@deck)),
              labels = slide.metadata[:labels] || %{} do
            li class: "menu-group" do
              div class: "menu-slide", data_commands: menu_commands(first) do
                section class: Expresso.Element.classes("menu-thumb", slide.metadata[:class]),
                        data_step: steps,
                        aria_hidden: "true" do
                  c(&slide_parts/1, deck: @deck, slide: slide)
                end

                span class: "menu-number" do
                  slide.metadata.slide_number
                end

                span class: "menu-name" do
                  menu_name(slide)
                end
              end

              ol class: "menu-steps" do
                for step <- 1..steps//1 do
                  li class: "menu-step",
                     data_index: first + step - 1,
                     data_single: steps == 1 and labels[step] == nil,
                     data_commands: menu_commands(first + step - 1) do
                    span class: "menu-number" do
                      step
                    end

                    span class: "menu-label" do
                      labels[step] || ""
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  defp menu_commands(index), do: index |> Program.menu() |> Program.json_commands()

  # The name of a slide in the menu: its heading, its name, or its number.
  defp menu_name(slide),
    do: slide.metadata[:heading] || slide.name || "Slide #{slide.metadata.slide_number}"

  # The columns of the overview and the zoom of each page in it. Each page is as
  # large as the window, and the style sheet scales it with `zoom`. The padding
  # and the gaps of the grid are 1vw wide and 1vh high. The number of rows is not
  # more than the number of columns, so a zoom that fits the width also fits the
  # height.
  defp overview_sizes(deck) do
    columns = deck.slides |> length() |> Program.columns()
    zoom = (98 - (columns - 1)) / (100 * columns)
    "--overview-columns: #{columns}; --overview-zoom: #{:erlang.float_to_binary(zoom, [:short])};"
  end

  # The value of `data-progress` on the `body`. A deck from the imperative API
  # can have no metadata, and it then shows the progress bar.
  defp progress(deck) do
    case deck.metadata do
      %{progress: false} -> "false"
      _other -> "true"
    end
  end

  # The value of `data-print-notes` on the `body`. The notes stay in the
  # document with either value, because the speaker view reads them there.
  defp print_notes(deck) do
    case deck.metadata do
      %{print_notes: false} -> "false"
      _other -> "true"
    end
  end

  # The text of the number of a slide, such as "3 / 12", or nil. A deck shows
  # the numbers only with `slide_numbers: true`, and slide 1 shows no number.
  defp slide_number(deck, slide) do
    number = slide.metadata.slide_number

    case deck.metadata do
      %{slide_numbers: true} when number > 1 -> "#{number} / #{length(deck.slides)}"
      _other -> nil
    end
  end

  # `Expresso.Deck.render/1` writes the doctype. Floki drops a doctype node, and the
  # deck function writes this tree with Floki. Therefore the doctype cannot come
  # from this function.
  #
  # The two style sheets are files of this repository, the rules of the token
  # classes come from Makeup, and the presenter bundle comes from files of this
  # repository. The renderer reads them at compile time, and no input of a user
  # can change them. The generated style block comes from the deck, and
  # `Expresso.Overlay.Render.style/1` escapes each value of it. The list of the
  # steps and the program also come from the deck, and `Expresso.Steps.json/1`
  # and `Expresso.Presenter.Program.json/1` escape each `<`.
  # The three parts of a slide. The present view and the handout view show the
  # same parts, and each view gives its own container.
  defp slide_parts(assigns) do
    temple do
      div style: "width: 100%; flex-grow: 0; display: flex;justify-content: center;" do
        c(&Expresso.Template.render_deck_template(:header, &1), deck: @deck, slide: @slide)
      end

      div style: "width: 100%; flex-grow: 1; display: flex; justify-content: center;" do
        c(&Expresso.Template.render_slide_template/1, deck: @deck, slide: @slide)
      end

      # The footnotes of the slide go under the slide template, so each
      # template gets them. `Expresso.Element.Footnote` gives the reasons.
      c(&footnotes/1, footnotes: Footnote.of_slide(@slide))

      # The number of the slide goes into the row of the footer, so a page of
      # the handout view shows it above the notes. The style sheet puts it in
      # the right corner of that row.
      div style:
            "width: 100%; flex-grow: 0; flex-shrink: 0; display: flex;justify-content: center; position: relative;" do
        c(&Expresso.Template.render_deck_template(:footer, &1), deck: @deck, slide: @slide)

        if number = slide_number(@deck, @slide) do
          span class: "slide-number" do
            number
          end
        end
      end
    end
  end

  defp footnotes(assigns) do
    temple do
      if @footnotes != [] do
        ol class: "footnotes" do
          for footnote <- @footnotes do
            c(&Footnote.render/1,
              rest!: footnote |> Footnote.get_assigns() |> Map.put(:class, footnote.class)
            )
          end
        end
      end
    end
  end

  # The page of the sources: the footnotes of each slide, after the last page
  # of the handout view. The style sheet hides it in the speaker view and in
  # the overview. A deck with no footnote gets no page.
  defp sources(assigns) do
    temple do
      if @slides != [] do
        section class: "sources" do
          h2 do
            "Sources"
          end

          for {slide, footnotes} <- @slides do
            c(&slide_sources/1, slide: slide, footnotes: footnotes)
          end
        end
      end
    end
  end

  defp slide_sources(assigns) do
    temple do
      h3 do
        "#{@slide.metadata.slide_number}. #{menu_name(@slide)}"
      end

      ol do
        for footnote <- @footnotes do
          li do
            div do
              Footnote.html(footnote)
            end
          end
        end
      end
    end
  end

  # The slides with footnotes, each with its footnotes.
  defp footnoted(deck) do
    for slide <- deck.slides,
        footnotes = Footnote.of_slide(slide),
        footnotes != [],
        do: {slide, footnotes}
  end

  # The sources of the embeds. The presenter gives a frame its source when its
  # slide shows, so each page loads one time. A deck with no embed has no such
  # element. `Expresso.Element.Embed.json/1` escapes each `<`.
  # sobelow_skip ["XSS.Raw"]
  defp embeds(assigns) do
    temple do
      if json = Expresso.Element.Embed.json(@deck) do
        script id: "expresso-embeds", type: "application/json" do
          Phoenix.HTML.raw(json)
        end
      end
    end
  end

  # The videos, one time each. The presenter gives a video its source when it
  # plays. A deck with no video has no such element.
  # `Expresso.Element.Video.json/1` escapes each `<`.
  # sobelow_skip ["XSS.Raw"]
  defp videos(assigns) do
    temple do
      if json = Expresso.Element.Video.json(@deck) do
        script id: "expresso-videos", type: "application/json" do
          Phoenix.HTML.raw(json)
        end
      end
    end
  end

  # The list of keys: a `dialog` with a search field, and a section for each
  # mode. The key `?` or `/` opens it, and the script opens the section of the
  # mode under it. Each row holds its words in lower case, and the filter of
  # the script looks for the typed text in them. Temple escapes each text.
  defp help_lists(assigns) do
    temple do
      dialog id: "help", aria_labelledby: "help-title", closedby: "any" do
        h2 id: "help-title", class: "help-hidden" do
          "Keys and commands"
        end

        label class: "help-search" do
          span class: "help-hidden" do
            "Search the keys"
          end

          # A field of the type `search` clears its text at the first
          # `Escape`, and the dialog then stays open. A field of text closes it.
          input type: "text",
                id: "help-filter",
                role: "searchbox",
                enterkeyhint: "search",
                autocomplete: "off",
                autofocus: true,
                placeholder: "Type a key or a word, such as dark or next"
        end

        div class: "help-body" do
          for {mode, groups} <- @groups do
            details data_mode: mode do
              summary do
                span class: "help-mode" do
                  Help.title(mode)
                end

                span class: "help-count" do
                  count(groups)
                end
              end

              for {heading, rows} <- groups do
                c(&help_group/1, heading: heading, rows: rows)
              end
            end
          end

          p class: "help-none" do
            "No key matches the search."
          end
        end

        p class: "help-footer" do
          kbd(do: "Esc")
          " closes the list."
        end
      end
    end
  end

  # A group holds its heading and its rows, so the style sheet hides the two
  # together when no row matches the search.
  defp help_group(assigns) do
    temple do
      div class: "help-set" do
        if @heading do
          h3 class: "help-group" do
            @heading
          end
        end

        ul do
          for row <- @rows do
            li data_words: row.words do
              c(&help_keys/1, row: row)

              span class: "help-action" do
                row.text
              end
            end
          end
        end
      end
    end
  end

  # A row with a label shows the label in place of its keys.
  defp help_keys(%{row: %{label: label}} = assigns) when is_binary(label) do
    temple do
      span class: "help-keys" do
        span class: "help-label" do
          @row.label
        end
      end
    end
  end

  defp help_keys(assigns) do
    temple do
      span class: "help-keys" do
        for key <- @row.keys do
          kbd(do: key)
        end
      end
    end
  end

  defp count(groups) do
    case groups |> Enum.map(fn {_heading, rows} -> length(rows) end) |> Enum.sum() do
      1 -> "1 row"
      rows -> "#{rows} rows"
    end
  end

  @doc """
  Make the HTML tree of a deck

  The assigns hold the deck under the key `deck`. `Expresso.Deck.render/1` calls
  this function, and it writes the tree and adds the doctype. The function
  dims the lines of each code element with the `highlight` option with
  `Expresso.Element.Code.spotlight/1` first. It gives each element its identity
  with `Expresso.Overlay.Render.identify/1` next. Then `Expresso.Goto.resolve/1` writes the commands of each link, and
  it raises for a link to a slide or a step that the deck does not have.
  """
  @spec render(map() | keyword()) :: Phoenix.HTML.safe()
  # Sobelow reports `XSS.HTML` for the attribute of the `html` element. The
  # value of that attribute is the text "en" in this module, and no input of a
  # user reaches it.
  # sobelow_skip ["XSS.Raw", "XSS.HTML"]
  def render(assigns) do
    assigns =
      assigns
      |> Map.new()
      |> Map.update!(
        :deck,
        &(&1
          |> Expresso.Element.Code.spotlight()
          |> Expresso.Element.Diagram.place()
          |> Expresso.Element.Embed.number()
          |> Expresso.Element.Video.number()
          |> Expresso.Overlay.Render.identify()
          |> Expresso.Goto.resolve())
      )

    assigns = Map.put(assigns, :program, Program.compile(Definition.presenter(), assigns.deck))

    temple do
      # The language of the document. A screen reader reads the attribute, and
      # it selects a voice from the value. Each deck takes English at this
      # time, and a later version can give the `deck` section an option.
      html lang: "en", data_variants: two_variants?(@deck) do
        head do
          # The encoding goes in front of each other element of the head. A
          # browser reads the first 1024 bytes of a document for it. Without
          # this element the browser makes a guess, and the guess comes from
          # the locale of the person. Elixir writes UTF-8 only.
          meta charset: "utf-8"

          # A deck has no name when the DSL gives no `name` option, or when
          # `Expresso.Deck.new/3` takes `nil`. The `title` element is necessary,
          # so the renderer writes it with no text.
          title(do: @deck.name || "")

          style do
            Phoenix.HTML.raw(fonts())
          end

          style do
            Phoenix.HTML.raw(theme(@deck) <> "\n" <> style())
          end

          style do
            Phoenix.HTML.raw(Expresso.Highlight.stylesheet())
          end

          style do
            Phoenix.HTML.raw(Expresso.Overlay.Render.style(@deck))
          end

          if css = deck_css(@deck) do
            style do
              Phoenix.HTML.raw(css)
            end
          end
        end

        body style: "min-height: 100vh; width: 100%; margin: 0px; #{overview_sizes(@deck)}",
             data_view: "present",
             data_progress: progress(@deck),
             data_print_notes: print_notes(@deck) do
          div class: "screen" do
            for {slide, index} <- Enum.with_index(@deck.slides) do
              section id: "slide-#{slide.metadata.slide_number}",
                      class: Expresso.Element.classes("slide", slide.metadata[:class]),
                      data_step: 1,
                      data_max_step: Expresso.Overlay.Render.max_step(slide),
                      style:
                        "height: 100%; display: #{if index == 0, do: "flex", else: "none"}; flex-direction: column; justify-content: stretch" do
                c(&slide_parts/1, deck: @deck, slide: slide)
              end
            end
          end

          div class: "handout" do
            # Each step gets a page, because the speaker view shows the page of
            # each step. A page that the handout option does not select gets
            # `data-omit`, and the style sheet hides it in the handout view and
            # on paper. The overview shows the page of the last step of each
            # slide, which has `data-thumbnail`, and a click on that page runs
            # its `data-commands`. `data-index` is the index of the step in the
            # list of the steps, and the speaker view marks pages by it.
            for {slide, %{first: first}} <- Enum.zip(@deck.slides, Expresso.Steps.slides(@deck)),
                printed <- [Expresso.Handout.printed(@deck, slide)],
                max = Expresso.Overlay.Render.max_step(slide),
                step <- 1..max//1 do
              section class: Expresso.Element.classes("handout-page", slide.metadata[:class]),
                      data_step: step,
                      data_slide: slide.metadata.slide_number,
                      data_index: first + step - 1,
                      data_omit: step not in printed,
                      data_thumbnail: step == max,
                      data_commands: step == max && page_commands(slide) do
                c(&slide_parts/1, deck: @deck, slide: slide)

                # The notes of the speaker go under each page of the slide, and
                # the present view does not show them. The text is not HTML.
                if notes = slide.metadata[:notes] do
                  aside class: "notes" do
                    div do
                      notes
                    end
                  end
                end
              end
            end

            c(&sources/1, slides: footnoted(@deck))

            # The four elements of the speaker view. They go into the handout
            # view, because the style sheet places them in the grid of that
            # view. The style sheet hides them in each other view and on paper.
            for id <- ~w(speaker-notes speaker-position speaker-timer speaker-left) do
              div id: id do
              end
            end
          end

          # The progress bar of the present view. The style sheet sets its width
          # from `--fraction`, which the script writes on the `body`.
          div id: "progress" do
          end

          c(&menu/1, deck: @deck)

          c(&help_lists/1, groups: Help.groups(Definition.presenter()))

          # The list of the steps. The presenter reads it at load, so it comes
          # before the script. `Expresso.Steps.json/1` escapes each `<`.
          script id: "expresso-deck", type: "application/json" do
            Phoenix.HTML.raw(Expresso.Steps.json(@deck))
          end

          # The program of the presenter for this deck. The interpreter of the
          # script runs it. `Expresso.Presenter.Program.json/1` escapes each `<`.
          script id: "expresso-program", type: "application/json" do
            Phoenix.HTML.raw(Program.json(@program))
          end

          c(&embeds/1, deck: @deck)

          c(&videos/1, deck: @deck)

          script do
            Phoenix.HTML.raw(presenter())
          end
        end
      end
    end
  end
end
