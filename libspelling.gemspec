# frozen_string_literal: true

# Released under the Apache License, Version 2.0.
# Copyright, 2026, by General Intelligence Systems.

require_relative "lib/libspelling/version"

Gem::Specification.new do |spec|
  spec.name = "libspelling"
  spec.version = Libspelling::VERSION
  spec.authors = ["Nathan Kidd"]
  spec.email = ["nathankidd@hey.com"]
  spec.license = "Apache-2.0"

  spec.summary = "Ruby bindings for libspelling, GNOME's spell checker."
  spec.description = "libspelling for Ruby -- the spell checker GNOME Text Editor and Builder "\
    "use: dictionary discovery, correction lists, the personal word list, and the "\
    "GtkSourceView buffer adapter. Defined from its GObject Introspection typelib at require "\
    "time rather than wrapped by hand, so the binding is the whole library and does not drift "\
    "as it gains API. The Ruby namespace is Spelling."
  spec.homepage = "https://github.com/n-at-han-k/libspelling-rb"

  spec.required_ruby_version = ">= 3.3"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["documentation_uri"] = "https://n-at-han-k.github.io/libspelling-rb/"

  # The library, and nothing else: there is no extension, so there are no
  # sources to ship for one.
  #
  # LICENSE and NOTICE ship because the Apache License asks for both: section
  # 4(a) wants every recipient given a copy of the licence, and 4(d) wants the
  # attribution notices carried along with it.
  spec.files = Dir.glob(
    ["{lib}/**/*", "LICENSE", "NOTICE", "README.md", "CHANGELOG.md"],
    File::FNM_DOTMATCH,
    base: __dir__,
  )

  spec.require_paths = ["lib"]

  # GemKit::Deprecate declares a deprecation as a dated promise: the replacement, and the version the old name stops existing in.
  spec.add_dependency "gem_kit", "~> 0.2"

  # The loader. This is the whole binding: GObjectIntrospection::Loader reads
  # the typelib and defines the Spelling namespace from it. glib2 comes along as
  # its dependency and is what GLib::Log and the GObject base classes are.
  #
  # Note this does mean installing compiles C: glib2 and gobject-introspection
  # are native extensions built against glib, so a compiler and glib headers
  # are needed. This gem adds no build step of its own, and those two are what
  # every ruby-gnome application already has, since gtk4 depends on them.
  #
  # The C library itself is NOT a gem dependency and cannot be: its typelib
  # belongs to the distribution. See the README.
  spec.add_dependency "gobject-introspection", "~> 4.3"

  spec.add_development_dependency "lefthook", "~> 2.2"
end
