require 'test_helper'
require 'yadriggy/py'

class Py_Tester < Test::Unit::TestCase
  test 'call a local function' do
    r = Yadriggy::Py::run do
      def foo(a)
        return a + 1
      end
      foo(3)
    end
    assert_equal(4, r)
  end

  def add10(a)
    return a + 10
  end

  test 'call an external function' do
    r = Yadriggy::Py::run { add10(7) }
    assert_equal(17, r)
  end

  test 'True, False, None' do
    assert_equal(true, Yadriggy::Py::run { print(true); true })
    assert_equal(true, Yadriggy::Py::run { print(True); True })
    assert_equal(false, Yadriggy::Py::run { print(False); False })
    assert_equal(nil, Yadriggy::Py::run { print(nil); nil })
    assert_equal(nil, Yadriggy::Py::run { print(None); None })
  end

  test 'unary' do
    assert_equal(-7, Yadriggy::Py::run { -(3 + 4) })
    assert_equal(false, Yadriggy::Py::run { !true })    # ! is not available in Python
  end

  test 'binary' do
    assert_true(Yadriggy::Py::run { 3 > 0 && 2 > 0 })    # && -> and
    assert_true(Yadriggy::Py::run { 3 == 0 || 2 > 0 })   # || -> or
    assert_true(Yadriggy::Py::run { 3 .in [1, 2, 3] })   # in
    assert_equal(3, Yadriggy::Py::run { 13 .idiv 4 })    # //
    assert_equal([1, 2], Yadriggy::Py::run { list(1..3) })   # range(1,3)
    assert_equal([1, 2], Yadriggy::Py::run { list(range(1, 3)) })
  end

  test 'assign' do
    assert_equal(3, Yadriggy::Py::run { a = 3; a })
    assert_equal(7, Yadriggy::Py::run { a, b = 3, 4; a + b })
    assert_equal(PyCall::tuple([3, 4]), Yadriggy::Py::run { a = 3, 4; a })
    assert_raise do
      Yadriggy::Py::run { a, b = 1, 2, 3 }
    end
  end

  test 'lambda' do
    v = Yadriggy::Py::run do
      f = -> (x) { x + 1 }
      f(3)
    end
    assert_equal(4, v)
  end

  test 'lambda 2' do
    v = Yadriggy::Py::run do
      f = lambda {|x| x + 1 }
      f(3)
    end
    assert_equal(4, v)
  end

  test 'labmda and call' do
    # in Ruby, this should be ->(x){x+1}.call(3) or ->(x){x+1}.(3)
    assert_equal(4, Yadriggy::Py::run { ->(x) { x + 1 }.__call__(3) })
  end

  test 'list literal' do
    assert_equal([1, 2, 3], Yadriggy::Py::run { [1, 2, 3] })
  end

  test 'tuple literal' do
    assert_equal(PyCall::tuple(), Yadriggy::Py::run { tuple() })
    assert_equal(PyCall::tuple([1]), Yadriggy::Py::run { tuple(1) })
    assert_equal(PyCall::tuple([1]), Yadriggy::Py::run { tuple(1,) })
    assert_equal(PyCall::tuple([1, 2]), Yadriggy::Py::run { tuple(1, 2) })
  end

  test 'call a Python function' do
    assert_equal(3, Yadriggy::Py::run { len([10, 2, 3]) })
  end

  test 'list accesses' do
    assert_equal(3, Yadriggy::Py::run { a = [1, 2, 3]; a[2] })
    assert_equal([2, 3], Yadriggy::Py::run { a = [1, 2, 3, 4]; a[1..3] })    # a[1:3]
    assert_equal([2, 3, 4], Yadriggy::Py::run { a = [1, 2, 3, 4]; a[1.._] }) # a[1:]
    assert_equal([1, 2], Yadriggy::Py::run { a = [1, 2, 3, 4]; a[_..2] })    # a[:2]
    assert_raise do
      Yadriggy::Py::run { a = [1, 2, 3, 4]; a[1...3] }
    end
    assert_raise do
      Yadriggy::Py::run { a[1, 2] }
    end
  end

  test 'list comprehension' do
    assert_equal([0, 1, 2],
                 Yadriggy::Py::run { [for i in range(0,3) do i end] })
    assert_equal([0, 1, 2],
                 Yadriggy::Py::run { [for i in 0..3 do i end] })
  end

  test 'hash literal or dict' do
    res = Yadriggy::Py::run do
      hash = { 'foo' => 1, 'bar' => 2 }   # {foo: 1, bar: 2}
      hash['foo']
    end
    assert_equal(1, res)
  end

  test 'hash literal or dict 2' do
    res = Yadriggy::Py::run do
      hash = { foo:1, bar: 2 }
      hash['foo']
    end
    assert_equal(1, res)
  end

  test 'sequence' do
    res = Yadriggy::Py::run { a = 1; b = 2; a + b }
    assert_equal(3, res)
  end

  test 'sequence 2' do
    res = Yadriggy::Py::run do
      a = 1
      b = 2
      a + b
    end
    assert_equal(3, res)
  end

  test 'if statements' do
    res = Yadriggy::Py::run do
      a = 1
      if a
        b = 3
      else
        b = -3
      end
      c = b > 0 ? 5 : -5
      c > 0 ? c : -c
    end
    assert_equal(5, res)

    assert_raise do
      Yadriggy::Py::run { a = if true then 1 else 2 end }
    end
  end

  test 'for statement' do
    k = 3
    res = Yadriggy::Py::run do
      a = [1, 20, 300, 4000, 50000, 600000]
      sum = 0
      for i in range(0, k)
        sum += a[i]
      end
      sum
    end
    assert_equal(321, res)
  end

  test 'a free variable of string type' do
    str = 'hello'
    sym = :world
    res = Yadriggy::Py::run { str + sym }
    assert_equal(str + sym.to_s, res)
  end

  test 'a free variable of list type' do
    lst = [1, 2, 3, [:a, 10]]
    res = Yadriggy::Py::run { lst[1] + lst[3][1] }
    assert_equal(12, res)
  end

  test 'import and property' do
    Yadriggy::Py::Import.import('sys')
    Yadriggy::Py::run { print(sys::version) }   # sys.version
  end

  list_free_var = [1, 2, 3]
  list_free_var2 = list_free_var

  def add_list(a, b)
    b[0] = 10
    return a[0] + b[1]
  end

  test 'free variables in function definition' do
    res = Yadriggy::Py::run { add_list(list_free_var, list_free_var2) }
    assert_equal(12, res)
  end
end
