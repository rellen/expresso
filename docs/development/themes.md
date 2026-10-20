# Add a built-in theme

A built-in theme is a base16 scheme of the
[Tinted Theming project](https://github.com/tinted-theming/schemes). To add one, do these
steps:

1. Download the file of the scheme from `base16/` of that repository into
   `assets/themes/`. Do not change the file. `assets/themes/LICENSE` covers it.
2. Run `mix compile`. `Expresso.Palette.Builtin` adjusts the scheme, and the compile stops
   when a color needs a change of lightness of more than 0.4. Such a scheme cannot be a
   built-in theme. Remove its file.
3. Add the theme to the table of `docs/reference/theme-option.md`, with its change and the
   dim opacities of its text and its comments. This command writes each row:

   ```sh
   mix run -e 'for n <- Expresso.Palette.Builtin.names(), p = Expresso.Palette.Builtin.fetch!(n), do: IO.puts("#{n} #{p.variant} #{Float.round(p.change, 2)} #{elem(p.dimmed.text, 0)} #{elem(p.dimmed.code_comment, 0)}")'
   ```

4. Add the still of the theme to "The gallery" of `docs/reference/theme-option.md`.
   `mix expresso.gifs` records a still for each built-in theme, with the name
   `theme-` and the name of the theme with hyphens, such as `theme-tokyo-night-storm.png`.
   This command records it:

   ```sh
   mix expresso.gifs /tmp/gifs theme-tokyo-night-storm
   ```

5. Run `mix test test/expresso/palette_test.exs test/expresso/examples_test.exs`. They
   make sure that each built-in theme meets each minimum and has its still.

The name of the theme is the name of its file, with underscores, such as
`:tokyo_night_storm` for `tokyo-night-storm.yaml`.
