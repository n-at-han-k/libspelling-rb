# libspelling

Ruby bindings for [libspelling](https://gitlab.gnome.org/GNOME/libspelling), the
spell checker GNOME Text Editor and Builder use: a GObject front end over
enchant, plus the GtkSourceView adapter that underlines misspellings as they
are typed.

```ruby
require "libspelling"

provider = Spelling::Provider.default
provider.display_name   # => "Enchant"
provider.default_code   # => "en_GB", or nil where enchant found no dictionary

checker = Spelling::Checker.default
checker.check_word("the", -1)     # => true  (-1 means NUL-terminated)
checker.list_corrections("teh")   # => ["the", ...], or nil with no dictionary
```

The Ruby namespace is `Spelling`, not `Libspelling`: it is the namespace the
typelib declares, and only the gem is named after the shared library.

None of this needs a display or a main loop. `spelling_init` — which the loader
calls for you — registers the library's types and its enchant provider and
touches no `GdkDisplay`, so word lookups work headless and in CI.
`Spelling::TextBufferAdapter` is the exception, as it wants a real
`GtkSource::Buffer`: for that, add the
[gtksourceview5](https://rubygems.org/gems/gtksourceview5) gem and build it
inside your GTK application.

## How this works, and what it costs to install

The library ships a GObject Introspection typelib — `Spelling-1.typelib` —
describing every class, method, property and signal it has. `Spelling::Loader`
hands that to ruby-gnome's `GObjectIntrospection::Loader`, which defines the
Ruby classes from it at `require` time. The loader is thirty lines, most of them
comment.

So this gem is pure Ruby: no extension of its own, no Cargo workspace, no
per-platform binary. You get the whole library rather than the subset somebody
got round to wrapping by hand, and it does not drift when libspelling gains API.

Be precise about install, though. `gem install libspelling` still compiles C,
because `gobject-introspection` and `glib2` are themselves native extensions
built against glib, so a compiler and glib's development headers are needed.
What *this* gem adds on top is nothing: it has no build step of its own, and
those two extensions are the ones every ruby-gnome application already has,
since `gtk4` depends on them.

This is how [ruby-gnome](https://github.com/ruby-gnome/ruby-gnome) itself ships
gtksourceview5, libsecret and the rest.

## The one thing you must install

The typelib is a C-library artefact, so it belongs to your distribution and this
gem cannot install it:

| | |
|---|---|
| Debian / Ubuntu | `gir1.2-spelling-1` (the library itself is `libspelling-1-2`) |
| Fedora | `libspelling` |
| Arch | `libspelling` |
| nix | `pkgs.libspelling` |

`Spelling-1.typelib` names `GtkSource-5`, `Gtk-4.0` and `Gio-2.0`, and the
loader follows those at require time, so gtksourceview5's and gtk4's typelibs
have to be installed too — `gir1.2-gtksource-5` and `gir1.2-gtk-4.0` on Debian,
and the main packages elsewhere. Without them the require fails as
`Typelib file for namespace 'GtkSource' not found`.

If any of it is outside the default search path, point `GI_TYPELIB_PATH` at the
directories holding the typelibs. The dev shell in `flake.nix` does this.

Note the version: libspelling 0.4 ships `Spelling-1.typelib`, with a bare `1`
where most GNOME libraries would have `1.0`. That is the version string the
loader passes, and the reason it is worth reading off the installed file rather
than guessing.

**One trap worth knowing.** The typelib must come from the same glib build as
the `gobject-introspection` gem. Mixing two registers GIO twice in one process
and fails with `cannot register existing type 'GTlsCertificate'`. Under nix,
take both from one nixpkgs — and note that glib's typelibs live in its `out`
output, not the default one.

## Using it from a flake

The gem needs `Spelling-1.typelib` and everything that typelib declares, resolved
transitively by the loader at `require` time. A missing one surfaces as
`Typelib file for namespace 'X' not found`, one at a time, so the whole chain
is listed here rather than discovered by repeated failure:

- `pkgs.libspelling` — its typelib, which is where `Spelling-1.typelib` lives
- `pkgs.gtksourceview5` — GtkSource-5
- `pkgs.gtk4` — Gtk-4.0, and through it Gdk, Gsk and Graphene
- `pkgs.pango` — Pango-1.0 and PangoCairo-1.0
- `pkgs.gdk-pixbuf` — GdkPixbuf-2.0
- `pkgs.graphene` — Graphene-1.0, the viewport maths
- `pkgs.harfbuzz` — HarfBuzz-0.0
- `pkgs.gobject-introspection` — its typelib
- `pkgs.glib` — GLib-2.0, GObject-2.0 and Gio-2.0, which nearly every GNOME typelib declares

Note the `.out`: a package's default output is often `bin`, which carries no
typelibs. `makeSearchPath` takes the first output, so it has to be asked for
`out` explicitly — this is the single most common way to get a search path that
looks right and finds nothing.

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0"
        (map (drv: drv.out or drv) [ pkgs.libspelling pkgs.gtksourceview5 pkgs.gtk4 pkgs.pango pkgs.gdk-pixbuf pkgs.graphene pkgs.harfbuzz pkgs.gobject-introspection pkgs.glib ]);
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ pkgs.ruby_3_4 pkgs.bundler ] ++ [ pkgs.libspelling pkgs.gtksourceview5 pkgs.gtk4 pkgs.pango pkgs.gdk-pixbuf pkgs.graphene pkgs.harfbuzz pkgs.gobject-introspection pkgs.glib ];

        shellHook = ''
          export GI_TYPELIB_PATH="${typelibPath}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
        '';
      };
    };
}
```

Everything must come from **one** nixpkgs. A typelib built against a different
glib than the `gobject-introspection` gem registers GIO twice in the process
and fails with `cannot register existing type 'GTlsCertificate'`.

If you are packaging an application rather than entering a shell, the same
`typelibPath` goes on the wrapper:

```nix
makeWrapper ${ruby}/bin/ruby $out/bin/my-app \
  --set GI_TYPELIB_PATH "${typelibPath}"
```

## Development

```sh
nix develop
bin/test
```

The suite runs headless, which is part of what it checks.

## Releasing

```sh
gem kit release
```

That is the whole thing. It gates on the changelog having an entry for this
version, on no deprecation deadline coming due, and on a clean working tree;
then builds, pushes and tags.

There is nothing to wait for in CI. This gem is pure Ruby, so `gem build`
produces one `libspelling-X.Y.Z.gem` that is the same artefact wherever it is built —
no extension, no per-platform gems, nothing for a workflow to hand back.


## Licence

Apache-2.0. libspelling itself is LGPL-2.1-or-later; this gem links nothing and
copies no libspelling code — it reads a description of it at runtime.
