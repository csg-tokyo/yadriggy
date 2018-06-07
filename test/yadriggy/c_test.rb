require 'test_helper'
require 'yadriggy/c'

class C_Tester < Test::Unit::TestCase
  include Yadriggy::C

  syn = Yadriggy::C::syntax
  tchecker = ClangTypeChecker.new

  class Foo
    include Yadriggy::C::CType

    def fooo(a, b) - Int
      typedecl a: Int, b: Int
      return a + b
    end

    def fooo2(a, b)
      typedecl a: Int, b: Int, return: Int
      return a + b
    end

    def fooo3(a, b)
      -a
      typedecl a: Int, b: Int, return: Int
      return a + b
    end

    def foo(a, b) - Int
      typedecl a: Int, b: Int
      return a + b
    end

    def bar(a, b) - Void
      typedecl a: Int, b: Int
      return
    end

    def baz(a, b) ! Int
      typedecl a: Int, b: Int
      c = a + b
      d = 3
      return c + d
    end

    def baz2(a, b) ! Float
      typedecl a: Int, b: Int
      c = a + b
      d = 3.0
      return d + c
    end

  end

  test 'syntax checker' do
    foo = Foo.new
    ast = Yadriggy::reify(foo.method(:fooo))
    assert(syn.check_usertype(:func_body, ast.tree.body), 'syntax error')
    assert_equal(:func_body, ast.tree.body.usertype)
    assert_equal(:return_type, ast.tree.body.expressions[0].usertype)
  end

  test 'syntax checker 2' do
    foo = Foo.new
    ast = Yadriggy::reify(foo.method(:fooo2))
    assert(syn.check(ast.tree), 'syntax error')
    assert_equal(:func_body, ast.tree.body.usertype)
    assert_equal(:typedecl, ast.tree.body.expressions[0].usertype)
  end

  test 'syntax checker 3' do
    foo = Foo.new
    ast = Yadriggy::reify(foo.method(:fooo3))
    assert(syn.check(ast.tree), 'syntax error')
    assert_equal(:func_body, ast.tree.body.usertype)
    assert_equal(:expr, ast.tree.body.expressions[0].usertype)
    assert_equal(:typedecl, ast.tree.body.expressions[1].usertype)
  end

  test 'typedecl for foo' do
    ast = Yadriggy::reify(Foo.new.method(:foo))
    assert(syn.check(ast.tree), 'syntax check typedecl')
    e = ast.tree.body
    assert_equal(:typedecl, e.expressions[1].usertype)
    assert_equal(:typedecl_hash, e.expressions[1].args[0].usertype)
    assert(tchecker.typecheck(ast.tree))
  end

  test 'typedecl for bar' do
    ast = Yadriggy::reify(Foo.new.method(:bar))
    assert(syn.check(ast.tree), 'syntax check typedecl')
    assert(tchecker.typecheck(ast.tree))
    ast_var_a = ast.tree.body.expressions[1].args[0].pairs[0][0]
    assert_equal(nil, tchecker.type(ast_var_a).definition)
  end

  test 'type inference for assignment' do
    foo = Foo.new
    ast = Yadriggy::reify(foo.method(:baz))
    assert(syn.check(ast.tree), 'syntax check')
    assert_equal(Yadriggy::RubyClass::Integer,
                 tchecker.typecheck(ast.tree).result)
    exprs = ast.tree.body.expressions
    assert_equal(Yadriggy::RubyClass::Integer,
                 tchecker.type(exprs[2].left))
    assert_equal(Yadriggy::RubyClass::Integer,
                 tchecker.type(exprs[3].left))

    ast_var_a = exprs[1].args[0].pairs[0][0]
    assert_equal(nil, tchecker.type(ast_var_a).definition)
  end

  test 'type inference for assignment 2' do
    foo = Foo.new
    ast = Yadriggy::reify(foo.method(:baz2))
    assert(syn.check(ast.tree), 'syntax check')
    assert_equal(Yadriggy::RubyClass::Float,
                 tchecker.typecheck(ast.tree).result)
    exprs = ast.tree.body.expressions
    assert_equal(Yadriggy::RubyClass::Integer,
                 tchecker.type(exprs[2].left))
    assert_equal(Yadriggy::RubyClass::Float,
                 tchecker.type(exprs[3].left))
    d_type = tchecker.type(exprs[4].values[0].left)
    assert_equal(Yadriggy::RubyClass::Float, d_type)
    assert_equal(exprs[3].left, d_type.definition)
  end

  class Bar
    include Yadriggy::C::CType

    def foo(a, b) ! Int
      return a + b
    end

    def bar(a, b) ! Int
      typedecl a: Int, b: Int
      return foo(a, b + 1)
    end

    def baz(a) ! Int
      typedecl a: Int
      b = a + 1
      return foo(a, b)
    end

    def foo2(a, b) ! Int
      return a + b
    end

    def bar2() ! Float
      m = foo2(1, 2)
      n = foo2(1.0, 2.0)
      return m + n
    end
  end

  test 'type inference of a called method' do
    bar = Bar.new
    bar_ast = Yadriggy::reify(bar.method(:bar))
    assert(syn.check(bar_ast.tree), 'syntax check')
    bar_t = tchecker.typecheck(bar_ast.tree)
    assert_equal(Yadriggy::RubyClass::Integer, bar_t.result)
    foo_ast = bar_ast.reify(bar.method(:foo))
    foo_t = tchecker.type(foo_ast.tree)
    assert_equal(Yadriggy::RubyClass::Integer, foo_t.result)
    ret_value = foo_ast.tree.body.expressions[1].values[0]
    assert_equal(Yadriggy::RubyClass::Integer,
                 tchecker.type(ret_value.left)) # a
    assert_equal(Yadriggy::RubyClass::Integer,
                 tchecker.type(ret_value.right)) # b
  end

  test 'collecting local variables' do
    bar = Bar.new
    baz_ast = Yadriggy::reify(bar.method(:baz))
    assert(syn.check(baz_ast.tree), 'syntax check')
    baz_t = tchecker.typecheck(baz_ast.tree)
    lvt = tchecker.local_vars_table[baz_ast.tree]
    assert(lvt)
    assert_equal(1, lvt.size)
    assert_false(lvt.include?(:a))
    assert(lvt.include?(:b))

    foo_ast = baz_ast.reify(bar.method(:foo))
    foo_lvt = tchecker.local_vars_table[foo_ast.tree]
    assert(foo_lvt)
    assert_equal(0, foo_lvt.size)
  end

  test 'argument type mismatch by type inference' do
    bar = Bar.new
    bar_ast = Yadriggy::reify(bar.method(:bar2))
    assert(syn.check(bar_ast.tree), 'syntax check')
    assert_raise do
      tchecker.typecheck(bar_ast.tree)
    end
  end

  class Fact
    include Yadriggy::C::CType

    def fact(n) ! Int
      typedecl n: Int
      return fact2(n, 1)
    end

    def fact2(n, res) ! Int
      if n > 1
        res2 = res * n
        return fact2(n - 1, res2)
      else
        return res
      end
    end

    def print(n) ! Void
      typedecl n: Int,
               native: "printf(\"fact=%d\\n\", n);"
      puts(n)
    end
  end

  test 'ruby fact' do
    assert_equal(40320, Fact.new.fact(8))
  end

  test 'convert fact() to C' do
    t = Time.now
    mth = Fact.new.method(:fact)
    mod = Yadriggy::C::compile(mth, 'fact', './testbin/')
    assert_equal(40320, mod.fact(8))
    puts "compile fact: #{Time.now - t} sec."
    t = Time.now
    mod.fact(8)
    puts "fact(8): #{Time.now - t} sec."
    t = Time.now
    Fact.new.fact(8)
    puts "fact(8): #{Time.now - t} sec."
  end

  class Baz
    include Yadriggy::C::CType

    def foo(s) ! String
      typedecl s: String
      print(s)
      return s
    end

    def foo2(a)
      typedecl a: String
      print(a)
    end

    def foo3(a)
      typedecl a: Int, return: Int
      return a
    end

    def bar(a, i, v) ! Int
      typedecl a: arrayof(Int), i: Int, v: Int
      a[i + 1] = v
      return a[i]
    end

    def baz(a, i, v) ! Float
      typedecl a: arrayof(Float), i: Int, v: Float
      a[i + 1] = v
      return a[i]
    end

    def baz2(a, b, i, v) ! Float
      typedecl a: FloatArray, b: IntArray, i: Int, v: Float
      a[i + b[0]] = v
      return a[i]
    end

    def baz3(a)
      typedecl a: arrayof(Float), return: arrayof(Float)
      return a
    end

    def print(s) ! Void
      typedecl s: String, return: Void,
               native: "printf(\"print=%s\\n\", s);"
      puts(n)
    end
  end

  test 'string' do
    baz = Baz.new
    mth = baz.method(:foo)
    mod = Yadriggy::C.compile(mth, 'str_test', './testbin/')
    assert_equal('Hello', mod.foo('Hello'))
  end

  test 'return void' do
    baz = Baz.new
    mth = baz.method(:foo2)
    mod = Yadriggy::C.compile(mth, 'ret_void_test', './testbin/')
    mod.foo2('return void')
  end

  test 'return int' do
    baz = Baz.new
    mth = baz.method(:foo3)
    mod = Yadriggy::C.compile(mth, 'ret_int_test', './testbin/')
    assert_equal(7, mod.foo3(7))
  end

  test 'int array' do
    baz = Baz.new
    mth = baz.method(:bar)
    mod = Yadriggy::C.compile(mth, 'int_array_test', './testbin/')
    a = IntArray.new(5)
    a[0] = 13
    a[1] = 17
    a[2] = 123
    a[3] = 456
    assert_equal(123, a[2])
    assert_equal(456, a[3])
    assert_equal(123, mod.bar(a, 2, 789))
    assert_equal(789, a[3])
  end

  test 'float array with type arrayof(Float)' do
    baz = Baz.new
    mth = baz.method(:baz)
    mod = Yadriggy::C.compile(mth, 'float_array_test', './testbin/')
    a = FloatArray.new(5)
    a[0] = 13.4
    a[1] = 17.8
    a[2] = 123.4
    a[3] = 456.7
    assert_equal(123.4, a[2])
    assert_equal(456.7, a[3])
    assert_equal(123.4, mod.baz(a, 2, 789.1))
    assert_equal(789.1, a[3])
  end

  test 'float array with type FloatArray' do
    baz = Baz.new
    mth = baz.method(:baz2)
    mod = Yadriggy::C.compile(mth, 'float_array_test2', './testbin/')
    a = FloatArray.new(5)
    a[0] = 13.4
    a[1] = 17.8
    a[2] = 123.4
    a[3] = 456.7
    b = IntArray.new(3)
    b[0] = 1
    assert_equal(123.4, a[2])
    assert_equal(456.7, a[3])
    assert_equal(123.4, mod.baz2(a, b, 2, 789.1))
    assert_equal(789.1, a[3])
  end

  test 'return an array' do
    baz = Baz.new
    mth = baz.method(:baz3)
    mod = Yadriggy::C.compile(mth, 'return_array', './testbin/')
    a = FloatArray.new(5)
    a[0] = 3.14
    b = mod.baz3(a)
    assert_equal(3.14, b[0])
  end

  class Baz32
    include Yadriggy::C::CType
    def foo(a, b) ! Float32
      typedecl a: arrayof(Float32), b: Float32Array
      return a[0] + b[0]
    end

    def bar(a) ! Float32Array
      typedecl a: arrayof(Float32)
      return a
    end
  end

  test 'float32 array' do
    baz = Baz32.new
    mth = baz.method(:foo)
    mod = Yadriggy::C.compile(mth, 'float32_array', './testbin/')
    a = Float32Array.new(5)
    a[0] = 3.14
    b = Float32Array.new(5)
    b[0] = 1.0
    v = mod.foo(a, b)
    assert_equal(4.14, v.round(3))

    mth = baz.method(:bar)
    mod2 = Yadriggy::C.compile(mth, 'float32_array2', './testbin/')
    a = Float32Array.new(4)
    a2 = mod2.bar(a)
    assert_equal(a, a2)
  end

  class Baz32error
    # include Yadriggy::C::CType
    def foo(a, b) ! Float32
      typedecl a: arrayof(Float32), b: Float32Array
      return a[0] + b[0]
    end
  end

  test 'float32 array error' do
    baz = Baz32error.new
    mth = baz.method(:foo)
    assert_raise do
      Yadriggy::C.compile(mth, 'float32_array_error', './testbin/')
    end
  end

  class LoopExample
    include Yadriggy::C::CType

    def foo(a, n) ! Int
      typedecl a: arrayof(Int), n: Int
      sum = 0
      for i in 0...n
        sum += a[i]
      end
      return sum
    end

    def foo2(a, n) ! Int
      typedecl a: arrayof(Int), n: Int
      sum = 0
      for i in 0..(n-1)
        sum += a[i]
      end
      return sum
    end

    def bar(a, n) ! Float
      typedecl a: arrayof(Float), n: Int
      sum = 0.0
      while n > 0
        sum += a[n - 1]
        n -= 1
      end
      return sum
    end
  end

  test 'for-loop' do
    le = LoopExample.new
    mod = Yadriggy::C.compile(le, 'for-loop_test', './testbin/')
    a = IntArray.new(4)
    a[0] = 1
    a[1] = 2
    a[2] = 3
    a[3] = 4
    assert_equal(10, mod.foo(a, a.size))
    assert_equal(10, mod.foo2(a, a.size))

    b = FloatArray.new(5)
    b[0] = 1
    b[1] = 2
    b[2] = 3
    b[3] = 4
    b[4] = 5
    assert_equal(15.0, mod.bar(b, b.size))
  end

  class ReturnArray < Yadriggy::C::Program
    def test(a) ! arrayof(Int)
      typedecl a: IntArray
      return foo6(foo5(foo4(foo3(foo2(foo(a))))))
    end

    def foo(a) ! arrayof(Int)
      typedecl a: IntArray
      return a
    end

    def foo2(a) ! IntArray
      typedecl a: IntArray
      return a
    end

    def foo3(a)
      typedecl a: IntArray, return: arrayof(Int)
      return a
    end

    def foo4(a)
      typedecl a: IntArray, return: IntArray
      return a
    end

    def foo5(a) ! arrayof(Int)
      typedecl a: IntArray, return: arrayof(Int)
      return a
    end

    def foo6(a) ! IntArray
      typedecl a: IntArray, return: IntArray
      return a
    end
  end

  test 'various forms for array types' do
    a = IntArray.new(3)
    assert_equal(a, ReturnArray.compile(dir: './testbin/').test(a))
  end

  class Baz2
    include Yadriggy::C::CType

    def foo(s) ! Int
      typedecl s: Int
      printf('foo(%d)\n', s)
      printf('foo(%d, %d)\n', s, s)
      return s
    end

    # a foreign function is not translated into a C function.
    # A call to a foreign function is translated into a call to the
    # C function with the same name.  The parameter types are not
    # checked.
    def printf(s) ! Void
      # foreign: <return type>
      typedecl s: String, foreign: Void
      puts s
    end
  end

  test 'foreign function' do
    baz2 = Baz2.new
    mth = baz2.method(:foo)
    mod = Yadriggy::C.compile(mth, 'foreign_test', './testbin/')
    assert_equal(7, mod.foo(7))
  end

  class Reload
    def foo(i) ! Integer
      typedecl i: Integer
      return i
    end
  end

  class Reload2
    include Yadriggy::C::CType

    def foo(i) ! Integer
      typedecl i: Integer
      return i + 1
    end
  end

  test 'reloading a function will fail' do
    obj = Reload.new
    mth = obj.method(:foo)
    mod = Yadriggy::C.compile(mth, 'reload_test', './testbin/')
    assert_equal(7, mod.foo(7))

    obj2 = Reload2.new
    mth2 = obj2.method(:foo)
    mod2 = Yadriggy::C.compile(mth2, 'reload_test', './testbin/')
    assert_equal(7, mod2.foo(7))  # not 8!

    mod3 = Yadriggy::C.compile(mth2, 'reload_test2', './testbin/')
    assert_equal(8, mod3.foo(7))
    assert_equal(7, mod2.foo(7))
  end

  class CProg < Yadriggy::C::Program
    def initialize()
      # All instance variables have to be initialized here.
      # Their types are determined by the types of their initial values.
      @array = IntCArray.new(3, 3)
    end

    def foo() ! Int
      @array[1,1] = 7
      @array[1,1] += 10
      return @array[1,1]
    end
  end

  test 'C Array' do
    assert_equal(17, CProg.compile('CArray', dir: './testbin/').foo())
    load './testbin/carray.rb'
  end

  class CProg2 < Yadriggy::C::Program
    def initialize()
      @array = IntCArray.new(3, 3)
      @array2 = IntCArray.new(3, 3)
    end

    def foo() ! Int
      @array[1,1] = 7
      @array2 = @array    # bad assignment
      return @array2[1,1]
    end
  end

  test 'C Array assignment' do
    prog2 = CProg2.new
    prog2_ast = Yadriggy::reify(prog2.method(:foo))
    assert(syn.check(prog2_ast.tree), 'syntax check')
    assert_raise do
      tchecker.typecheck(prog2_ast.tree)
    end
  end

  class CProg3 < Yadriggy::C::Program
    def foo() ! Int
      t = current_time
      return t
    end

    def bar() ! Int
      return current_time
    end
  end

  test 'call a method without an argument' do
    mod = CProg3.compile(dir: './testbin/')
    puts mod.foo
    puts mod.bar
  end

  class CProg4 < Yadriggy::C::Program
    def foo(a) ! Int
      typedecl a: Int
      a += 3
      return a
    end

    def bar(a) ! Int
      typedecl a: IntArray
      a += 3  # type error
      return a
    end

    def baz(a) ! Int
      typedecl a: Int
      a = a % 3
      return a
    end

    def baz2(a) ! Float
      typedecl a: Float
      a = a % 3  # type error
      return a
    end

  end

  test '+= operator' do
    prog = CProg4.new
    mod = Yadriggy::C.compile(prog.method(:foo), 'plus_eq_test', './testbin/')
    assert_equal(10, mod.foo(7))

    prog_ast = Yadriggy::reify(prog.method(:bar))
    assert(syn.check(prog_ast.tree), 'syntax check1')
    assert_raise do
      tchecker.typecheck(prog_ast.tree)
    end

    prog_ast = Yadriggy::reify(prog.method(:baz))
    assert(syn.check(prog_ast.tree), 'syntax check2')
    tchecker.typecheck(prog_ast.tree)

    prog_ast = Yadriggy::reify(prog.method(:baz2))
    assert(syn.check(prog_ast.tree), 'syntax check3')
    assert_raise do
      tchecker.typecheck(prog_ast.tree)
    end
  end

  class CProg5 < Yadriggy::C::Program
    def foo(a, n) ! Int
      typedecl a: IntArray, n: Int
      sum = 0
      n.times {|i| sum += a[i] }
      return sum
    end
  end

  test 'times call' do
    a = IntArray.new(3)
    a[0] = 1; a[1] = 2; a[2] = 3
    sum = a.to_a.reduce(:+)
    assert_equal(sum, CProg5.compile(dir: './testbin/').foo(a, a.size))
  end

  class MathTest < Yadriggy::C::Program
    def test_sqrtf(a) ! Float
      typedecl a: Float
      return sqrtf(a)
    end

    def test_sqrt(a) ! Float
      typedecl a: Float
      return sqrt(a)
    end

    def test_expf(a) ! Float
      typedecl a: Float
      return expf(a)
    end

    def test_exp(a) ! Float
      typedecl a: Float
      return exp(a)
    end

    def test_logf(a) ! Float
      typedecl a: Float
      return logf(a)
    end

    def test_log(a) ! Float
      typedecl a: Float
      return log(a)
    end
  end

  test 'math function call' do
    mod = MathTest.compile(dir: './testbin/')
    mtest = MathTest.new
    assert_equal(mtest.test_sqrtf(4.0).round(3), mod.test_sqrtf(4.0).round(3))
    assert_equal(mtest.test_sqrt(4.0).round(3), mod.test_sqrt(4.0).round(3))

    assert_equal(mtest.test_expf(4.0).round(3), mod.test_expf(4.0).round(3))
    assert_equal(mtest.test_exp(4.0).round(3), mod.test_exp(4.0).round(3))

    assert_equal(mtest.test_logf(4.0).round(3), mod.test_logf(4.0).round(3))
    assert_equal(mtest.test_log(4.0).round(3), mod.test_log(4.0).round(3))
  end

  test 'free variables' do
    n = 7
    assert_equal(7, Yadriggy::C.run(dir: './testbin/') { return n })
    assert_equal(8, Yadriggy::C.run(dir: './testbin/') do ! Integer
                   m = n
                   return m + 1
                 end)
    assert_equal(7, Yadriggy::C.run(dir: './testbin/') do ! Integer
                   m = n
                   n = 'free'
                   return m
                 end)
  end

end
