{
  description = "libspelling — Ruby bindings";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    mine.url = "github:n-at-han-k/flake.nix";
    mine.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, mine, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = mine.lib.${system};

        gemspecFiles = pkgs.runCommand "libspelling-gemspec" { } ''
          mkdir -p $out/lib/libspelling
          cp ${./libspelling.gemspec}         $out/libspelling.gemspec
          cp ${./lib/libspelling/version.rb}  $out/lib/libspelling/version.rb
        '';

        gems = pkgs.bundlerEnv {
          name = "libspelling-gems";
          ruby = pkgs.ruby_3_4;
          gemfile = ./Gemfile;
          lockfile = ./Gemfile.lock;
          gemset = import ./gemset.nix;
          extraConfigPaths = [ "${gemspecFiles}/." ];
        };

        # The namespaces the loader needs at require time: Spelling itself, and
        # everything Spelling-1.typelib reaches transitively. It declares
        # GtkSource-5, Gtk-4.0 and Gio-2.0; GtkSource-5 names Gtk-4.0 again,
        # and Gtk-4.0 names Gdk/Gsk (both in gtk4), Pango and PangoCairo,
        # GdkPixbuf, Graphene, HarfBuzz, and cairo-1.0 -- which ships with
        # gobject-introspection and not with cairo. Miss one and the require
        # fails as "Typelib file for namespace 'X' not found".
        #
        # `makeSearchPath` would take each package's *first* output, and the
        # first output of glib, pango and gdk-pixbuf is `bin` or `man`, which
        # carries no typelibs -- hence the explicit `.out`. This is the same
        # trap the port scaffold documents.
        typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0"
          (map (drv: drv.out or drv) [
            pkgs.libspelling
            pkgs.gtksourceview5
            pkgs.gtk4
            pkgs.pango
            pkgs.gdk-pixbuf
            pkgs.graphene
            pkgs.harfbuzz
            pkgs.gobject-introspection
            pkgs.glib
          ]);
      in
      {
        devShells.default = lib.mkRubyShell {
          buildInputs = with pkgs; [
            gems
            gems.wrappedRuby

            # libspelling itself, for its typelib, and the two libraries whose
            # typelibs it names. Taking them from the same nixpkgs as the
            # gobject-introspection gem is not a tidiness point: a typelib
            # built against a different glib registers GIO a second time in
            # the process and dies with
            #   cannot register existing type 'GTlsCertificate'
            #
            # The attribute is `gtksourceview5`, whose pname is
            # `gtksourceview`; nixpkgs carries several majors under one pname,
            # so the digit belongs on the attribute and not in the package.
            libspelling
            gtksourceview5
            gtk4

            skywalking-eyes
          ];

          shellHook = /* bash */ ''
            # Spelling-1.typelib, plus every typelib it reaches. The loader
            # resolves those transitively at require time, so all of them have
            # to be on this path -- GtkSource-5 and Gtk-4.0 because Spelling-1
            # names them, and Pango, GdkPixbuf, Graphene, HarfBuzz, cairo-1.0
            # and glib's own because Gtk-4.0 names those.
            export GI_TYPELIB_PATH="${typelibPath}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"

            export BUNDLE_GEMFILE="$PWD/Gemfile"
            export BUNDLE_FROZEN=false

            export LANG="''${LANG:-C.UTF-8}"
            export LC_ALL="''${LC_ALL:-$LANG}"

            export RUBYLIB="$PWD/lib''${RUBYLIB:+:$RUBYLIB}"
          '';
        };
      }
    );
}
