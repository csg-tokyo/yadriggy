require 'yadriggy'
require 'yadriggy/c'
require 'yadriggy/c/opencl'
require 'image_filters/png_file'

class LaplacianDemo

  class Laplacian < Yadriggy::C::Program
    def kernel(image, image2, width, height) ! Void
      typedecl image: arrayof(Float32), image2: arrayof(Float32),
        width: Integer, height: Integer

      (width * (height - 2)).times do |i|
        p = i * 3
        v = image[p] + image[p + width * 3 - 3] +
          image[p + width * 3 + 3] + image[p + width * 6] -
          4 * image[p + width * 3]

        vv = (v + 255 * 4) / (255.0 * 8)
        image2[i + width] = vv < 0.51 ? 0 : 255
      end
    end
  end

  class GpuLaplacian < Yadriggy::C::Program
    def initialize(width, height)
      @image = OclArray.new(width * height * 3)
      @image2 = OclArray.new(width * height)
    end

    def kernel(c_image, c_image2, width, height) ! Void
      typedecl c_image: arrayof(Float32), c_image2: arrayof(Float32),
        width: Integer, height: Integer

      @image.copyfrom(c_image, width * height * 3)
      t = current_time
      (width * (height - 2)).ocl_times do |i|
        p = i * 3
        v = @image[p] + @image[p + width * 3 - 3] +
          @image[p + width * 3 + 3] + @image[p + width * 6] -
          4 * @image[p + width * 3]

        vv = (v + 255 * 4) / (255.0 * 8)
        @image2[i + width] = vv < 0.51 ? 0 : 255
      end
      printf('OpenCL core: %d usec.\n', current_time - t)
      @image2.copyto(c_image2, width * height)

      offset = width * (height - 1)
      width.times do |i|
        c_image2[i] = 0
        c_image2[offset + i] = 0
      end
    end
  end

  def main(file_name)
    fname_base = "#{File.dirname(file_name)}/#{File.basename(file_name, '.*')}"
    t0 = Time.now
    f = PngFile.new(file_name)
    image = Yadriggy::C::Float32Array.new(f.width * f.height * 3)
    f.to_array1d(image)
    image2 = Yadriggy::C::Float32Array.new(f.width * f.height)
    puts("image loaded. #{Time.now - t0} sec.")

    t0 = Time.now
    Laplacian.new.kernel(image, image2, f.width, f.height)
    puts("Ruby time   #{Time.now - t0} sec.")
    PngFile.write_1d_png("#{fname_base}2.png", image2, f.width, f.height)

    t0 = Time.now
    mod = Laplacian.compile
    t = Time.now
    mod.kernel(image, image2, f.width, f.height)
    puts("C time      #{Time.now - t} sec. (total #{Time.now - t0} sec.)")
    PngFile.write_1d_png("#{fname_base}3.png", image2, f.width, f.height)

    if Yadriggy::C::Config::HostOS == :macos
      t0 = Time.now
      mod = GpuLaplacian.ocl_compile(args: [f.width, f.height])
      mod.ocl_init(2) # 0: CPU, 1: 1st GPU, 2: 2nd GPU, ...
      t = Time.now
      mod.kernel(image, image2, f.width, f.height)
      puts("OpenCL time #{Time.now - t} sec. (total #{Time.now - t0} sec.)")
      mod.ocl_finish
      PngFile.write_1d_png("#{fname_base}4.png", image2, f.width, f.height)
    end
  end

end

LaplacianDemo.new.main ARGV.size < 1 ? 'photo.png' : ARGV[0]
