# gdal-ruby

[![CI](https://github.com/fulcrumapp/gdal-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/fulcrumapp/gdal-ruby/actions/workflows/ci.yml)

Fulcrum’s internal fork of native GDAL/OGR bindings for Ruby.

> **Status:** maintenance / compatibility shim. Upstream OSGeo GDAL no longer
> ships Ruby SWIG bindings. This gem vendors historical SWIG output and links
> against the system `libgdal`. For new shapefile import/export prefer
> [`rgeo-shapefile`](https://github.com/rgeo/rgeo-shapefile) (Fulcrum already
> uses `rgeo`). Keeping this gem is about API continuity, not greenfield design.

## Why this is hard

| Problem | Detail |
|--------|--------|
| Abandoned upstream Ruby bindings | No supported regenerate path from current GDAL |
| Native extension + system GDAL | Build needs matching headers/`gdal-config` per arch |
| Multi-arch | x86_64 and arm64 each need a successful compile against arch-native `libgdal` |
| Oversized surface | ~51k lines of generated C/C++ for a tiny Fulcrum call site |

Publishing to GitHub Packages does **not** by itself solve multi-arch: the
default artifact is a **source gem** that still compiles on install. Prebuilt
platform gems are a separate, costly project (`rake-compiler-dock`).

## Requirements

- Ruby `>= 3.1`
- System GDAL development package (`libgdal-dev` / Homebrew `gdal`)
- `pkg-config` and a C++ toolchain

Verified CI targets: Ubuntu 24.04 amd64 + arm64, macOS 14 arm64, Ruby 3.2/3.3.

## Install (GitHub Packages)

This gem is published to the Fulcrum GitHub Packages RubyGems registry on
release (merge to `main` via release-please).

Bundler (`~/.bundle/config` or CI env):

```bash
bundle config set --global rubygems.pkg.github.com fulcrumapp:TOKEN
# or: BUNDLE_RUBYGEMS__PKG__GITHUB__COM=fulcrumapp:${GITHUB_TOKEN}
```

```ruby
# Gemfile
source "https://rubygems.pkg.github.com/fulcrumapp" do
  gem "gdal", "~> 3.1"
end
```

System GDAL must still be present at `bundle install` / extension compile time.

### Local / source install

```bash
# macOS
brew install gdal

# Debian/Ubuntu
sudo apt-get install -y libgdal-dev gdal-bin gdal-data pkg-config

bundle install
bundle exec rake spec
```

## Usage

```ruby
require "gdal-ruby/ogr"

puts Gdal::Ogr
  .create_geometry_from_wkt("POINT (30 10)")
  .export_to_json
```

Fulcrum production usage today is essentially shapefile open → read fields →
`export_to_json` in `Import::Formats::Shapefile`.

## Release automation

On every merge to `main`:

1. [release-please](https://github.com/googleapis/release-please) opens/updates a
   Release PR from conventional commits (`feat:`, `fix:`, `chore:` …).
2. When that Release PR merges, Actions:
   - tags `vX.Y.Z`
   - builds the gem
   - pushes to `https://rubygems.pkg.github.com/fulcrumapp`
   - attaches the `.gem` to the GitHub Release

Version source of truth: `lib/gdal-ruby/version.rb`.

## Recommended long-term direction

1. **Preferred:** remove this dependency from Fulcrum; implement shapefile import
   with `rgeo-shapefile` + existing RGeo stack (true multi-arch, no SWIG).
2. **If GDAL formats beyond shapefile are required:** shell out to `ogr2ogr`
   (`gdal-bin` already in Fulcrum images) or evaluate `ffi-gdal`.
3. **Do not** invest in full SWIG regeneration against modern GDAL without a
   strong second consumer.

## License

BSD. Generated sources under `ext/gdal-ruby` come from GDAL; see
`ext/gdal-ruby/LICENSE`.
