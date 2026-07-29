# frozen_string_literal: true

# Mirrors fulcrumapp/fulcrum app/classes/import/formats/shapefile.rb call surface
# against this gem. Keep behavior aligned when changing either side.
module FulcrumShapefileImporter
  module_function

  def open(path)
    Gdal::Ogr.open(path.to_s)
  end

  def layer(datasource, index = 0)
    datasource.get_layer(index)
  end

  def feature_count(layer)
    layer.get_feature_count
  end

  def field_info(layer)
    layer.get_layer_defn
  end

  def field_count(layer)
    field_info(layer).get_field_count
  end

  def geometry_kind(layer)
    case layer.get_geom_type
    when Gdal::Ogr::WKBPOINT,
         Gdal::Ogr::WKBPOINT25D,
         Gdal::Ogr::WKBMULTIPOINT,
         Gdal::Ogr::WKBMULTIPOINT25D
      :point
    when Gdal::Ogr::WKBLINESTRING,
         Gdal::Ogr::WKBMULTILINESTRING,
         Gdal::Ogr::WKBLINEARRING,
         Gdal::Ogr::WKBLINESTRING25D,
         Gdal::Ogr::WKBMULTILINESTRING25D
      :line
    when Gdal::Ogr::WKBPOLYGON,
         Gdal::Ogr::WKBMULTIPOLYGON,
         Gdal::Ogr::WKBPOLYGON25D,
         Gdal::Ogr::WKBMULTIPOLYGON25D
      :polygon
    else
      :unknown
    end
  end

  def schema_columns(layer)
    info = field_info(layer)
    field_count(layer).times.map do |index|
      defn = info.get_field_defn(index)
      type =
        case defn.get_type
        when Gdal::Ogr::OFTSTRING then :string
        when Gdal::Ogr::OFTINTEGER then :integer
        when Gdal::Ogr::OFTREAL then :double
        else :string
        end
      { name: defn.get_name, type: type }
    end
  end

  def read_feature(layer, index)
    feature = layer.get_feature(index)
    info = field_info(layer)
    attrs = {}

    field_count(layer).times do |field_index|
      defn = info.get_field_defn(field_index)
      value =
        case defn.get_type
        when Gdal::Ogr::OFTSTRING
          text_value(feature.get_field_as_string(field_index))
        when Gdal::Ogr::OFTINTEGER
          feature.get_field_as_integer(field_index)
        when Gdal::Ogr::OFTREAL
          feature.get_field_as_double(field_index)
        else
          text_value(feature.get_field_as_string(field_index))
        end
      attrs[defn.get_name] = value
    end

    geom = feature.get_geometry_ref
    geojson = nil
    if geom
      geom.flatten_to_2d
      geojson = JSON.parse(geom.export_to_json)
    end

    attrs.merge("__geometry__" => geojson)
  end

  def each_feature(path)
    ds = open(path)
    lyr = layer(ds)
    feature_count(lyr).times.map { |i| read_feature(lyr, i) }
  ensure
    lyr = nil
    ds = nil
  end

  def text_value(input)
    input.force_encoding("UTF-8")
  rescue StandardError
    input
  end
end
