# Yadriggy

Yadriggy (mistletoe in Japanese) is a library for building a
domain-specific language (DSL) embedded in Ruby.  It was developed for
a particular kind of embedded DSLs.
These DSLs borrow the syntax from the host language, Ruby, and the
code written in the DSLs is embedded in normal Ruby code.  However,
the execution of the DSL code is independent of Ruby.  Its semantics
can be totally different from Ruby and the code can be run out of the
Ruby VM.  These DSLs look like Ruby but they are different
languages except their syntax.
They are embedded in Ruby by borrowing the syntax but their embedding is
outward; their execution engines are their own.

For details, the documentation is available from [Wiki](https://github.com/csg-tokyo/yadriggy/wiki).

## An example

Computation offloading from Ruby is a typical example of the DSLs
implemented by Yadriggy.
For example, Yadriggy provides a simple DSL to offload
from Ruby to native C language.

```ruby
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
This DSL looks like Ruby but it is a different language.
`! Integer` following `def fib(n)` specifies the return type.
`typedecl` specifies the types of the parameters (and local variables
if any).  In this DSL, most types have to be statically given
although the DSL performs simple type inference and some types
can be omitted.

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

Yadriggy works with Pry and IRuby unless a syntax error occurs.

The idea of `reify` was proposed in the following paper:

- Shigeru Chiba, YungYu Zhuang, Maximilian Scherr, "Deeply Reifying Running Code for Constructing a Domain-Specific Language", PPPJ'16, Article No. 1, ACM, August 2016.

## Installation

To install, run:

    $ gem install yadriggy

or, download this repository and run:

    $ bundle exec rake install

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/csg-tokyo/yadriggy.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
