# frozen_string_literal: true

# Released under the Apache License, Version 2.0.
# Copyright, 2026, by General Intelligence Systems.

require "libspelling"

describe Spelling do
  it "defines the namespace from the typelib" do
    # Spelling-1 is a small namespace -- five types and no enums -- so the
    # number here is small. What it rules out is the loader half-running: it
    # cannot reach six without the typelib's own types, since only Error,
    # LOG_DOMAIN and Loader come from this gem.
    expect(Spelling.constants.size).to be > 6
  end

  it "defines the classes a caller actually reaches for" do
    expect(Spelling.const_defined?(:Checker)).to be == true
    expect(Spelling.const_defined?(:Dictionary)).to be == true
    expect(Spelling.const_defined?(:Language)).to be == true
    expect(Spelling.const_defined?(:Provider)).to be == true
    expect(Spelling.const_defined?(:TextBufferAdapter)).to be == true
  end

  it "makes them GObject classes rather than bare Ruby ones" do
    expect(Spelling::Checker.ancestors).to be(:include?, GLib::Object)
    expect(Spelling::TextBufferAdapter.ancestors).to be(:include?, GLib::Object)
  end

  # A loader that registered the types but no methods would satisfy every
  # assertion above, so this is the one that catches a half-loaded namespace.
  it "maps the library's methods onto the classes, not just constants" do
    checker = Spelling::Checker.instance_methods - GLib::Object.instance_methods

    expect(checker).to be(:include?, :check_word)
    expect(checker).to be(:include?, :list_corrections)
    expect(checker).to be(:include?, :language)
    expect(checker.size).to be > 5

    dictionary = Spelling::Dictionary.instance_methods - GLib::Object.instance_methods

    expect(dictionary).to be(:include?, :contains_word)
    expect(dictionary).to be(:include?, :list_corrections)
  end

  # The loader calls spelling_init in pre_load, which is why every assertion
  # below works at all, and then drops the function rather than exposing a
  # second call. ruby-gnome's GtkSource loader does the same with
  # gtk_source_init.
  it "has already run the library's init, and does not expose it again" do
    expect(Spelling.respond_to?(:init)).to be == false
  end

  it "hands back the enchant provider, initialised" do
    provider = Spelling::Provider.default

    expect(provider).to be_a(Spelling::Provider)
    expect(provider.display_name).to be_a(String)

    # Which dictionaries are installed is a property of the machine, so the
    # suite asserts the shape and not the content: the default code is a
    # String where enchant found one and nil where it did not.
    code = provider.default_code
    expect(code).to be_a(String) unless code.nil?

    # A GListModel of Spelling::Language. Indexing it wants the gio2 gem,
    # which this gem does not depend on, so the assertion stops at the count.
    expect(provider.list_languages.n_items).to be_a(Integer)
  end

  it "constructs a checker over that provider" do
    provider = Spelling::Provider.default
    checker = Spelling::Checker.new(provider, provider.default_code)

    expect(checker).to be_a(Spelling::Checker)
    expect(checker.provider).to be_a(Spelling::Provider)
  end

  it "answers about a word without a display or a main loop" do
    # The point of this one is that it answers at all: no gtk_init has run and
    # there is no GdkDisplay, and spell checking a word must not need either.
    #
    # Whether "the" is spelled correctly depends on the installed word list --
    # a machine with no dictionary says yes to everything -- so the assertion
    # is that the answer is a boolean. -1 is the length argument, meaning the
    # word is NUL-terminated.
    checker = Spelling::Checker.default

    expect([true, false]).to be(:include?, checker.check_word("the", -1))
  end

  it "shares one default checker" do
    expect(Spelling::Checker.default).to be_equal(Spelling::Checker.default)
  end
end
