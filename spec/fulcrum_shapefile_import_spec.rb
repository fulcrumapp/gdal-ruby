# frozen_string_literal: true

require "spec_helper"
require_relative "support/fulcrum_shapefile_importer"

RSpec.describe "Fulcrum Import::Formats::Shapefile surface" do
  def shp(name)
    FIXTURES.join(name, "#{File.basename(name)}.shp")
  end

  describe "constants used by Fulcrum schema mapping" do
    it "exposes OGR field type constants" do
      expect(Gdal::Ogr::OFTSTRING).to be_a(Integer)
      expect(Gdal::Ogr::OFTINTEGER).to be_a(Integer)
      expect(Gdal::Ogr::OFTREAL).to be_a(Integer)
      expect(Gdal::Ogr::OFTSTRING).not_to eq(Gdal::Ogr::OFTINTEGER)
      expect(Gdal::Ogr::OFTINTEGER).not_to eq(Gdal::Ogr::OFTREAL)
    end

    it "exposes WKB geometry constants referenced by Fulcrum" do
      %i[
        WKBPOINT WKBPOINT25D WKBMULTIPOINT WKBMULTIPOINT25D
        WKBLINESTRING WKBMULTILINESTRING WKBLINEARRING WKBLINESTRING25D WKBMULTILINESTRING25D
        WKBPOLYGON WKBMULTIPOLYGON WKBPOLYGON25D WKBMULTIPOLYGON25D
      ].each do |name|
        expect(Gdal::Ogr.const_get(name)).to be_a(Integer), "missing #{name}"
      end
    end
  end

  describe "open + layer access" do
    it "opens a .shp path like Fulcrum file_path usage" do
      ds = FulcrumShapefileImporter.open(FIXTURES.join("flat/points.shp"))
      expect(ds).not_to be_nil
      expect(FulcrumShapefileImporter.layer(ds).get_feature_count).to eq(2)
    end

    it "opens a directory datasource containing a shapefile" do
      ds = FulcrumShapefileImporter.open(FIXTURES.join("points"))
      expect(FulcrumShapefileImporter.feature_count(FulcrumShapefileImporter.layer(ds))).to eq(2)
    end
  end

  describe "points fixture (primary Fulcrum path)" do
    let(:path) { shp("points") }
    let(:ds) { FulcrumShapefileImporter.open(path) }
    let(:layer) { FulcrumShapefileImporter.layer(ds) }

    it "reports feature_count" do
      expect(FulcrumShapefileImporter.feature_count(layer)).to eq(2)
    end

    it "maps geometry kind to :point" do
      expect(FulcrumShapefileImporter.geometry_kind(layer)).to eq(:point)
    end

    it "loads field schema with string/integer/real types" do
      columns = FulcrumShapefileImporter.schema_columns(layer)
      by_name = columns.to_h { |c| [c[:name], c[:type]] }

      expect(by_name).to include(
        "name" => :string,
        "count" => :integer,
        "score" => :double,
        "note" => :string
      )
    end

    it "reads attributes with the same field accessors Fulcrum uses" do
      rows = FulcrumShapefileImporter.each_feature(path)
      expect(rows.size).to eq(2)

      first = rows[0]
      expect(first["name"]).to eq("alpha")
      expect(first["count"]).to eq(3)
      expect(first["score"]).to eq(1.5)
      expect(first["note"]).to eq("café")
    end

    it "exports geometry to GeoJSON after flatten_to_2d" do
      rows = FulcrumShapefileImporter.each_feature(path)
      geom = rows[0]["__geometry__"]

      expect(geom["type"]).to eq("Point")
      expect(geom["coordinates"].size).to eq(2)
      expect(geom["coordinates"][0]).to be_within(0.0001).of(-82.4572)
      expect(geom["coordinates"][1]).to be_within(0.0001).of(27.9506)
    end

    it "flattens 3D points to 2 coordinates for GeoUtils consumers" do
      rows = FulcrumShapefileImporter.each_feature(path)
      three_d = rows.find { |r| r["name"] == "beta" }
      expect(three_d["__geometry__"]["coordinates"].size).to eq(2)
    end

    it "force-encodes string fields as UTF-8 like Fulcrum text_value" do
      rows = FulcrumShapefileImporter.each_feature(path)
      note = rows[0]["note"]
      expect(note.encoding).to eq(Encoding::UTF_8)
      expect(note).to eq("café")
    end

    it "supports random access get_feature by cursor index" do
      second = FulcrumShapefileImporter.read_feature(layer, 1)
      expect(second["name"]).to eq("beta")
      expect(second["count"]).to eq(10)
      expect(second["score"]).to eq(2.25)
    end
  end

  describe "lines fixture" do
    let(:path) { shp("lines") }
    let(:layer) { FulcrumShapefileImporter.layer(FulcrumShapefileImporter.open(path)) }

    it "maps geometry kind to :line" do
      expect(FulcrumShapefileImporter.geometry_kind(layer)).to eq(:line)
    end

    it "exports LineString GeoJSON" do
      row = FulcrumShapefileImporter.read_feature(layer, 0)
      expect(row["__geometry__"]["type"]).to eq("LineString")
      expect(row["__geometry__"]["coordinates"]).to be_a(Array)
      expect(row["name"]).to eq("route-a")
    end
  end

  describe "polygons fixture" do
    let(:path) { shp("polygons") }
    let(:layer) { FulcrumShapefileImporter.layer(FulcrumShapefileImporter.open(path)) }

    it "maps geometry kind to :polygon" do
      expect(FulcrumShapefileImporter.geometry_kind(layer)).to eq(:polygon)
    end

    it "exports Polygon GeoJSON" do
      row = FulcrumShapefileImporter.read_feature(layer, 0)
      expect(row["__geometry__"]["type"]).to eq("Polygon")
      expect(row["__geometry__"]["coordinates"].first.size).to be >= 4
      expect(row["name"]).to eq("block")
    end
  end

  describe "multipoint fixture" do
    let(:path) { shp("multipoint") }
    let(:layer) { FulcrumShapefileImporter.layer(FulcrumShapefileImporter.open(path)) }

    it "maps multipoint to :point like Fulcrum case branches" do
      expect(FulcrumShapefileImporter.geometry_kind(layer)).to eq(:point)
    end

    it "exports MultiPoint GeoJSON" do
      row = FulcrumShapefileImporter.read_feature(layer, 0)
      expect(row["__geometry__"]["type"]).to eq("MultiPoint")
      expect(row["__geometry__"]["coordinates"].size).to eq(2)
    end
  end

  describe "end-to-end parity with Fulcrum next_feature loop" do
    it "walks every feature without raising and yields geometry + attrs" do
      %w[points lines polygons multipoint].each do |name|
        rows = FulcrumShapefileImporter.each_feature(shp(name))
        expect(rows).not_to be_empty
        rows.each do |row|
          expect(row).to have_key("__geometry__")
          expect(row["__geometry__"]).to be_a(Hash)
          expect(row["__geometry__"]).to have_key("type")
          expect(row).to have_key("name")
        end
      end
    end
  end
end
