# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = "roundhouse-rugaroo"
  s.version = "0.1.0"
  s.summary = "Run roundhouse's Spinel output of a Rails app on MRI, or compile it to one Go binary with rugaroo"
  s.description = "Ruby stand-ins for the Spinel-only files roundhouse emits (its tep HTTP server, its FFI sqlite and crypto), " \
                  "plus the RBS corrections rugaroo needs to type the rest."
  s.authors = ["JT Archie"]
  s.license = "MIT"
  s.homepage = "https://github.com/jtarchie/roundhouse-rugaroo"
  s.files = Dir["lib/**/*.rb"] + Dir["sig/**/*.rbs"] + ["README.md", "LICENSE"]
  s.required_ruby_version = ">= 3.3"
  s.add_dependency "base64" # a bundled gem since Ruby 3.4; the gem and roundhouse's runtime both require it
  s.add_dependency "sqlite3", ">= 2.0"
end
