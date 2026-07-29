# frozen_string_literal: true

require "spec_helper"
require "open3"

RSpec.describe "Ruby 3 SWIG allocator warnings" do
  it "does not emit T_DATA allocator warnings on require/use" do
    script = <<~RUBY
      Warning[:deprecated] = true if Warning.respond_to?(:[]=)
      require "gdal"
      g = Gdal::Ogr.create_geometry_from_wkt("POINT (1 2)")
      puts g.export_to_json
      ds = Gdal::Ogr.open(#{SpecSupport::FIXTURES.join('flat/points.shp').to_s.inspect})
      layer = ds.get_layer(0)
      layer.set_next_by_index(0)
      f = layer.get_next_feature
      puts f.get_field_as_string(0)
    RUBY

    env = {
      "BUNDLE_GEMFILE" => File.expand_path("../Gemfile", __dir__),
      "RUBYOPT" => "-W2"
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "ruby", "-e", script)
    combined = stdout + stderr

    expect(status.success?).to eq(true), combined
    expect(combined).not_to match(/undefining the allocator of T_DATA class/)
    expect(combined).not_to match(/swig_runtime_data/)
  end
end
