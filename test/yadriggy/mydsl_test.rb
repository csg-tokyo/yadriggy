require 'test_helper'
require 'yadriggy'

# Sample implementation of a DSL.
#
class MyDSLTester < Test::Unit::TestCase
  include Yadriggy

  @syntax = Yadriggy::define_syntax do
    Binary <= { left: Binary | Number, op: :+, right: Number }
    Block  <= { body: Number | Binary }
  end

  class MyTypeChecker < TypeChecker
    rule(Binary) do
      t1 = type(ast.left)
      t2 = type(ast.right)
      if t1 == t2
        t1
      else
        DynType
      end
    end

    rule(Block) do
      type(ast.body)
    end

    rule(Number) do
      ast.value.class
    end
  end

  class MyEvaluator < Checker
    rule(Binary) do
      v1 = check(ast.left)
      v2 = check(ast.right)
      v1 + v2
    end

    rule(Block) do
      check(ast.body)
    end

    rule(Number) do
      ast.value
    end
  end

  def self.compile(&block)
    tchecker = MyTypeChecker.new
    evaluator = MyEvaluator.new
    ast = Yadriggy::reify(block)
    return false unless @syntax.check(ast.tree)
    return false unless tchecker.typecheck(ast.tree) < Numeric
    evaluator.check(ast.tree)
  end

  test 'my DSL' do
    v = MyDSLTester.compile { 3 + 2 + 1 }
    puts "result #{v}"
    assert(v)
  end

end

