require 'yadriggy/c'

class ArrayToC < Yadriggy::C::Program
  def inc(a, b, n) ! Void
    typedecl a: arrayof(Int), b: arrayof(Int), n: Int
    for i in 0...n
      b[i] = a[i] + 1
    end
  end

  def inc2(a, b, n) ! Void
    typedecl a: arrayof(Int), b: arrayof(Int), n: Int
    n.times do |i|
      b[i] = a[i] + 1
    end
  end
end

include Yadriggy::C::CType

a_in = IntArray.new(5)    # an array object that can be passed to C code.
a_in.set_values {|i| i }  # a[i] = i
a_in[0] = 7
a_out = IntArray.new(5)
m = ArrayToC.compile
m.inc(a_in, a_out, a_in.size)
puts a_out.to_a
m.inc2(a_in, a_out, a_in.size)
puts a_out.to_a
