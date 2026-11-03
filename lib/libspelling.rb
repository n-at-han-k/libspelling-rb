# frozen_string_literal: true

# Released under the Apache License, Version 2.0.
# Copyright, 2026, by General Intelligence Systems.

require "gobject-introspection"

require_relative "libspelling/version"
require_relative "libspelling/loader"

# Ruby bindings for libspelling, spell checking for GtkSourceView 5.
#
# libspelling-1 is the C library GNOME Text Editor and Builder spell check
# with: a GObject front end over enchant carrying dictionary discovery,
# correction lists, the user's personal word list, and {TextBufferAdapter},
# which underlines misspellings in a GtkSourceView buffer as they are typed.
#
# Nothing here wraps a C function by hand. The library ships a GObject
# Introspection typelib describing every class, method, property and signal it
# has, and ruby-gnome's GObjectIntrospection::Loader reads that at require time
# and defines the Ruby classes from it. {Spelling::Loader} is thirty lines, most
# of them comment; what you get is the whole library, and it does not drift
# when libspelling gains API.
#
# This is how ruby-gnome itself ships gtksourceview5, libsecret and the rest.
#
# The Ruby namespace is `Spelling`, not `Libspelling`: it is the typelib's
# namespace (`Spelling-1.typelib`), and only the gem is named after the shared
# library. `Libspelling` holds nothing but {Libspelling::VERSION}.
#
# The typelib has to be findable at require time, which means the library's
# `girepository-1.0` directory on `GI_TYPELIB_PATH` or in the system default --
# along with the typelibs `Spelling-1` names, which are `GtkSource-5`,
# `Gtk-4.0` and `Gio-2.0`, and the ones those name in turn. This gem cannot
# install any of it: it is a C library artefact and belongs to the
# distribution. See the README for the package name; `flake.nix` wires up a dev
# shell that has it.
#
# One trap, paid for already: the typelib must come from the same glib build as
# the `gobject-introspection` gem. Mix two and GIO is registered twice in one
# process, which fails as `cannot register existing type 'GTlsCertificate'`.
module Spelling
  LOG_DOMAIN = "Spelling"
  GLib::Log.set_log_domain(LOG_DOMAIN)

  class Error < StandardError
  end

  loader = Loader.new(self)
  loader.load
end
