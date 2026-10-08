defmodule Expresso.Presenter.Default do
  @moduledoc """
  The definition of the presenter, in the presenter DSL

  Each document holds the program that `Expresso.Presenter.Program` makes from
  this definition. The modes come in the order that the interpreter examines
  them: the black screen, the list of keys, the overview, then the views. The
  bindings of a mode come in the order of the rows in its list of keys. The
  projections tell how the script writes a state to the document.
  `Expresso.Presenter.Definition` tells what each part of a mode does, and
  `Expresso.Presenter.Projection` tells what each projection does.
  """

  use Expresso.Presenter.Dsl

  @digits ~w(0 1 2 3 4 5 6 7 8 9)
  @help "This list of keys. The next key closes it."

  state index: 0,
        view: :present,
        blank: false,
        help: false,
        digits: "",
        overview: false,
        selected: 1,
        progress: true,
        every: false,
        undim: false,
        menu: false,
        cursor: 0

  sync [:blank, :undim]
  reset [:undim]

  # The attributes of the `body`. The style sheet reads them.
  attribute :view, "data-view"
  attribute :blank, "data-blank", flag: true
  attribute :progress, "data-progress"
  attribute :every, "data-every"
  attribute :overview, "data-overview", flag: true
  attribute :help, "data-help", flag: true
  attribute :digits, "data-digits"
  attribute :undim, "data-undim", flag: true
  attribute :menu, "data-menu", flag: true

  # The style sheet sets the width of the progress bar from the part of the
  # deck before the current step.
  property "--fraction", :fraction

  # The overview marks the page of the selected slide. The speaker view marks
  # the page of the current step and the page of the next step.
  mark "data-selected", ".handout-page[data-thumbnail]", :slide, [{"", :selected, 0}]
  mark "data-speaker", ".handout-page", :index, [{"current", :index, 0}, {"next", :index, 1}]

  # The menu marks the row of its cursor and the row of the current step. The
  # script keeps the row of the cursor in view.
  mark "data-cursor", ".menu-step[data-index]", :index, [{"", :cursor, 0}], scroll: true
  mark "data-current", ".menu-step[data-index]", :index, [{"", :index, 0}]

  # A black screen or the list of keys closes at the next event, and the event
  # does no more.
  mode :blank, match: [blank: true], any: set(:blank, false)
  mode :help, match: [help: true], any: set(:help, false)

  mode :overview do
    match overview: true
    element true

    key "?", set(:help, true), @help
    key ["j", "ArrowRight", "PageDown", " "], select_by(1), "Select the next slide"
    key ["k", "ArrowLeft", "PageUp"], select_by(-1), "Select the previous slide"
    key "ArrowDown", select_by(columns(1)), "Select the slide below"
    key "ArrowUp", select_by(columns(-1)), "Select the slide above"
    key "Home", select(1), "Select the first slide"
    key "End", select(last_slide()), "Select the last slide"
    key "Enter", [goto_slide(:selected), set(:overview, false)], "Step 1 of the selected slide"
    event :element, [], "Step 1 of that slide", label: "Click or tap a slide"
    key ["o", "Escape"], set(:overview, false), "Close the overview. The step does not change."
  end

  # The menu lists each slide with its steps. The cursor starts at the current
  # step, and the step changes only at `Enter` or at a click.
  mode :menu do
    match menu: true
    element true

    key "?", set(:help, true), @help
    key ["j", "ArrowDown"], move(:cursor, 1), "Move the cursor to the next step"
    key ["k", "ArrowUp"], move(:cursor, -1), "Move the cursor to the previous step"
    key "Enter", [go(:cursor), set(:menu, false)], "The step of the cursor"
    event :element, [], "That step", label: "Click or tap a step or a slide"
    key ["m", "Escape"], set(:menu, false), "Close the menu. The step does not change."
  end

  # Each key except a digit and `Enter` removes the typed digits. A click on a
  # link of `Expresso.Goto` runs the commands of the link.
  mode :present do
    match view: :present
    each clear(:digits)
    other true
    element true

    key ["j", "ArrowRight", "ArrowDown", "PageDown", " "],
        step(1),
        "Next step, or the first step of the next slide"

    key ["k", "ArrowLeft", "ArrowUp", "PageUp"],
        step(-1),
        "Previous step, or the last step of the previous slide"

    key "Home", goto(0), "First slide"
    key "End", goto(last_slide()), "Step 1 of the last slide"
    key @digits, append(:digits), "Type a slide number", label: "0 to 9", each: false
    key "Enter", go_typed(), "Step 1 of the slide that you typed", each: false
    key "b", set(:blank, true), "Black screen. The next key shows the slide again."
    key "p", set(:view, :handout), "Handout view"
    key "s", builtin(:open_speaker), "Speaker view, in a second window"
    key "f", builtin(:fullscreen), "Full screen on or off"
    key "g", toggle(:progress), "Progress bar on or off"
    key "t", builtin(:switch_scheme), "Light or dark variant of the theme, in the two windows"
    key "d", toggle(:undim), "Code in full color until the next step, in the two windows"

    event [click: :right, swipe: :left], step(1), "Next step",
      label: "Click or tap the right two thirds, or swipe left"

    event [click: :left_third, swipe: :right], step(-1), "Previous step",
      label: "Click or tap the left third, or swipe right"

    event :element, [], "The slide and the step of the link", label: "Click or tap a link"

    key "o",
        [set(:overview, true), assign(:selected, entry(:slide))],
        "Overview of the slides. Only this window shows it."

    key "m",
        [set(:menu, true), copy(:cursor, :index)],
        "Menu of the slides and their steps. Only this window shows it."

    key "?", set(:help, true), @help
  end

  # The speaker view knows the keys of the present view, except `p`, `s` and
  # `g`. It also knows `r`.
  mode :speaker do
    match view: :speaker
    each clear(:digits)
    other true

    key ["j", "ArrowRight", "ArrowDown", "PageDown", " "],
        step(1),
        "Next step, or the first step of the next slide"

    key ["k", "ArrowLeft", "ArrowUp", "PageUp"],
        step(-1),
        "Previous step, or the last step of the previous slide"

    key "Home", goto(0), "First slide"
    key "End", goto(last_slide()), "Step 1 of the last slide"
    key @digits, append(:digits), "Type a slide number", label: "0 to 9", each: false
    key "Enter", go_typed(), "Step 1 of the slide that you typed", each: false
    key "b", set(:blank, true), "Black screen. The next key shows the slide again."

    key "r", builtin(:reset_timer), "Set the timer to 0:00"
    key "f", builtin(:fullscreen), "Full screen on or off"
    key "t", builtin(:switch_scheme), "Light or dark variant of the theme, in the two windows"
    key "d", toggle(:undim), "Code in full color until the next step, in the two windows"

    event [click: :right, swipe: :left], step(1), "Next step",
      label: "Click or tap the right two thirds, or swipe left"

    event [click: :left_third, swipe: :right], step(-1), "Previous step",
      label: "Click or tap the left third, or swipe right"

    key "o",
        [set(:overview, true), assign(:selected, entry(:slide))],
        "Overview of the slides. Only this window shows it."

    key "m",
        [set(:menu, true), copy(:cursor, :index)],
        "Menu of the slides and their steps. Only this window shows it."

    key "?", set(:help, true), @help
  end

  # The handout view knows only these keys. The browser gets each other key,
  # so the arrow keys and the space bar scroll the pages.
  mode :handout do
    match view: :handout
    each clear(:digits)
    other true

    key "j", step(1), "Next step. The present view then shows it."
    key "k", step(-1), "Previous step. The present view then shows it."
    key "p", set(:view, :present), "Present view"

    key "a",
        toggle(:every),
        "Every step, or the steps of the handout option. A print shows the same."

    key "?", set(:help, true), @help
  end
end
