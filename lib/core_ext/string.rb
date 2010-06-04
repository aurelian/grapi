require 'zlib'
require 'stringio'

class String
  def uncompress
    begin
      gz = Zlib::GzipReader.new(StringIO.new(self))
      xml = gz.read
      gz.close
    rescue Zlib::GzipFile::Error
      # Maybe this is not gzipped?
      xml = self
    end
    xml
  end
end

