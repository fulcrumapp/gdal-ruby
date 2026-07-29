# frozen_string_literal: true

require "mkmf"
require "open3"
require "shellwords"

require_relative "ruby-2.2-patch"

module Gdal
  module ExtconfHelper
    module_function

    def configure!(target:)
      gdal_config = find_executable("gdal-config")
      raise "gdal-config not found. Install libgdal-dev / gdal and ensure it is on PATH." unless gdal_config

      version = gdal_config_output(gdal_config, "--version").strip
      cflags = Shellwords.split(gdal_config_output(gdal_config, "--cflags").strip)
      libs = Shellwords.split(gdal_config_output(gdal_config, "--libs").strip)

      incdirs = cflags.select { |f| f.start_with?("-I") }.map { |f| f.delete_prefix("-I") }
      libdirs = libs.select { |f| f.start_with?("-L") }.map { |f| f.delete_prefix("-L") }
      dir_config("gdal", incdirs.first, libdirs.first)

      $INCFLAGS = [incdirs.map { |d| "-I#{d}" }.join(" "), $INCFLAGS].compact.join(" ").strip
      $LDFLAGS = [libdirs.map { |d| "-L#{d}" }.join(" "), $LDFLAGS].compact.join(" ").strip

      pkg_config("gdal")
      have_library("gdal") or raise "libgdal not found (gdal-config reported #{version})"
      $libs = append_library($libs, "gdal")

      $CXXFLAGS = CONFIG["CXXFLAGS"] unless defined?($CXXFLAGS) && $CXXFLAGS

      common_warnings = " -Wno-format-security -Wno-unused-result -Wno-deprecated-declarations"
      $CFLAGS << common_warnings
      $CXXFLAGS << common_warnings

      major = version.split(".").first.to_i
      # Only C++ extensions need a modern dialect; gdalconst is pure C.
      if major >= 2 && target != "gdal-ruby/gdalconst"
        $CXXFLAGS << " -Wno-reserved-user-defined-literal -std=c++17"
      end

      libdirs.each do |dir|
        $LDFLAGS << " -Wl,-rpath,#{dir}" if RUBY_PLATFORM.include?("darwin")
      end

      puts "Using GDAL #{version} for #{target}"
      create_makefile(target)
    end

    def gdal_config_output(gdal_config, *args)
      output, status = Open3.capture2(gdal_config, *args)
      raise "failed to run #{gdal_config} #{args.join(' ')}" unless status.success?

      output
    end
  end
end

