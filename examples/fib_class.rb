require 'yadriggy'
require 'yadriggy/c'

class Fib < Yadriggy::C::Program
  def fib(n) ! Integer
    typedecl n: Integer
    if n > 1
      return fib(n - 1) + fib(n - 2)
    else
      return 1
    end
  end
end

m = Fib.compile('FastFib')  # returns a module.
puts m.fib(32)
