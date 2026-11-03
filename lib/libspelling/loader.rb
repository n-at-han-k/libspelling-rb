# frozen_string_literal: true

# Released under the Apache License, Version 2.0.
# Copyright, 2026, by General Intelligence Systems.

module Spelling
  # Defines everything in the Spelling namespace from `Spelling-1.typelib`.
  #
  # Modelled on ruby-gnome's own loaders -- see
  # gtksourceview5/lib/gtksourceview5/loader.rb for one that has to call the
  # library's init function first, and libsecret/lib/libsecret/loader.rb for
  # one that does not. libspelling is the first kind.
  #
  # The version string is the typelib's rather than the library's release
  # number, and here the two look nothing alike: libspelling 0.4 ships
  # `Spelling-1.typelib`, so the version is "1" -- not "1.0", which is what
  # most GNOME libraries use and what would fail as `Typelib file for namespace
  # 'Spelling', version '1.0' not found`.
  class Loader < GObjectIntrospection::Loader
    def load
      self.version = "1"
      super("Spelling")
    end

    private

    # `spelling_init` has to run before anything else in the library works --
    # its own documentation says "call this function before using any other
    # libspelling functions in your applications" -- so the loader calls it
    # rather than leaving it to the caller, exactly as ruby-gnome's GtkSource
    # loader calls `gtk_source_init`. Skip it and the namespace loads and then
    # hands back nulls.
    #
    # It needs neither a display nor a main loop: it registers the library's
    # types and its enchant provider and touches no GdkDisplay, so requiring
    # this gem is safe headless, in CI and over ssh.
    def pre_load(repository, namespace)
      call_init_function(repository, namespace)
    end

    def call_init_function(repository, namespace)
      init = repository.find(namespace, "init")
      init.invoke([])
    end

    # Having called it, do not also define `Spelling.init`: a second call is
    # pointless at best, and this is what ruby-gnome's GtkSource loader does
    # with `gtk_source_init` for the same reason.
    def load_function_info(info)
      case info.name
      when "init"
        # Already called, in pre_load.
      else
        super
      end
    end

    def post_load(repository, namespace)
      require_libraries
    end

    def require_libraries
      # Nothing yet. Hand-written Ruby that improves on what the typelib gives
      # -- an each that yields, a to_s, a keyword-argument constructor -- goes
      # in files required from here, which is the convention ruby-gnome uses
      # for exactly that purpose.
    end
  end
end
