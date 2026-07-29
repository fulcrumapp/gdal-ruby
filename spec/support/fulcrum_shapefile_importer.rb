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
    info.get_field_count.times.map do |index|
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

  # Prefer set_next_by_index: get_feature takes FID, which is not always 0..N-1.
  def feature_at(layer, index)
    layer.set_next_by_index(index)
    layer.get_next_feature
  end

  def read_feature(layer, index)
    feature = feature_at(layer, index)
    raise "missing feature at index #{index}" if feature.nil?

    info = field_info(layer)
    attrs = read_attrs(feature, info)
    attrs.merge("__geometry__" => geometry_json(feature))
  end

  # Sequential scan matching Fulcrum's next_feature loop.
  def read_features(path)
    ds = open(path)
    lyr = layer(ds)
    lyr.reset_reading

    info = field_info(lyr)
    rows = []
    while (feature = lyr.get_next_feature)
      attrs = read_attrs(feature, info)
      attrs["__geometry__"] = geometry_json(feature)
      rows << attrs
    end

    rows
  end

  def read_attrs(feature, info)
    attrs = {}
    info.get_field_count.times do |field_index|
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
    attrs
  end

  def geometry_json(feature)
    geom = feature.get_geometry_ref
    return nil unless geom

    geom.flatten_to_2d
    JSON.parse(geom.export_to_json)
  end

  def text_value(input)
    input.force_encoding("UTF-8")
  rescue StandardError
    input
  end
end
