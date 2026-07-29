# frozen_string_literal: true

require_relative "lib/gdal-ruby/version"

Gem::Specification.new do |gem|
  gem.name          = "gdal"
  gem.version       = Gdal::Ruby::VERSION
  gem.authors       = ["Zac McCormick", "Fulcrum"]
  gem.email         = ["zac.mccormick@gmail.com"]
  gem.summary       = "GDAL/OGR bindings for Ruby (Fulcrum internal fork)"
  gem.description   = <<~DESC
    Native GDAL/OGR bindings packaged as a gem. This is the Fulcrum-maintained
    fork of zhm/gdal-ruby. Bindings are historical SWIG output and are not kept
    in lockstep with the latest GDAL API. Prefer rgeo-shapefile for new
    shapefile work when full GDAL is not required.
  DESC
  gem.homepage      = "https://github.com/fulcrumapp/gdal-ruby"
  gem.license       = "BSD-3-Clause"
  gem.required_ruby_version = ">= 3.1.0"

  gem.metadata = {
    "bug_tracker_uri" => "https://github.com/fulcrumapp/gdal-ruby/issues",
    "changelog_uri" => "https://github.com/fulcrumapp/gdal-ruby/blob/main/CHANGELOG.md",
    "homepage_uri" => gem.homepage,
    "source_code_uri" => "https://github.com/fulcrumapp/gdal-ruby",
    "github_repo" => "https://github.com/fulcrumapp/gdal-ruby",
    "allowed_push_host" => "https://rubygems.pkg.github.com/fulcrumapp"
  }

  gem.files = Dir.chdir(__dir__) do
    tracked =
      if system("git", "rev-parse", "--is-inside-work-tree", out: File::NULL, err: File::NULL)
        `git ls-files -z`.split("\x0")
      else
        Dir.glob("**/*", File::FNM_DOTMATCH)
      end

    tracked
      .reject(&:empty?)
      .reject { |f| f == "." || f == ".." || f.end_with?("/.") || f.end_with?("/..") }
      .reject { |f| File.directory?(f) }
      .reject do |f|
        f.start_with?("spec/", "test/", ".github/", "tmp/", "pkg/") ||
          f == ".travis.yml" ||
          f.end_with?(".bundle", ".so", ".o", ".gem")
      end
  end

  raise "gdal.gemspec: gem.files is empty; cannot package a valid gem" if gem.files.empty?

  gem.require_paths = ["lib"]
  gem.extensions = [
    "ext/gdal-ruby/gdal/extconf.rb",
    "ext/gdal-ruby/gdalconst/extconf.rb",
    "ext/gdal-ruby/ogr/extconf.rb",
    "ext/gdal-ruby/osr/extconf.rb"
  ]

  gem.add_development_dependency "rake", "~> 13.0"
  gem.add_development_dependency "rake-compiler", "~> 1.2"
  gem.add_development_dependency "rspec", "~> 3.13"
end
