# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Gdal" do
  it "reports a version" do
    expect(Gdal::Ruby::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  it "converts WKT to GeoJSON" do
    geometry = Gdal::Ogr.create_geometry_from_wkt("POINT (30 10)")
    parsed = JSON.parse(geometry.export_to_json)

    expect(parsed).to eq("type" => "Point", "coordinates" => [30.0, 10.0])
  end

  it "loads all extension entrypoints used by require 'gdal'" do
    expect(defined?(Gdal::Gdal)).to be_truthy
    expect(defined?(Gdal::Ogr)).to be_truthy
    expect(defined?(Gdal::Osr)).to be_truthy
  end
end
