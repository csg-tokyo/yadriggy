require 'test_helper'
require 'yadriggy/ast'
require 'yadriggy/source_code'
require 'yadriggy/ast_location'

module Yadriggy
  class CheckAllAst
    class CheckAllAst2
    end
  end

  def self.check_all_asts_f0()
  end

  def self.check_all_asts_f1(i)
    i
  end

  def self.check_all_asts_f2(i, j)
    i
  end

  @@check_ast_const_path = Yadriggy.reify do |e|
    YadAstCheck::A = 3
    ::YadAstCheck000 = 7
    YadAstCheck001 = 3
  end

  @@check_ast_module = Yadriggy.reify do |e|
    module YadAstCheck
    end

    module YadAstCheck2
      def foo(i) i end
    end

    module YadAstCheck3
      def foo(i) i end
    rescue => evar
      evar
    end

    module YadAstCheck4::YadAstCheck5
      def foo(i) i end
    end
  end

  @@check_ast_class = Yadriggy.reify do
    class YadAstCheck01
    end

    class YadAstCheck02 < YadAstCheck01
      def foo(i) i end
    end

    class YadAstCheck03
      def foo(i) i end
    rescue => evar
      evar
    end

    class YadAstCheck04::YadAstCheck05
      def foo(i) i end
    end

    class YadAstCheck04::YadAstCheck06 < YadAstCheck04::YadAstCheck05
      def foo(i) i end
    end

    clazz = YadAstCheck04.new
    class << clazz
      def baz(i) i end
    end
  end

  def self.check_all_asts(&proc)
    code = ->() { nil }
    proc.call(Yadriggy.reify(code))

    code = ->() { 9 }
    proc.call(Yadriggy.reify(code))

    code = ->() { 9.9 }
    proc.call(Yadriggy.reify(code))

    code = ->(i) { i }
    proc.call(Yadriggy.reify(code))

    code = ->() { Const }
    proc.call(Yadriggy.reify(code))

    code = ->() { $g }
    proc.call(Yadriggy.reify(code))

    code = ->() { @i + @@j }
    proc.call(Yadriggy.reify(code))

    code = ->() { self }
    proc.call(Yadriggy.reify(code))

    code = ->() { super }
    proc.call(Yadriggy.reify(code))

    code = ->() { 1 + 0xab + 9.3 }
    proc.call(Yadriggy.reify(code))

    code = ->() { :foo }
    proc.call(Yadriggy.reify(code))

    code = ->() { :"=" }
    proc.call(Yadriggy.reify(code))

    code = ->() { ?\C-a }
    proc.call(Yadriggy.reify(code))

    code = ->() { Yadriggy }
    proc.call(Yadriggy.reify(code))

    code = ->() { Yadriggy::CheckAllAst }
    proc.call(Yadriggy.reify(code))

    code = ->() { ::CheckAllAst }
    proc.call(Yadriggy.reify(code))

    code = ->() { Yadriggy::CheckAllAst::CheckAllAst2 }
    proc.call(Yadriggy.reify(code))

    code = ->(a, b, c, d) do
      a = "hello"
      b = 'hello'
      c = "hello #{x}"
      d = "hello #{x; x + y}"
    end
    proc.call(Yadriggy.reify(code))

    code = ->() do
      a = %q(foobar)
      b = %Q(foobar #{x})
      c = %w(foo bar baz)
      d = %W(abc bar#{x}baz)
    end
    proc.call(Yadriggy.reify(code))

    code = ->() do
      a = %s(foobar baz)
      # b = %i(foo bar baz)   # Ripper produces an S-exp for %w.
      # c = %r(foobar)
    end
    proc.call(Yadriggy.reify(code))

    code = ->(i, j, a, b, c, c2) do
      a = +i + i + 3 + -i
      b = !(i > 3)
      c = 1..2
      c2 = 1...3
      (a + 1) * 2
    end
    proc.call(Yadriggy.reify(code))

    x = 100
    code = ->(i) do
      i = i + 1
      a = i + x
    end
    proc.call(Yadriggy.reify(code))

    code = ->() { [] }
    proc.call(Yadriggy.reify(code))

    i = 100
    code = ->() { [1, 2, i] }
    proc.call(Yadriggy.reify(code))

    code = ->() { {} }
    proc.call(Yadriggy.reify(code))

    code = ->() { {:one => 1, :two => 2} }
    proc.call(Yadriggy.reify(code))

    code = ->() { {one: 1, two: 2} }
    proc.call(Yadriggy.reify(code))

    code = ->(a) { a[0] }
    proc.call(Yadriggy.reify(code))

    code = ->(a) { a[] + a[1,2,3] }
    proc.call(Yadriggy.reify(code))

    code = ->() { check_all_asts_f0 }
    proc.call(Yadriggy.reify(code))

    code = ->() { self.check_all_asts_f0 }
    proc.call(Yadriggy.reify(code))

    code = ->() { check_all_asts_f0() }
    proc.call(Yadriggy.reify(code))

    code = ->(i) { check_all_asts_f1(i) }
    proc.call(Yadriggy.reify(code))

    code = ->(i) { check_all_asts_f2(i, 0) }
    proc.call(Yadriggy.reify(code))

    code = ->(i) { Yadriggy::check_all_asts_f1(i) }
    proc.call(Yadriggy.reify(code))

    code = ->(i) { check_all_asts_f1(i,) }
    proc.call(Yadriggy.reify(code))

    code = ->(i) do
      check_all_asts_f1 i
    end
    proc.call(Yadriggy.reify(code))

    code = ->(i) do
      check_all_asts_f2 i, 0
    end
    proc.call(Yadriggy.reify(code))

    code = ->(i) do
      self.check_all_asts_f1 i
    end
    proc.call(Yadriggy.reify(code))

    code = ->(i) do
      self.check_all_asts_f1 (i) { 3 + 1 }
    end
    proc.call(Yadriggy.reify(code))

    code = ->(i) do
      check_all_asts_f1 (i) { 3 + 1 }
    end
    proc.call(Yadriggy.reify(code))

    code = ->(i) do
      f = lambda {|x| x + 1 }
      f.(3)
    end
    proc.call(Yadriggy.reify(code))

    code = ->(i, j) do
      if i > 0 then
        return i
      end
      j
    end
    proc.call(Yadriggy.reify(code))

    code = ->(i, j) do
      if i > 0 then
        i
      else
        j
      end
    end
    proc.call(Yadriggy.reify(code))

    code = ->(i, j) do
      if i > 0 then
        i
      elsif i > -3
        i + 1
      else
        j
      end
    end
    proc.call(Yadriggy.reify(code))

    code = ->(i, j) do
      if i > 0 then
        i
      elsif i > -3
        i + 1
      elsif i > -5
        i + 2
      else
        j
      end
    end
    proc.call(Yadriggy.reify(code))

    code = ->(i, j) do
      unless i > 0 then
        i
      else
        j
      end
    end
    proc.call(Yadriggy.reify(code))

    code = ->(i, j) do
      i == j ? i : j
    end
    proc.call(Yadriggy.reify(code))

    code = ->(i, j) do
      i += 3 if j > 0
      i
    end
    proc.call(Yadriggy.reify(code))

    code = ->(i, j) do
      i += 3 unless j > 0
      i
    end
    proc.call(Yadriggy.reify(code))

    code = ->(i, j) do
      while i > 0
        i -= 1
        j += 1
      end
      j
    end
    proc.call(Yadriggy.reify(code))

    code = ->(i, j) do
      until i > 10
        i -= 1
        j += 1
      end
      j
    end
    proc.call(Yadriggy.reify(code))

    code = ->(i) do
      i += 1 while i < 10
      i
    end
    proc.call(Yadriggy.reify(code))

    code = ->() do
      j = 0
      for i in 0..10
        j += i
      end
      j
    end
    proc.call(Yadriggy.reify(code))

    code = ->() do
      j = 0
      for i in [1, 2, 3]
        j += i
      end
      j
    end
    proc.call(Yadriggy.reify(code))

    code = ->(i, j) do
      while i > 0
        i -= 1
        redo if j < 0
        break if i < 3
        next if i < 5
      end
      j
    end
    proc.call(Yadriggy.reify(code))

    code = ->(j) do
      for i in 0..j
        break 3 if i < 3
        next 5 if i < 5
      end
    end
    proc.call(Yadriggy.reify(code))

    code = ->(j) do
      for i in 0..j
        break 3, 4 if i < 3
        next 5, 6 if i < 5
      end
    end
    proc.call(Yadriggy.reify(code))

    code = ->(j) { return }
    proc.call(Yadriggy.reify(code))

    code = ->(j) { return j }
    proc.call(Yadriggy.reify(code))

    code = ->(j) { return j, j }
    proc.call(Yadriggy.reify(code))

    code = ->(j) do
      a = lambda { 1 }
      b = lambda {|i| i + 1 }
      c1 = lambda() { 3 }
      c = ->() { 3 }
      d = ->(i) { i + 4 }
      e = ->(i, j) { i + j }
    end
    proc.call(Yadriggy.reify(code))

    code = -> (obj) do
      k = obj.x
      obj.x = k + 1
    end
    proc.call(Yadriggy.reify(code))

    code = -> (i, j) do
      begin
        i + j
      end
    end
    proc.call(Yadriggy.reify(code))

    code = -> (i, j) do
      begin
        i + j
      rescue
        x = 3
      ensure
        y = 3
      end
    end
    ast = Yadriggy.reify(code)
    proc.call(Yadriggy.reify(code))

    code = -> (i, j) do
      begin
        raise "foo" if i < 0
        i + j
      rescue => evar
        x = 3
        retry
      rescue SyntaxError => evar2
        x = 4
      rescue TypeError, StandardError, SyntaxError  => evar2
        x = 5
      else
        x = 0
      ensure
        y = 3
      end
    end
    proc.call(Yadriggy.reify(code))

    code = -> (i, j) do
      def foo(x, y)
        x + y + i + j
      end
    end
    proc.call(Yadriggy.reify(code))

    code = -> (i, j) do
      def self.foo2(x, y)
        x + y
      end
    end
    proc.call(Yadriggy.reify(code))

    code = -> (i, j) do
      def foo3(x, y)
        x + y
      rescue => evar
        evar
      end
    end
    proc.call(Yadriggy.reify(code))

    proc.call(@@check_ast_const_path)
    proc.call(@@check_ast_module)
    proc.call(@@check_ast_class)

    # pp Yadriggy.reify(code)

  end

  class AstTester2 < Test::Unit::TestCase
    test 'all asts' do
      Yadriggy::check_all_asts {|a| assert_not_nil(a) }
    end
  end
end
