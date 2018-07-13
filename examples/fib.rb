require 'yadriggy'
require 'yadriggy/c'

include Yadriggy::C::CType

def fib(n) ! Integer
  typedecl n: Integer
  if n > 1
    return fib(n - 1) + fib(n - 2)
  else
    return n
  end
end

puts Yadriggy::C.run { return fib(32) }

n = 32
puts Yadriggy::C.run { return fib(n) }
