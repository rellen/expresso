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

## Show a video

Expresso has no video element. A local page with the video inside it works, and the
document holds the video one time. An `image` with a GIF is larger, and the document holds
a copy of it for each view.

1. Save the video as a WebM file, such as `demo/demo.webm`. A browser plays WebM with no
   plugin.
2. Take a screenshot of the video as a PNG file, such as `demo/demo.png`, for paper.
3. Make a page that holds the video as a data URI:

   ```sh
   printf '<!doctype html>\n<video src="data:video/webm;base64,%s" autoplay loop muted playsinline style="width:100%%"></video>\n' \
     "$(base64 < demo/demo.webm | tr -d '\n')" > demo/video.html
   ```

4. Write an `embed` element with the page and the screenshot:

   ```elixir
   embed "demo/video.html" do
     title "The demonstration"
     fallback "demo/demo.png"
   end
   ```

The video starts when its slide shows, and it plays again from the start at the end. A
browser starts a video automatically only when it has no sound, so `autoplay` needs
`muted`. The handout view and paper show the screenshot.

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
