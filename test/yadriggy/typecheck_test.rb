require 'test_helper'
require 'yadriggy/typecheck.rb'
require 'yadriggy/ruby_typecheck.rb'
require 'yadriggy/ast_test2.rb'


module Yadriggy
  class TypecheckTester < Test::Unit::TestCase
    typechecker = RubyTypeChecker.new

    test 'typecheck a ruby variable' do
      a = 3
      ast = Yadriggy::reify { a }.tree.body
      assert(typechecker.typecheck(ast).exact_type <= Integer)
    end

    test 'typecheck an assignment' do
      a = 3
      ast = Yadriggy::reify { b = a; b }.tree.body
      assert(typechecker.typecheck(ast).exact_type <= Integer)
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

    test 'typecheck a call' do
      a = 7
      def foo(i)
        100 + i
      end
      ast = Yadriggy::reify { foo(a * 10) }.tree.body
      assert(typechecker.typecheck(ast) == DynType)
    end

    test 'typecheck a cal to a non-existing method' do
      a = 7
      ast = Yadriggy::reify { barbar(a * 10) }.tree.body
      assert_raise do
        typechecker.typecheck(ast) == DynType
      end
    end

    Val3 = "3"
    Val4 = "4"

    test 'references' do
      ast = Yadriggy::reify { a = Val3 }.tree.body
      assert(typechecker.typecheck(ast) <= RubyClass::String)
      assert(typechecker.references.include?(Val3))
      assert_false(typechecker.references.include?(Val4))
      typechecker.clear_references
      assert_false(typechecker.references.include?(Val3))
    end

    class TypeCheck2 < RubyTypeChecker
      rule(Number) do
        if proceed(ast) <= CommonSuperType.new(Integer)
          RubyClass::String
        else
          RubyClass::Numeric
        end
      end
    end

    test 'check proceed' do
      ast = Yadriggy::reify { 3 }.tree.body
      tcheck = TypeCheck2.new
      assert(tcheck.typecheck(ast).exact_type == String)
    end

    class TypeCheck3 < TypeChecker
      rule(Number) do
        proceed(ast)
      end
    end

    test 'check no proceed' do
      ast = Yadriggy::reify { 3 }.tree.body
      assert_raise do
        TypeCheck3.new.typecheck(ast)
      end
    end

    test 'various ruby code' do
      syn = Yadriggy::Syntax.ruby_syntax
      tchecker = RubyTypeChecker.new(syn)

      Yadriggy::check_all_asts do |ast|
        assert(syn.check(ast.tree), ast.tree.source_location_string)
        tchecker.typecheck(ast.tree)
      end
    end

  end
end
