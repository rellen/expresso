defmodule Examples.TransitionCustom do
  use Expresso

  css ~S"""
  html[data-transition="wipe-down"]::view-transition-old(slide) {
    animation-name: wipe-down-old;
  }
  html[data-transition="wipe-down"]::view-transition-new(slide) {
    animation-name: wipe-down-new;
  }
  html[data-transition="wipe-down"][data-direction="back"]::view-transition-old(slide) {
    animation-name: wipe-up-old;
  }
  html[data-transition="wipe-down"][data-direction="back"]::view-transition-new(slide) {
    animation-name: wipe-up-new;
  }
  @keyframes wipe-down-old {
    from { clip-path: inset(0 0 0 0); }
    to { clip-path: inset(100% 0 0 0); }
  }
  @keyframes wipe-down-new {
    from { clip-path: inset(0 0 100% 0); }
    to { clip-path: inset(0 0 0 0); }
  }
  @keyframes wipe-up-old {
    from { clip-path: inset(0 0 0 0); }
    to { clip-path: inset(0 0 100% 0); }
  }
  @keyframes wipe-up-new {
    from { clip-path: inset(100% 0 0 0); }
    to { clip-path: inset(0 0 0 0); }
  }
  """

  transition :wipe_down

  slide "one" do
    heading "One"

    text_box do
      text_area(text: "The first slide")
    end
  end

  slide "two" do
    heading "Two"

    text_box do
      text_area(text: "The second slide")
    end
  end
end

Examples.TransitionCustom
