# The embed element

The `embed` element shows a web page in a slide: a page from the network, or a local HTML
file. The page runs in a frame, so a live demonstration can be part of the talk.

```elixir
slide "the factory" do
  embed "https://rellen.github.io/iso-factories/line-4/index.html" do
    title "Line 4, the running factory"
    fallback "line4.png"
    width "62%"
  end
end
```

`Expresso.Builder` takes the same options, such as
`embed("demo.html", title: "The demonstration", fallback: "demo.png")`.

## The options

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | An address that starts with `https://` or `http://`, or the path of a local `.html` or `.htm` file | The page. A path is relative to [the root option](root-option.md) of the deck, or to the working directory of the command. |
| `title` | A string, required | The name of the page for a screen reader. The fallback image gets it as its `alt` text. |
| `fallback` | The path of an image | The image that shows on paper, in the handout view, in the overview and while the page loads. |
| `width` | A CSS width, such as `"900px"` or `"80%"` | The width of the page. A percentage is a part of the width of the slide. The default is `80%`. |
| `aspect` | Two numbers with a slash, such as `"16/9"` | The ratio of the width to the height. The default is `16/9`. |
| `interactive` | `true` or `false` | Let the page take clicks and keys. The default is `false`. |
| `class` | CSS class names | See [the class option](class-option.md). |

The element also takes the overlay options, such as `at` and `effect`. See
[the overlay options](overlay-options.md).

The compiler gives an error for a first argument that is not an address or the path of an
HTML file, for an `aspect` that is not a ratio, and for an element with no `title`. The
render gives an error for a local file that it cannot read.

## When the page loads

| View | The page |
| --- | --- |
| The present view | The page loads when its slide shows for the first time, after the load of the deck. It then stays loaded, and it keeps its state when the slide shows again. |
| The speaker view | No page loads. The pages show the fallback. |
| The handout view, the overview and paper | No page loads. Each page shows the fallback. |

Without a `fallback`, each of these places shows a box with the title, and with the address
for a page of the network. The fallback also shows under the frame while the page loads.

A browser with no network loads no address, and the fallback stays. When the network comes
back, the page loads. A page that the network does not deliver shows the error page of the
browser, because a deck cannot read a page of a different origin.

## A local file

A local file goes into the document, so the deck stays one file, and the page works with
no network. The page must be one file: a script, a style sheet or an image that it loads by
a relative path does not load. The watch mode renders the deck again after a change to the
file.

A data URI holds a file inside the page, such as a WebM video in
`<video src="data:video/webm;base64,...">`. The document then holds the video one time.
For the steps, see "Show a video" in [Show a web page in a slide](../how-to/show-a-web-page.md).

## Clicks, keys and the focus

| `interactive` | A click on the page | A key |
| --- | --- | --- |
| `false` | Goes to the presenter, as a click on the slide does. | Goes to the presenter. The key Tab does not go into the page. |
| `true` | Goes to the page. | Goes to the page after a click on it. Click the slide outside the page to give the keys to the presenter again. |

## The sandbox

The frame has a `sandbox` attribute and `referrerpolicy="no-referrer"`:

| Page | Sandbox | Result |
| --- | --- | --- |
| An address | `allow-scripts allow-same-origin` | The page runs its scripts, and it keeps its own origin, so it keeps its storage. |
| A local file | `allow-scripts` | The page runs its scripts. It has no origin of its own, so it cannot read the deck. |

A page cannot open a window, submit a form or change the address of the deck. A site can
refuse to show in a frame of a different site. The frame then shows the error page
of the browser.
