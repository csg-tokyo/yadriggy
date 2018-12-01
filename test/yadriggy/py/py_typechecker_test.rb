require 'test_helper'
require 'yadriggy/py/py_typechecker.rb'

module Yadriggy
  class PyTypecheckTester < Test::Unit::TestCase
    typechecker = Py::PyTypeChecker.new

    Val3 = [3, 4]
    Val4 = [5, 7]

    test 'references' do
      ast = Yadriggy::reify { a = Val3 }.tree.body
      assert(typechecker.typecheck(ast) == DynType)
      assert(typechecker.references.include?(Val3))
      assert_false(typechecker.references.include?(Val4))
      typechecker.clear_references
      assert_false(typechecker.references.include?(Val3))
    end
  end
end
