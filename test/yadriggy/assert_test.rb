require 'test_helper'
require 'yadriggy/assert'

class TestAssert < Test::Unit::TestCase
  test 'simple power assert' do
    x = 7
    assert_false(Yadriggy::Assert.assert { 7 < 4 })
    assert_false(Yadriggy::Assert.assert { x < 4 })
    assert_false(Yadriggy::Assert.assert { x + 1 < 4 })
    assert_false(Yadriggy::Assert.assert { !!(x < 4) })
  end

  def my_assert(&block)
    Yadriggy::Assert.assert(&block)
  end

  long_arr = [1] * 50
  test 'power assert with a method call' do
    assert_false(my_assert { 7 == 4 })
    assert_false(my_assert { [1, 2, 3].size < 3 })
    assert_false(my_assert { long_arr.size < 3 })
    assert_false my_assert { [1, 2, 3].map{|e| e + 1}.reduce(:+) < 3 }
  end

  class Foo
    def < (a)
      raise 'error'
   end
   def !()
      raise 'unary error'
   end
  end

  test 'power assert with an exception' do
    foo = Foo.new
    assert_raise do
      my_assert{ nil.size > 0 }
    end
    assert_raise do
      my_assert{ 3 > nil.size }
    end
    assert_raise do
      my_assert{ 3 > !nil.size }
    end
    assert_raise do
      my_assert{ [1,2].size(3) }
    end
    assert_raise do
      my_assert{ foo < 3 + 4 }
    end
    assert_raise do
      my_assert{ !foo < 3 + 4 }
    end
  end
end
