require 'test_helper'
require 'yadriggy/oops'

class Oops_Tester < Test::Unit::TestCase
  module Prog01
    def foo(i) ! Integer
      typedecl i: Integer
      return i + 3
    end

    def bar(i, j) ! Integer
      typedecl i: Integer, j: Integer
      return i + j
    end
  end

  test 'Prog01' do
    FastProg01 = Yadriggy::Oops.compile(Prog01, 'Prog01', './testbin/', 'Prog01')
    assert_equal(11, FastProg01.foo(8))
    assert_equal(23, FastProg01.bar(11, 12))
  end
end
