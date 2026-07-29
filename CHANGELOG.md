# Changelog

## [3.1.0](https://github.com/fulcrumapp/gdal-ruby/compare/v3.0.0...v3.1.0) (2026-07-29)

### Features

* publish to GitHub Packages with release-please on main
* multi-arch GitHub Actions CI (ubuntu amd64/arm64, macOS arm64)
* modernize gemspec metadata and require Ruby >= 3.1
* add fixture-based specs covering Fulcrum shapefile import call surface

### Bug Fixes

* align in-repo version with the 3.x line Fulcrum already locks
* silence Ruby 3.2+ SWIG `T_DATA` allocator warnings on require
* compile against GDAL 3.13 (`CSLConstList` const-correctness, `ABS` shim)
* stop passing `-std=c++17` into the pure-C `gdalconst` extension

### Documentation

* document multi-arch limits, Packages install, and rgeo-shapefile migration path
* remove obsolete Travis CI configuration

## [3.0.0](https://github.com/fulcrumapp/gdal-ruby/compare/v2.0.0...v3.0.0) (2020-04-16)

* RubyGems release used by Fulcrum (`~> 3.0.0`); version file in git had drifted to 2.0.0

## [2.0.0](https://github.com/fulcrumapp/gdal-ruby/compare/v1.0.0...v2.0.0) (2019-06-18)

* Fix GDAL 2.x compatibility

## v1.0.0

* Regenerated bindings using GDAL 1.10.1 sources and SWIG 3.0.5
* Patch for ruby 2.2.1
* Fix symbol conflicts between gdal and ogr modules

## v0.0.7

* Fix for building on ruby versions where `$CXXFLAGS` isn't defined
