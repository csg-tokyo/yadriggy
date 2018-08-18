require 'test_helper'
require 'yadriggy/ruby_typeinfer.rb'
require 'yadriggy/ast_test2.rb'


module Yadriggy
  class TypeInferenceTester < Test::Unit::TestCase
    typechecker = RubyTypeInferer.new

    test 'typecheck a free variable' do
      a = 3
      ast = Yadriggy::reify { a }.tree.body
      t = typechecker.typecheck(ast)
      assert_false(InstanceType.role(t).nil?)
      assert(t <= RubyClass::Integer)
    end

    test 'typecheck an assignment' do
      a = 3
      ast = Yadriggy::reify { b = a; b }.tree.body
      t = typechecker.typecheck(ast)
      assert(InstanceType.role(t).nil?)
      assert(t <= RubyClass::Integer)
    end

    test 'typecheck two assignments' do
      a = 3
      ast = Yadriggy::reify { b = a; b = b + 1 }.tree.body
      assert(typechecker.typecheck(ast).exact_type <= Integer)
    end

    test 'typecheck a bad assignment' do
      a = 3
      ast = Yadriggy::reify { b = a; b = 'test' }.tree.body
      assert_raise do
        typechecker.typecheck(ast)
      end
    end

    test 'typecheck a constant' do
      A = 3
      ast = Yadriggy::reify { A }.tree.body
      t = typechecker.typecheck(ast)
      assert_false(InstanceType.role(t).nil?)
      assert(t <= RubyClass::Integer)
    end

    test 'typecheck a number' do
      ast = Yadriggy::reify { 3 }.tree.body
      t = typechecker.typecheck(ast)
      assert_false(InstanceType.role(t).nil?)
      assert(t <= RubyClass::Integer)
    end

    test 'typecheck assign' do
      ast = Yadriggy::reify {
        x = 3
        y = x + 1.0
      }.tree.body
      t = typechecker.typecheck(ast)
      t2 = typechecker.type(ast.expressions[0].left)  # x's type
      assert_false(LocalVarType.role(t2).nil?)
      assert(t2 <= RubyClass::Integer)
      t3 = typechecker.type(ast.expressions[1].left)  # y's type
      assert(t3 <= RubyClass::Float)
      t4 = typechecker.type(ast.expressions[1].right.left) # 2nd x's type
      assert(t4 <= RubyClass::Integer)
      assert_equal(ast.expressions[0].left,
                   LocalVarType.role(t4)&.definition)

      # the two occurrences of x are bound to the same LocalVarType object.
      assert_equal(typechecker.type(ast.expressions[0].left),
                   typechecker.type(ast.expressions[1].right.left))
    end

    test 'typecheck assign 1' do
      ast = Yadriggy::reify {
        x = 3
        x = 7
      }.tree.body
      t = typechecker.typecheck(ast)

      # the two occurrences of x are bound to the same LocalVarType object.
      assert_equal(t, typechecker.type(ast.expressions[0].left))

      # t.definition is Undef since a value is assigned to x twice.
      assert_equal(Yadriggy::Undef, LocalVarType.role(t)&.definition)
    end

    test 'typecheck assign 2' do
      ast = Yadriggy::reify {
        x = 3
        x = 1.0
      }.tree.body
      assert_raise do
        typechecker.typecheck(ast)
      end
    end

    test 'typecheck assign 3' do
      ast = Yadriggy::reify {
        x = 3
        x = nil
      }.tree.body
      t = typechecker.typecheck(ast)
      assert(t == RubyClass::Integer)
    end

    test 'typecheck Integer#+=' do
      ast = Yadriggy::reify {
        x = 3
        x += x
      }.tree.body
      t = typechecker.typecheck(ast)    # x's type
      assert(t == RubyClass::Integer)

      assert_equal(Yadriggy::Undef, LocalVarType.role(t)&.definition)
    end

    class TypeInfer01
      def f=(x)
        @x = x
      end
      def f()
        @x
      end
      def get()
        @x
      end

      def get2()
        @x = 3
        @y = 7
        return @y
      end

      def get3()
        @x += 1
        @y -= 1
      end

      def get4()
        @z
      end
    end

    test 'typecheck TypeInfer01#=' do
      mt = Yadriggy::MethodType.new([Integer], Integer)
      typechecker.add_typedef(TypeInfer01)[:f=] = mt
      mt2 = Yadriggy::MethodType.new([], Integer)
      typechecker.add_typedef(TypeInfer01)[:f] = mt2
      typechecker.add_typedef(TypeInfer01)[:@z] = RubyClass::Integer

      a = TypeInfer01.new
      ast = Yadriggy::reify {
        a.f = 3
      }.tree.body
      t = typechecker.typecheck(ast)
      assert(t == RubyClass::Integer)

      b = TypeInfer01.new
      b.f = 7
      ast2 = Yadriggy::reify { b.f }.tree.body
      t2 = typechecker.typecheck(ast2)
      assert(t2 == RubyClass::Integer)

      ast3 = Yadriggy::reify(b.method(:get)).tree.body
      t3 = typechecker.typecheck(ast3)
      assert(t3 == RubyClass::Integer)

      ast4 = Yadriggy::reify(b.method(:get2)).tree.body
      t4 = typechecker.typecheck(ast4)
      assert(t4 == RubyClass::Integer)

      ast5 = Yadriggy::reify(b.method(:get3)).tree.body
      t5 = typechecker.typecheck(ast5)
      assert(t5 == RubyClass::Integer)

      ast6 = Yadriggy::reify(b.method(:get4)).tree.body
      t6 = typechecker.typecheck(ast6)
      assert(t6 == RubyClass::Integer)

      c = TypeInfer01.new
      c.f = 7
      ast7 = Yadriggy::reify { b.f += 1 }.tree.body
      t7 = typechecker.typecheck(ast7)
      assert(t7 == RubyClass::Integer)
    end

    test 'typecheck a global variable' do
      ast = Yadriggy::reify do
        $yad_typeinfer = 3
        $yad_typeinfer = 7
        $yad_typeinfer += 1
        $yad_typeinfer
      end.tree.body
      t = typechecker.typecheck(ast)
      assert(t == RubyClass::Integer)
    end

    test 'typecheck a binary expression' do
      ast = Yadriggy::reify { 5 + 3 }.tree.body
      t = typechecker.typecheck(ast)
      assert(t == RubyClass::Integer)
    end

    test 'various ruby code' do
      syn = Yadriggy::Syntax.ruby_syntax
      tchecker = RubyTypeInferer.new(syn)

      Yadriggy::check_all_asts do |ast|
        assert(syn.check(ast.tree), ast.tree.source_location_string)
        tchecker.typecheck(ast.tree)
      end
    end
  end
end
