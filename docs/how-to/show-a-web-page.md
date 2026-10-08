# Show a web page in a slide

This guide shows how to put a running web page into a slide, such as a demonstration of
your project, and how to keep the talk working with no network. For each option, see
[The embed element](../reference/embed-element.md).

## Show a page from the network

1. Take a screenshot of the page, for paper and for a room with no network.
2. Write an `embed` element with the address, a title and the screenshot:

   ```elixir
   slide "the demonstration" do
     embed "https://example.com/demo" do
       title "The demonstration"
       fallback "demo.png"
     end
   end
   ```

3. Render the deck, and open it. The page loads when its slide shows.

The screenshot shows in the handout view and on paper, and while the page loads.

## Show a local page with no network

Give the path of an HTML file in place of the address:

```elixir
embed "demo/index.html" do
  title "The demonstration"
  fallback "demo.png"
end
```

The document of the deck then holds the page, so the talk needs no network. The page must
be one file, with its scripts and its styles inside it.

In this deck, the second slide shows the local page `examples/animations/demo.html`. The
page has its style and its script inside it. `examples/animations/demo.png` is a
screenshot of the page:

```elixir
defmodule Examples.EmbedPage do
  use Expresso

  slide "the problem" do
    heading "The problem"

    text_box do
      text_area(text: "The team counts the orders by hand")
    end
  end

  slide "the demonstration" do
    heading "The demonstration"

    embed "examples/animations/demo.html" do
      title "The page of the orders"
      fallback "examples/animations/demo.png"
      interactive true
      width "60%"
    end
  end
end

Examples.EmbedPage
```

![The second slide shows the page of the orders, with its number and its button](https://raw.githubusercontent.com/rellen/expresso/media/embed-page.gif)

The page loads when its slide shows. During the talk, a click on the button adds an order,
because the embed has `interactive true`.

## Show a video

Use the `video` element. The document holds the video file one time, and the presenter
plays it in the present view. See [Show a video](show-a-video.md).

## Let the audience see you use the page

By default, a click on the page goes to the presenter, so the slides move as usual. To click
the buttons of the page during the talk, write `interactive true`:

```elixir
embed "demo/index.html" do
  title "The demonstration"
  interactive true
end
```

After a click on the page, the keys go to the page. Click the slide outside the page, and
the keys `j` and `k` move the slides again.

## Make the page fit

1. Give the ratio of the page with `aspect`, such as `aspect "4/3"`. The default is `16/9`.
2. Give the width with `width`, such as `width "60%"`.
3. Open the deck with `?check` at the end of the address. See
   [Check that a deck fits the screen](check-the-layout.md).
