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

  # Prefer set_next_by_index: get_feature takes FID, which is not always 0..N-1.
  def feature_at(layer, index)
    layer.set_next_by_index(index)
    layer.get_next_feature
  end

  def read_feature(layer, index)
    feature = feature_at(layer, index)
    raise "missing feature at index #{index}" if feature.nil?

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

  # Sequential scan matching Fulcrum's next_feature loop.
  def read_features(path)
    ds = open(path)
    lyr = layer(ds)
    lyr.reset_reading

    rows = []
    while (feature = lyr.get_next_feature)
      info = field_info(lyr)
      attrs = {}

      field_count(lyr).times do |field_index|
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
      if geom
        geom.flatten_to_2d
        attrs["__geometry__"] = JSON.parse(geom.export_to_json)
      else
        attrs["__geometry__"] = nil
      end

      rows << attrs
    end

    rows
  end

  def text_value(input)
    input.force_encoding("UTF-8")
  rescue StandardError
    input
  end
end

