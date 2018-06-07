require 'test_helper'

module Yadriggy
  class TypeTester < Test::Unit::TestCase
    test 'role' do
      assert(DynType.equal?(DynType.role(DynType)))
      assert_nil(DynType.role(Void))
      assert(Void.equal?(Void.role(Void)))
      assert_nil(Void.role(DynType))

      assert(RubyClass.role(RubyClass::String).equal?(RubyClass::String))
      assert_nil(RubyClass.role(InstanceType.new('aa')))
      assert(RubyClass.role(LocalVarType.new(RubyClass::String, nil))
                      .equal?(RubyClass::String))

      assert_nil(InstanceType.role(DynType))
      assert_nil(InstanceType.role(Void))

      t = InstanceType.new(String)
      assert(t.equal?(InstanceType.role(t)))
      assert_nil(InstanceType.role(CommonSuperType.new(String)))

      assert(t.equal?(InstanceType.role(t)))
      t2 = ResultType.new(t, nil)
      assert(t.equal?(InstanceType.role(t2)))
      assert(t2.equal?(ResultType.role(t2)))

      utypes1 = [RubyClass::String, RubyClass::Numeric]
      ut1 = UnionType.new(utypes1)
      assert(ut1.equal?(UnionType.role(LocalVarType.new(ut1, nil))))

      mt1 = MethodType.new(nil, [ Integer, String ], Float)
      assert_equal(nil, mt1.method_def)
      assert_equal([RubyClass::Integer, RubyClass::String], mt1.params)
      assert_equal(RubyClass::Float, mt1.result_type)
      assert(MethodType.role(mt1).equal?(mt1))
      assert(MethodType.role(LocalVarType.new(mt1, nil)).equal?(mt1))

      ct1 = CompositeType.new(Array, [RubyClass::Integer])
      assert(ct1.equal?(CompositeType.role(ct1)))
      assert(CompositeType.role(LocalVarType.new(ct1, nil)).equal?(ct1))
    end

    test 'type equivalence' do
      assert(DynType == DynType)
      assert(Void == Void)
      assert_false(DynType == RubyClass::String)
      assert_false(Void == RubyClass::String)
      assert_false(RubyClass::String == Void)
      assert_false(DynType == Void)
      assert_false(Void == DynType)

      assert(Void != DynType)
      assert_false(Void != Void)

      assert(Void == ResultType.new(Void, nil))
      assert(ResultType.new(Void, nil) == Void)

      assert(RubyClass::String == RubyClass[String])
      assert(RubyClass[String] == RubyClass::String)
      assert_false(RubyClass::String == RubyClass::Numeric)
      assert(ResultType.new(RubyClass::Integer, nil) == RubyClass::Integer)
      assert(RubyClass::Integer == ResultType.new(RubyClass::Integer, nil))

      utypes0 = [RubyClass::String, RubyClass::Numeric]
      utypes1 = [RubyClass::String, RubyClass::Numeric]
      utypes2 = [RubyClass::String, RubyClass::Numeric, RubyClass::String]
      ut0 = UnionType.new(utypes0)
      ut1 = UnionType.new(utypes1)
      ut2 = UnionType.new(utypes2)
      assert(ut0 == ut1)
      assert(ut0 == ut2)

      assert(CommonSuperType.new(String) == CommonSuperType.new(String))
      assert_false(CommonSuperType.new(String) == RubyClass::String)
      assert_false(RubyClass::String == CommonSuperType.new(String))

      assert(CommonSuperType.new(String) ==
             LocalVarType.new(CommonSuperType.new(String), nil))
      assert(LocalVarType.new(CommonSuperType.new(String), nil) ==
             CommonSuperType.new(String))

      assert_false(InstanceType.new('baz') == InstanceType.new('bazz'))
      assert_false(InstanceType.new('baz') == RubyClass::String)
      s0 = 'bazzzz'
      assert(InstanceType.new(s0) == InstanceType.new(s0))
      assert(InstanceType.new(s0) == ResultType.new(InstanceType.new(s0), nil))
      assert(ResultType.new(InstanceType.new(s0), nil) == InstanceType.new(s0))
      assert(InstanceType.new(s0) == ResultType.new(InstanceType.new(s0), nil))

      t = InstanceType.new('barr')
      assert(t == ResultType.new(t, nil))
      assert(RubyClass::String == ResultType.new(RubyClass::String, nil))

      ts1 = [ RubyClass::String, RubyClass::Integer, InstanceType.new('foo') ]
      ts2 = [ RubyClass::String, RubyClass::Integer, RubyClass::String ]
      ts3 = [ RubyClass::String, RubyClass::Integer, InstanceType.new('baz') ]

      assert(ts1 != ts2)
      assert_false(ts1 == ts2)
      assert_false(ts1 == ts3)

      mt0 = MethodType.new(nil, DynType, DynType)
      mt1 = MethodType.new(nil, [ Integer, String ], Float)
      mt2 = MethodType.new(nil, [ Integer, String ], Float)

      assert_false(mt0 ==mt1)
      assert(mt1 == mt2)

      utypes1 = [RubyClass::String, RubyClass::Numeric]
      utypes2 = [RubyClass::String, RubyClass::Numeric, RubyClass::String]
      ut1 = UnionType.new(utypes1)
      ut2 = UnionType.new(utypes2)
      ut3 = UnionType.new([ut1, ut2])
      ut4 = UnionType.new([RubyClass::String, RubyClass::NilClass])

      assert_equal(2, ut2.types.size)
      assert(ut1 == ut2)
      assert_equal(2, ut3.types.size)
      assert_equal(utypes1, ut3.types)
      assert(ut1 == ut2)
      assert(ut2 == ut1)
      assert_false(ut1 == ut4)

      ct1 = CompositeType.new(Array, [RubyClass::Integer])
      ct2 = CompositeType.new(Array, [RubyClass::Integer])
      rc1 = RubyClass::Array
      assert(ct1 == ct2)
      assert_false(ct1 == rc1)
    end

    test 'subtyping relation' do
      assert(DynType <= DynType)
      assert(Void <= Void)
      assert(Void <= DynType)
      assert(RubyClass::String <= DynType)

      assert_false(DynType <= Void)
      assert_false(RubyClass::String <= Void)

      ut1 = UnionType.new([RubyClass::String, RubyClass::Numeric])
      ut2 = UnionType.new([RubyClass::String, RubyClass::NilClass])
      ut3 = UnionType.new([ut1, ut2])

      assert(ut1 <= DynType)
      assert_false(ut1 <= Void)
      assert(ut1 <= ut3)
      assert(ut2 <= ut3)
      assert_false(ut1 <= ut2)

      assert(RubyClass::String <= ut1)
      assert_false(ut1 <= RubyClass::String)

      cst_string = CommonSuperType.new(String)
      cst_object = CommonSuperType.new(Object)
      cst_numeric = CommonSuperType.new(Numeric)
      ut_cst = UnionType.new([CommonSuperType.new(String),
                               CommonSuperType.new(Numeric)])

      assert(cst_string <= DynType)
      assert_false(cst_string <= Void)
      assert_false(cst_string <= ut1)
      assert_false(ut1 <= cst_string)
      assert(RubyClass::String <= cst_string)
      assert_false(cst_string <= RubyClass::String)
      assert(cst_string <= cst_object)
      assert_false(cst_object <= cst_string)
      assert(cst_string <= ut_cst)
      assert(CommonSuperType.new(Integer) <= cst_numeric)
      assert(RubyClass[Integer] <= cst_numeric)
      assert(RubyClass[Integer] <= CommonSuperType.new(Integer))
      assert(RubyClass[Integer] <= cst_numeric)

      str = 'foo'
      ins_t = InstanceType.new(str)
      ins_t2 = InstanceType.new(str)
      ins_t3 = InstanceType.new('bar')

      assert(ins_t <= ins_t2)
      assert_false(ins_t <= ins_t3)
      assert(ins_t <= RubyClass::String)
      assert(ins_t <= cst_string)
      assert_false(InstanceType.new(10) <= InstanceType.new(17))
      assert(InstanceType.new(10) <= CommonSuperType.new(Integer))
      assert(InstanceType.new(10) <= CommonSuperType.new(Integer))

      ut4 = UnionType.new([RubyClass::String, CommonSuperType.new(Numeric)])
      assert(InstanceType.new(10) <= ut4)

      assert(RubyClass::Integer <= RubyClass::Numeric)
      assert_false(RubyClass::Integer <= RubyClass[Numeric])

      mht1 = MethodType.new(nil, DynType, DynType)
      mht2 = MethodType.new(nil, DynType, RubyClass::String)
      mht3 = MethodType.new(nil, [RubyClass::Integer],
                            CommonSuperType.new(Object))
      assert(mht2 <= mht1)
      assert_false(mht1 <= mht2)
      assert(mht2 <= DynType)
      assert_false(DynType <= mht2)
      assert_false(mht2 <= Void)
      assert(mht2 <= mht3)
      assert_false(mht3 <= mht2)
      assert(mht2 <= UnionType.new([RubyClass::String, DynType]))

      assert(LocalVarType.new(ins_t, nil) <= LocalVarType.new(ins_t2, nil))
      assert(ins_t <= LocalVarType.new(ins_t2, nil))
      assert(LocalVarType.new(ins_t, nil) <= ins_t2)

      ct1 = CompositeType.new(Array, [RubyClass::Integer])
      ct2 = CompositeType.new(Array, [RubyClass::Integer])
      ct3 = CompositeType.new(Array, [CommonSuperType.new(Numeric)])
      assert(ct1 <= ct2)
      assert(ct1 <= ct3)
      assert(ct1 <= RubyClass::Array)
      assert_false(RubyClass::Array <= ct1)
      assert_false(ct1 <= RubyClass::String)
    end

    test 'nil type' do
      assert(CommonSuperType.new(NilClass) <= DynType)
      assert(CommonSuperType.new(NilClass) <= CommonSuperType.new(String))
      assert_false(CommonSuperType.new(String) <=
                   CommonSuperType.new(NilClass))

      assert(RubyClass::NilClass <= DynType)
      assert(RubyClass::NilClass <= RubyClass::String)
      assert_false(RubyClass::String <= RubyClass::NilClass)

      assert(RubyClass::NilClass <= CommonSuperType.new(String))
      assert_false(CommonSuperType.new(NilClass) <= RubyClass::String)

      assert_false(InstanceType.new(nil) <= InstanceType.new('foo'))
      assert(InstanceType.new(nil) <= RubyClass::String)
      assert_false(RubyClass::NilClass <= InstanceType.new('foo'))
    end

    test 'super type' do
      assert_equal(nil, DynType.supertype)
      assert_equal(CommonSuperType.new(Numeric),
                   CommonSuperType.new(Integer).supertype)
      assert_equal(CommonSuperType.new(String), RubyClass::String.supertype)
      assert_equal(RubyClass::String, InstanceType.new('foo').supertype)
      ct1 = CompositeType.new(Array, [RubyClass::Integer])
      assert_equal(RubyClass::Array, ct1.supertype)
      lt1 = LocalVarType.new(InstanceType.new('foo'), nil)
      assert_equal(RubyClass::String, lt1.supertype)
    end

    test 'type name' do
      assert_equal('DynType', DynType.name)
      assert_equal('Void', Void.name)

      assert_equal('String', RubyClass::String.name)

      ut = UnionType.new([RubyClass::String, RubyClass::Integer])
      assert_equal('(String|Integer)', ut.name)

      ut2 = UnionType.new([RubyClass::String])
      assert_equal('(String)', ut2.name)

      assert_equal('String+', CommonSuperType.new(String).name)
      assert_equal('foo', InstanceType.new('foo').name)

      mt = MethodType.new(nil, [ Integer, String ], Float)
      assert_equal('(Integer,String)->Float', mt.name)

      mt1 = MethodType.new(nil, [ Integer ], Float)
      assert_equal('(Integer)->Float', mt1.name)

      mt2 = MethodType.new(nil, [], Float)
      assert_equal('()->Float', mt2.name)

      mt3 = MethodType.new(nil, DynType, Float)
      assert_equal('DynType->Float', mt3.name)

      ct = CompositeType.new(Array, Integer)
      assert_equal('Array<Integer>', ct.name)

      ct1 = CompositeType.new(Array, [Integer])
      assert_equal('Array<Integer>', ct1.name)

      ct2 = CompositeType.new(Array, [Integer, String])
      assert_equal('Array<Integer,String>', ct2.name)

    end

  end
end
