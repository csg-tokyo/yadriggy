require 'yadriggy/c/opencl'

class Inc < Yadriggy::C::Program
  def initialize
    @data = OclArray.new(16)
  end
  def inc(arr, n) ! Void
    typedecl arr: Float32Array, n: Int
    @data.copyfrom(arr, n)
    16.ocl_times {|i| @data[i] *= 2.0 }
    @data.copyto(arr, n)
  end
end

m = Inc.ocl_compile
arr = Yadriggy::C::Float32Array.new(16)
arr.set_values {|i| i }
m.ocl_init(1)
m.inc(arr, arr.size)
m.ocl_finish
puts arr.to_a
