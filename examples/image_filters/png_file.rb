# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'zlib'

class PngFile
  attr_reader :width, :height, :type, :srgb

  def initialize(file_name)
    raw_data = File.binread(file_name)
    sig = raw_data[0, 8]
    raise 'broken png' unless sig.unpack('C8') == [137, 80, 78, 71, 13, 10, 26, 10]
    compressed_data = ""
    pos = 8
    while pos < raw_data.size
      len, name = raw_data[pos, 8].unpack('NA4')
      if name == 'IHDR'
        raise 'bad IHDR size' unless len == 13
        ihdr = raw_data[pos + 8, 13].unpack('NNC5')
        @width = ihdr[0]
        @height = ihdr[1]
        @depth = ihdr[2]  # 8?
        @type = ihdr[3]   # 0: grayscale, 2: RGB
        @compresssion = ihdr[4]
        @filter = ihdr[5]
        @interlace = ihdr[6] # 0: no
      elsif name == 'IDAT'
        compressed_data += raw_data[pos + 8, len]
      elsif name == 'IEND'
        @data = Zlib::Inflate.inflate(compressed_data)
        break
      end
      pos += 8 + len + 4
    end

    unless supported?
      msg = @type == 6 ? '(type 6: with alpha channel)' : ''
      raise "unsupported png #{msg}"
    end
  end

  def supported?
    @depth == 8 && @filter == 0 && @interlace == 0 &&
      @type == 2
  end

  def to_a
    data = Array.new(@height) { Array.new(@width, 0) }

    @height.times do |y|
      pos = y * (@width * 3 + 1)
      filter = @data[pos].unpack('C')[0]
      case filter
      when 0
        @width.times do |x|
          data[y][x] = @data[pos + x * 3 + 1, 3].unpack('CCC')
        end
      when 1 # Sub
        data[y][0] = @data[pos + 1, 3].unpack('CCC')
        (1...@width).each do |x|
          px = @data[pos + x * 3 + 1, 3].unpack('CCC')
          data[y][x] = add_rgb(px, data[y][x - 1])
        end
      when 2 # Up
        @width.times do |x|
          px = @data[pos + x * 3 + 1, 3].unpack('CCC')
          data[y][x] = add_rgb(px, data[y - 1][x])
        end
      when 3 # Average
        data[y][0] = add_ave(@data[pos + 1, 3].unpack('CCC'),
                             data[y - 1][0], [0, 0, 0])
        (1...@width).each do |x|
          px = @data[pos + x * 3 + 1, 3].unpack('CCC')
          data[y][x] = add_ave(px, data[y - 1][x],
                                   data[y][x - 1])
        end
      when 4 # Paeth
        data[y][0] = paeth_rgb(@data[pos + 1, 3].unpack('CCC'),
                               data[y - 1][0], [0, 0, 0], [0, 0, 0])
        (1...@width).each do |x|
          px = @data[pos + x * 3 + 1, 3].unpack('CCC')
          data[y][x] = paeth_rgb(px, data[y - 1][x],
                                     data[y][x - 1],
                                     data[y - 1][x - 1])
        end
      else
        raise "filter #{filter} is not supported"
      end
    end
    data
  end

  def to_array1d(array=nil)
    array = Array.new(@width * @height) if array.nil?
    pos = 0
    to_a.each do |line|
      line.each do |rgb|
        array[pos] = rgb[0]
        array[pos + 1] = rgb[1]
        array[pos + 2] = rgb[2]
        pos += 3
      end
    end
    array
  end

  # Writes a PNG file.
  # `PngFile.write_png('bar.png', PngFile.new('foo.png').to_a)`
  # copies a file from `foo.png` to `bar.png`.
  #
  # @param [String] file_name  the file name.
  # @param [Array<Array<Array<Integer>>>] data  an image data.
  #  A two-dimensional array of RGB vector.
  def self.write_png(file_name, data)
    width = data[0].size
    height = data.size
    type = data[0][0].is_a?(Array) ? 2 : 0
    sig = [137, 80, 78, 71, 13, 10, 26, 10].pack('C8')
    ihdr = make_chunk('IHDR', [width, height, 8, type, 0, 0, 0].pack('NNCCCCC'))
    raw_data = data.map {|line| ([0] + line.flatten).pack('C*')}.join
    idat = make_chunk('IDAT', Zlib::Deflate.deflate(raw_data))
    iend = make_chunk('IEND', '')
    File.binwrite(file_name, sig + ihdr + idat + iend)
  end

  # Writes a PNG file.
  #
  # @param [String] file_name  the file name.
  # @param [Array<Number>] data  the image data.  Its size must be
  #  `width * height` (gray) or `width * height * 3` (color).
  # @param [Integer] width  the width.
  # @param [Integer] height  the height.
  def self.write_1d_png(file_name, data, width, height)
    if data.size == height * width
      is_gray = true
    elsif data.size == height * width * 3
      is_gray = false
    else
      raise "bad size #{data.size} for width #{width}"
    end

    type = is_gray ? 0 : 2
    sig = [137, 80, 78, 71, 13, 10, 26, 10].pack('C8')
    ihdr = make_chunk('IHDR', [width, height, 8, type, 0, 0, 0].pack('NNCCCCC'))
    raw_data = make_raw_data(data, width, height, is_gray)
    idat = make_chunk('IDAT', Zlib::Deflate.deflate(raw_data))
    iend = make_chunk('IEND', '')
    File.binwrite(file_name, sig + ihdr + idat + iend)
  end

  private

  def self.make_raw_data(data, width, height, is_gray)
    line_len = is_gray ? width : width * 3
    line = Array.new(line_len + 1, 0)
    arr = Array.new(height) do |i|
      pos = i * line_len
      line_len.times {|j| line[j + 1] = data[pos + j].to_i }
      line.pack('C*')
    end
    arr.join
  end

  def self.make_chunk(type, data)
    [data.bytesize, type, data, Zlib.crc32(type + data)].pack("NA4A*N")
  end

  def add_rgb(p, q)
    [(p[0] + q[0]) % 256, (p[1] + q[1]) % 256, (p[2] + q[2]) % 256]
  end

  def add_ave(delta, p, q)
    [((p[0] + q[0]) / 2 + delta[0]) % 256,
     ((p[1] + q[1]) / 2 + delta[1]) % 256,
     ((p[2] + q[2]) / 2 + delta[2]) % 256]
  end

  def paeth(a, b, c)
    pa = (b - c).abs
    pb = (a - c).abs
    pc = (a + b - c - c).abs
    if pa <= pb && pa <= pc
      a
    elsif pb <= pc
      b
    else
      c
    end
  end

  def paeth_rgb(delta, above, left, upper_left)
    [(delta[0] + paeth(left[0], above[0], upper_left[0])) % 256,
     (delta[1] + paeth(left[1], above[1], upper_left[1])) % 256,
     (delta[2] + paeth(left[2], above[2], upper_left[2])) % 256]
  end

end
