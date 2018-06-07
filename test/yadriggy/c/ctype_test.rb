require 'test_helper'
require 'yadriggy/c'

class CType_Tester < Test::Unit::TestCase
  include Yadriggy::C::CType

  test 'int array' do
    assert_raise do
      IntCArray.new
    end

    a = IntCArray.new(2,3,4)
    a.debug = true
    a[0,0,0] = 1
    b = a[0,0,0]

    assert_raise { a[0] = 3 }
    assert_raise { a[3,0,0] = 3 }
    assert_raise { a[0,4,0] = 4 }
    assert_raise { a[0,0,5] = 5 }
    assert_raise { a[0,0,0,0] = 0 }
    assert_raise { b = a[3,0,0] }
    assert_raise { c = a[3,0] }
  end

  test 'float array' do
    assert_raise do
      FloatCArray.new
    end

    a = FloatCArray.new(2,3,4)
    a.debug = true
    a[0,0,0] = 1.0
    b = a[0,0,0]

    assert_raise { a[0] = 3.0 }
    assert_raise { a[3,0,0] = 3.0 }
    assert_raise { a[0,4,0] = 4.0 }
    assert_raise { a[0,0,5] = 5.0 }
    assert_raise { a[0,0,0,0] = 0.0 }
    assert_raise { b = a[3,0,0] }
    assert_raise { c = a[3,0] }
  end
end
