# encoding: utf-8
$:.unshift(File.dirname(__FILE__))

require 'rubygems'
require 'nokogiri'
require 'mini_exiftool'

class Gpx2exif

  def initialize
    @pictures     = Array.new
    @gpx          = Array.new
    @trackpoints  = Array.new
  end

  attr :pitures, :gpx, :trackpoints

  def read_pictures_folder(path)
    Dir.glob("#{path}/*.{jpg,png}", File::FNM_CASEFOLD).each do |f|
      add_picture(f)
    end
  end

  def read_gpx_folder(path)
    Dir.glob("#{path}/*.gpx", File::FNM_CASEFOLD).each do |f|
      add_gpx(f)
    end
  end

  def add_picture(picture)
    @pictures << picture
  end

  def add_gpx(gpx)
    @gpx << gpx
  end

  def read_gpx
    tracks = Array.new
    error_count = 0

    @gpx.each do |path|
      f = File.new(path)
      gpx = Nokogiri::XML(f)
      gpx.remove_namespaces!

      trackpoints = gpx.xpath('//gpx/trk/trkseg/trkpt')
      trackpoints.each do |wpt|
        w = {
          lat:  wpt.xpath('@lat').to_s.to_f,
          lon:  wpt.xpath('@lon').to_s.to_f,
          time: wpt.xpath('time').children.first.to_s,
          alt:  wpt.xpath('ele').children.first.to_s.to_f
        }

        if coord_valid?(w[:lat], w[:lon], w[:alt], w[:time])
          tracks << w
        else
          error_count += 1
        end
      end
      f.close
    end

    tracks = tracks.sort { |b, c| b[:time] <=> c[:time] }

    add_trackpoints(tracks)
  end

  def add_trackpoints(points)
    @trackpoints += points
    @trackpoints = @trackpoints.sort { |b, c| b[:time] <=> c[:time] }
  end

  def match_pictures_with_gpx
    @pictures.each do |picture|
      picture = MiniExiftool.new picture
      geo = search_coords(picture['DateTimeOriginal'])

      set_picture_coords(picture, geo[:lat], geo[:lon], geo[:alt]) unless geo.nil?
    end
  end


  def search_coords(time)
    threshold = 5*60
    time = time.to_i

    selected_coords = @trackpoints.select { |c| (DateTime.parse(c[:time]).to_time.to_i - time).abs < threshold }


    selected_coords = selected_coords.sort { |a, b| (DateTime.parse(a[:time]).to_time.to_i - time).abs <=> (DateTime.parse(b[:time]).to_time.to_i - time).abs }

    if selected_coords.size > 0
      { lat: selected_coords.first[:lat], lon: selected_coords.first[:lon] }
    end
  end

  def set_picture_coords(picture, lat, lon, alt)
    lat_ref = "N"
    lon_ref = "E"
    lat_ref = "S" if lat < 0.0
    lon_ref = "W" if lon < 0.0

    picture['GPSLatitudeRef']   = lat_ref
    picture['GPSLongitudeRef']  = lon_ref
    picture['GPSLatitude']      = lat
    picture['GPSLongitude']     = lon
    picture['GPSAltitude']      = alt

    picture.save
  end



  # Only import valid coords
  def coord_valid?(lat, lon, elevation, time)
    return true if lat and lon
    return false
  end
end
