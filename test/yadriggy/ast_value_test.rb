require 'test_helper'
require 'yadriggy/ast'
require 'yadriggy/source_code'
require 'yadriggy/ast_value'

module Yadriggy
  class AstValueTester < Test::Unit::TestCase
    class A
      ValueA = 1
    end

    test 'X::Y' do
      Value = 10
      p = lambda do |x|
        V = 100
        V + Value + A::ValueA
      end

      ast = Yadriggy.reify(p)
      assert_not_nil(ast)

      # V = 100
      expr1 = ast.tree.body.expressions[0]
      assert_equal(Undef, expr1.left.value)       # V
      assert_equal(Undef, expr1.left.const_value)       # V

      # V + Value + A::ValueA
      expr2 = ast.tree.body.expressions[1]
      assert_equal(Undef, expr2.left.left.value)  # V
      assert_equal(Undef, expr2.left.left.const_value)  # V
      assert_equal(10, expr2.left.right.value)    # Value
      assert_equal(10, expr2.left.right.const_value)    # Value
      assert_equal(1, expr2.right.value)       # A::ValueA
      assert_equal(1, expr2.right.const_value)       # A::ValueA

      assert_equal(111, p.call(0))
      assert_equal(100, expr1.left.value)       # V
      assert_equal(100, expr1.left.const_value)       # V
      assert_equal(100, expr2.left.left.value)  # V
      assert_equal(100, expr2.left.left.const_value)  # V
    end

    test 'bad X::Y' do
      p = lambda do |x|
        Y
        X::Y
      end

      ast = Yadriggy.reify(p)
      assert_not_nil(ast)

      expr1 = ast.tree.body.expressions[0]
      assert_equal(Undef, expr1.value)
      expr2 = ast.tree.body.expressions[1]
      assert_equal(Undef, expr2.value)
    end

    test 'local variables' do
      p = lambda do |x, y|
        z = y
        x + z
      end

      ast = Yadriggy.reify(p)
      assert_not_nil(ast)

      expr1 = ast.tree.body.expressions[0]
      assert_equal(Undef, expr1.left.value)   # z
      assert_equal(Undef, expr1.right.value)  # y
      expr2 = ast.tree.body.expressions[1]
      assert_equal(Undef, expr2.left.value)   # x
      assert_equal(Undef, expr2.right.value)  # z
    end

    test 'self' do
      class Foo
        def foo
          lambda do |x|
            self
          end
        end
      end
      f = Foo.new
      ast = Yadriggy.reify(f.foo)
      assert_not_nil(ast)
      assert_equal(Foo, ast.tree.body.value.class)
      assert_equal(Foo, ast.tree.body.const_value.class)
    end

    test 'unbound self' do
      class Foo
        def foo2() self end
      end
      ast = Yadriggy.reify(Foo.instance_method(:foo2))  # unbound
      assert_not_nil(ast)
      assert_equal(Undef, ast.tree.body.value)
      f = Foo.new
      ast = Yadriggy.reify(f.method(:foo2))             # bound
      assert_equal(f, ast.tree.body.value)
      assert_equal(f, ast.tree.body.const_value)
    end

    test 'true and false' do
      p = lambda {|x| true && false }
      ast = Yadriggy.reify(p)
      assert_not_nil(ast)
      assert_equal(true, ast.tree.body.left.value)
      assert_equal(false, ast.tree.body.right.value)
      assert_equal(true, ast.tree.body.left.const_value)
      assert_equal(false, ast.tree.body.right.const_value)
    end

    test 'global variable' do
      $yad_global_variable = 17
      p = lambda do |x|
        $yad_global_variable
      end
      ast = Yadriggy.reify(p)
      assert_not_nil(ast)
      assert_equal(17, ast.tree.body.value)
      assert_equal(Undef, ast.tree.body.const_value)
    end

    test 'unknown global variable' do
      p = lambda do |x|
        $yad_global_variable2	# uninitialized global variable
      end
      ast = Yadriggy.reify(p)
      assert_not_nil(ast)
      assert_equal(nil, ast.tree.body.value)
    end

    test 'super' do
      class SuperFoo
        def foo() end
      end

      class SuperFoo2 < SuperFoo
        def foo() super end
      end

      m = SuperFoo.instance_method(:foo)
      ast = Yadriggy.reify(SuperFoo2.instance_method(:foo))
      assert_not_nil(ast)
      assert_equal(m, ast.tree.body.value.context)

      ast2 = Yadriggy.reify(SuperFoo2.new.method(:foo))
      assert_not_nil(ast2)
      sm = ast2.tree.body.value.context
      assert_equal(SuperFoo, sm.owner)
      assert_equal(:foo, sm.name)
    end

    test 'numbers, string literals, and symbols' do
      p = lambda do |x|
        123
        '456'
        :foo
      end
      ast = Yadriggy.reify(p)
      assert_not_nil(ast)
      assert_equal(123, ast.tree.body.expressions[0].value)
      assert_equal('456', ast.tree.body.expressions[1].value)
      assert_equal(:foo, ast.tree.body.expressions[2].value)

      assert_equal(123, ast.tree.body.expressions[0].const_value)
      assert_equal('456', ast.tree.body.expressions[1].const_value)
      assert_equal(:foo, ast.tree.body.expressions[2].const_value)
    end

    test 'the current value of instance variable 1' do
      class Foo
        def initialize
          @foo = 3
        end
        def atfoo() @foo end
      end

      ast = Yadriggy.reify(Foo.new.method(:atfoo))
      assert_equal(3, ast.tree.body.value)
      assert_equal(Undef, ast.tree.body.const_value)

      f = Foo.new
      f.freeze
      ast = Yadriggy.reify(f.method(:atfoo))
      assert_equal(3, ast.tree.body.value)
      assert_equal(3, ast.tree.body.const_value)
    end

    test 'the current value of instance variable 2' do
      class Foo
        @bar = 70
        def self.bar() @bar end
      end

      ast = Yadriggy.reify(Foo.method(:bar))
      assert_equal(70, ast.tree.body.value)
      assert_equal(70, ast.tree.body.value_in_class(Foo))
      assert_equal(Undef, ast.tree.body.const_value)
      assert_equal(Undef, ast.tree.body.const_value_in_class(Foo))
    end

    test 'the current value of instance variable 3' do
      class ImmutableFoo
        @bar = 70
        def self.bar() @bar end
      end

      ImmutableFoo.freeze
      ast = Yadriggy.reify(ImmutableFoo.method(:bar))
      assert_equal(70, ast.tree.body.value)
      assert_equal(70, ast.tree.body.value_in_class(ImmutableFoo))
    end

    test 'the current value of class variable' do
      class Foo
        @@baz = 500
        def baz() @@baz end
      end

      ast = Yadriggy.reify(Foo.new.method(:baz))
      assert_equal(500, ast.tree.body.value)
      assert_equal(500, ast.tree.body.value_in_class(Foo))
      assert_equal(Undef, ast.tree.body.const_value)
      assert_equal(Undef, ast.tree.body.const_value_in_class(Foo))
    end

    test 'the current value of frozen class variable' do
      class ImmutableFoo2
        @@baz = 500
        def baz() @@baz end
      end

      ast = Yadriggy.reify(ImmutableFoo2.new.method(:baz))
      ImmutableFoo2.freeze
      assert_equal(500, ast.tree.body.const_value)
      assert_equal(500, ast.tree.body.const_value_in_class(Foo))
    end

    test 'the value of undefined instance variable' do
      class Foo
        def undef_foo() @undef_foo end
      end

      ast = Yadriggy.reify(Foo.new.method(:undef_foo))
      assert_equal(Undef, ast.tree.body.value)
    end

    test 'the value of a local variable' do
      a = 111
      p = ->(x) { x + a }
      ast = Yadriggy.reify(p)
      assert_equal(Undef, ast.tree.body.left.value)
      assert_equal(a, ast.tree.body.right.value)
      assert_equal(Undef, ast.tree.body.right.const_value)
    end

    test 'undefined local variable' do
      p = ->(x) { z }
      ast = Yadriggy.reify(p)
      assert_equal(Undef, ast.tree.body.value)
    end

    test 'a call without parentheses or arguments' do
      class FooCall
        def foo() end
        def bar() foo end
        def baz() baz2 end
      end

      f = FooCall.new
      ast = Yadriggy.reify(f.method(:bar))
      foo = ast.tree.body.value
      assert_equal(f.method(:foo), foo.context)

      ast2 = ast.reify(f.method(:baz))
      assert_equal(Undef, ast2.tree.body.value)

      ast3 = ast2.reify(FooCall.instance_method(:bar))
      assert_equal(Undef, ast3.tree.body.value)

      # check uniqueness
      assert_equal(foo, ast.tree.body.value)
      assert_equal(Undef, ast.tree.body.const_value)
      assert_equal(ast, ast.reify(f.method(:bar)))
      assert_not_equal(ast, Yadriggy.reify(f.method(:bar)))
    end

    test 'do_invocation in VariableCall' do
      class FooCall2
        def foo() 3 end
        def bar() foo end
      end

      f = FooCall2.new
      ast = Yadriggy.reify(f.method(:bar))
      v = ast.tree.body.do_invocation
      assert_equal(3, v)
    end

    test 'VariableCall 2' do
      a = 7
      def vcall2() 700 end
      ast = Yadriggy.reify { a + vcall2 }

      v = ast.tree.body.left.value  # Identifier
      assert_equal(7, v)
      f = ast.tree.body.right.value # VariableCall
      assert(f.tree.is_a?(Def))
      v2 = ast.tree.body.right.do_invocation
      assert_equal(700, v2)
    end

    test 'unary operator' do
      p = ->() { -7 }
      ast = Yadriggy.reify(p)
      assert_equal(-7, ast.tree.body.value)
      assert_equal(-7, ast.tree.body.const_value)
    end

    test 'unary operator 2' do
      i = 7
      p = ->() { -i }
      ast = Yadriggy.reify(p)
      assert_equal(-7, ast.tree.body.value)
      assert_equal(Undef, ast.tree.body.const_value)
    end

    test 'binary operator' do
      i = 10
      ast = Yadriggy.reify do
        3 + 4 + i
      end
      assert_equal(7, ast.tree.body.left.value)
      assert_equal(7, ast.tree.body.left.const_value)
      assert_equal(17, ast.tree.body.value)
      assert_equal(Undef, ast.tree.body.const_value)
    end

    test 'assign operator' do
      i = 10
      ast = Yadriggy.reify do
        i = 13
      end
      assert_true(ast.tree.body.is_a?(Yadriggy::Assign))
      assert_equal(Undef, ast.tree.body.value)
      assert_equal(Undef, ast.tree.body.const_value)
    end

    test 'method call' do
      class Mcaller
        def foo(i) i end
        def bar(x)
          ->() { foo(x) }
        end
      end

      m = Mcaller.new
      ast = Yadriggy.reify(m.method(:bar))
      assert_equal(m.method(:foo), ast.tree.body.body.value)
    end

    test 'array literal' do
      p = ->() { [1, 2, 3] }
      ast = Yadriggy.reify(p)
      assert_equal([1, 2, 3], ast.tree.body.value)
      assert_equal([1, 2, 3], ast.tree.body.const_value)
    end
  end
end
