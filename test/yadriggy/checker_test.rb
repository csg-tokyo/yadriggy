require 'test_helper'
require 'yadriggy/checker.rb'

module Yadriggy
  class CheckTester < Test::Unit::TestCase
    class TestChecker < Checker
      rule(Number) do
        3
      end
    end

    class TestChecker2 < TestChecker
      rule(Number) do
        proceed(ast) + 40
      end
    end

    class TestChecker3 < TestChecker2
      rule(Number) do
        proceed(ast) + 500
      end
    end

    class TestChecker4 < TestChecker
      rule(StringLiteral) do
        7
      end
    end

    test 'check proceed' do
      ast = Yadriggy::reify { 3 }.tree.body
      assert_equal(3, TestChecker.new.check(ast))
      assert_equal(43, TestChecker2.new.check(ast))
      assert_equal(543, TestChecker3.new.check(ast))
      assert_equal(3, TestChecker4.new.check(ast))

      ast2 = Yadriggy::reify { 'foo' }.tree.body
      assert_equal(7, TestChecker4.new.check(ast2))
    end

    class TestChecker5 < Checker
      rule(Number) do
        'num'
      end
      rule(Binary) do
        v1 = check(ast.left)
        v2 = check(ast.right)
        "#{v1}#{ast.op}#{v2}"
      end
    end

    test 'nested call to check' do
      ast = Yadriggy::reify { 1 + 3 }.tree.body
      assert_equal('num+num', TestChecker5.new.check(ast))
      ast2 = Yadriggy::reify { k + 1 }.tree.body
      assert_raise do
        TestChecker5.new.check(ast2)
      end
    end
  end
end

