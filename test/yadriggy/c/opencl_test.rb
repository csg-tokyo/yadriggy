require 'test_helper'
require 'yadriggy/c'
require 'yadriggy/c/opencl'

class OpenCL_Tester < Test::Unit::TestCase
  T = 0
  class Test1 < Yadriggy::C::Program
    S = 10.0
    def initialize
      @data = OclArray.new(512)
    end
    def foo(arr, n) ! Float32
      typedecl arr: Float32Array, n: Int
      @data.copyfrom(arr, n)
      512.ocl_times {|i| j = n; b = @data[i]; @data[i] = @data[i] + 1.0 }
      @data.copyto(arr, n)
      return arr[0]
    end
    def bar(a)
      typedecl a: Float32Array, return: Float32
      return a[0] + a[0] + S + OpenCL_Tester::T
    end
  end

  test 'simple opencl function' do
    break unless Yadriggy::C::Config::HostOS == :macos

    a = Yadriggy::C::Float32Array.new(10)
    a.set_values {|i| i + 1.1 }
    mod = Test1.ocl_compile(dir: './testbin/')
    mod.ocl_init(1)
    assert_equal(2.1, mod.foo(a, a.size).round(2))
    assert_equal(14.2, mod.bar(a).round(2))
    mod.ocl_finish
  end

  class Test2 < Yadriggy::C::Program
    def initialize
      @data = OclArray.new(512)
    end
    def foo(arr, n) ! Float32
      typedecl arr: Float32Array, n: Int
      512.ocl_times
      return arr[0]
    end
  end

  test 'simple opencl function 2' do
    break unless Yadriggy::C::Config::HostOS == :macos
    assert_raise do
      mod = Test2.ocl_compile(dir: './testbin/')
    end
  end

  class Test3 < Yadriggy::C::Program
    def foo(arr, n) ! Float32
      typedecl arr: Float32Array, n: Int
      512.ocl_times {|i| }
      return arr[0]
    end
  end

  test 'simple opencl function 3' do
    break unless Yadriggy::C::Config::HostOS == :macos
    mod = Test3.ocl_compile(dir: './testbin/')
  end

end
