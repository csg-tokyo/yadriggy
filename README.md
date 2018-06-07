# Yadriggy

Yadriggy (mistletoe in Japanese) is a library for building a
domain-specific language (DSL) embedded in Ruby.  It was developed for
a particular kind of embedded DSLs, which we call hemiparasitic DSLs.
These DSLs borrow the syntax from the host language, Ruby, and the
code written in the DSLs is embedded in normal Ruby code.  However,
the execution of the DSL code is independent of Ruby.  Its semantics
can be totally different from Ruby and the code can be run out of the
Ruby VM.  Hemiparasitic DSLs look like Ruby but they are different
languages except their syntax.
They parasitize Ruby by borrowing the syntax but their parasitism is
hemi; their execution engines are their own.

## Hemiparasitic DSLs

A typical example of hemiparasitic DSL is computation offloading from
Ruby.  For example, Yadriggy provides a simple DSL to offload
from Ruby to native C language.

```ruby
require 'yadriggy/c'

include Yadriggy::C::CType

def fib(n) ! Integer
  typedecl n: Integer
  if n > 1
    return fib(n - 1) + fib(n - 2)
  else
    return 1
  end
end

puts Yadriggy::C.run { return fib(32) }
```

When this code is run, the block given to `Yadriggy::C.run` is
translated into C code with the definition of `fib` method.
Then the C code is compiled into a dynamic library, loaded the
library through ruby-ffi, and executed.  Since the block given to
`run` calls `fib`, the definition of `fib` is also translated
into C.

An external variable is accessible from the compiled block:

```ruby
n = 32
puts Yadriggy::C.run { return fib(n) }
```

The argument to `fib` is take from the variable `n` that exists
outside of the block.  `n` is passed to the compiled block by _copying_.
It is not passed by _reference_.  Thus, when a new value is assigned to
`n` within the compiled block, it is not visible from the Ruby code.
The variable `n` in the Ruby code keeps the old value.

Note that the definition of `fib` contains type declarations
since this DSL is not Ruby.
A hemiparasitic DSL looks like Ruby but it is a different language.
`! Integer` following `def fib(n)` specifies the return type.
`typedecl` specifies the types of the parameters (and local variables
if any).  In this DSL, most types have to be statically given
although the DSL performs simple type inference and some types
can be omitted.

A compiled method can be repeatedly invoked.  To do so, first define
a subclass of `Yadriggy::C::Program`:

```ruby
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
```

Then compile all the public methods in `Fib`:

```ruby
m = Fib.compile
```

The `compile` method returns a module that contains a stub method
invoking the compiled `fib` method.  To invoke it, simply do:

```ruby
puts m.fib(32)
puts m.fib(30)
```

It is also possible to generate a Ruby script to load the generated
binary later.  For example,

```ruby
m = Fib.compile('FastFib')
```

This generates `yadriggy_tmp/fastfib.rb`.  It loads the `FastFib` module
with the compiled method `fib`.

```ruby
require 'yadriggy_tmp/fastfib'
puts FastFib.fib(31)
```

Passing an array to a compiled method is supported.
The type of array is either `arrayof(Int)` or `arrayof(Float)`.
The length of array has to be also passed.

```ruby
require 'yadriggy/c'

class ArrayToC < Yadriggy::C::Program
  def inc(a, b, n) ! Void
    typedecl a: arrayof(Int), b: arrayof(Int), n: Int
    for i in 0...n
      b[i] = a[i] + 1
    end
  end
end
```

To call `inc`, first, special array objects are created;
they are instances of `Yadriggy::C::CType::IntArray` or `FloatArray`
and they are accessible from both the Ruby code and the
offloaded `inc` method.
Regular Ruby arrays are not available in the method.

```ruby
include Yadriggy::C::CType

a_in = IntArray.new(5)    # an array object that can be passed to C code.
a_in.set_values {|i| i }  # a_in[i] = i
a_in[0] = 7
a_out = IntArray.new(5)
ArrayToC.compile.inc(a_in, a_out, a_in.size)  # compile and run
puts a_out.to_a           # convert a_out into a Ruby array and print it.
```

In the compiled method written in the DSL,
control structures such as `for` and `if` are available.
Moreover, the `times` method is available on an integer.
The `inc` method above can be rewritten as follows:

```ruby
def inc(a, b, n) ! Void
  typedecl a: arrayof(Int), b: arrayof(Int), n: Int
  n.times do |i|
    b[i] = a[i] + 1
  end
end
```

The block parameter `i` is a loop counter.  Note that a block
argument is only available for `times` in the DSL.  `times` in the DSL
is not a method but a special syntax form provided
for Ruby-like programming experience.
Currently, `IntArray` or `FloatArray` does not accept `times`.

## Library

Yadriggy provides a method for obtaining the abstract syntax tree (AST)
of the given method, lambda, or Proc.
It also provides a syntax checker that determines whether or not an AST
satisfies the syntax described in the BNF-like language, which is
a DSL embedded in Ruby by Yadriggy.

You can even obtain the AST of a piece of source code:

```ruby
require 'yadriggy'
ast = Yadriggy.reify {|a| a + 1 }
```

`reify` returns the AST of the given block `{|a| a + 1 }`.
It takes not only a block but also a `Method` or `Proc` object.

The idea of `reify` was proposed in the following paper:

- Shigeru Chiba, YungYu Zhuang, Maximilian Scherr, "Deeply Reifying Running Code for Constructing a Domain-Specific Language", PPPJ'16, Article No. 1, ACM, August 2016.

## Installation

To install, download this repository and run:

    $ bundle exec rake install

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/csg-tokyo/yadriggy.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
