require 'test_helper'
require 'yadriggy/source_code'

module Yadriggy
  class GetAstTester < Test::Unit::TestCase
    sub_test_case 'SourceCode class' do
      setup do
        @lambda_expr = lambda {|x,y| x + y + 1 }
      end

      test 'get_sexp ' do
        src = SourceCode.get_sexp(@lambda_expr)
        # pp src
        assert(!src.nil?, "get_sexp() cannot retrieve")
      end

      test 'get_sexp 2 ' do
        p = lambda {|x| x + 1 }
        q = lambda { p }
        src = SourceCode.get_sexp(q.call)
        # pp src
        assert(!src.nil?, "get_sexp() cannot retrieve")
      end

      test 'get_sexp 3 ' do
        p = lambda {|x|
          lambda {|y| x + y }
        }
        src = SourceCode.get_sexp(p)
        src2 = SourceCode.get_sexp(p.call(3))
        # pp src
        # pp src2
        assert_false(src == src2,
                     "get_sexp() cannot distinguish a nested lambda")
      end

      test 'get_sexp 4 ' do
        p = lambda do |x|
          lambda do |y| x + y end
        end
        src = SourceCode.get_sexp(p)
        src2 = SourceCode.get_sexp(p.call(3))
        assert_false(src == src2,
                     "get_sexp() cannot distinguish a nested do-lambda")
      end

      test 'get_sexp 5 ' do
        p = lambda do |x|
          lambda do
            x + 3
          end
        end
        src = SourceCode.get_sexp(p)
        src2 = SourceCode.get_sexp(p.call(3))
        assert_false(src == src2,
                     "get_sexp() cannot distinguish a nested do-lambda")
      end

      test 'get_sexp 6 ' do
        p = lambda do
          lambda do
            3
          end
        end
        src = SourceCode.get_sexp(p)
        src2 = SourceCode.get_sexp(p.call)
        assert_false(src == src2,
                     "get_sexp() cannot distinguish a nested do-lambda")
      end

      test 'get_sexp 7 ' do
        p = lambda do |x|
          ->() do
            3
          end
        end
        src = SourceCode.get_sexp(p)
        src2 = SourceCode.get_sexp(p.call(3))
        assert_false(src == src2,
                     "get_sexp() cannot distinguish a nested do-lambda")
      end

      test 'get_sexp 8 ' do
        p = lambda do
          lambda do |x|
            x + 3
          end
        end
        src = SourceCode.get_sexp(p)
        src2 = SourceCode.get_sexp(p.call)
        assert_false(src == src2,
                     "get_sexp() cannot distinguish a nested do-lambda")
      end

      def foo(lst)
        lst.each do |e|
          puts e
        end
      end

      test 'difficult def' do
        src = SourceCode.get_sexp(method(:foo))
        assert_equal(:def, src[1][0], "get_sexp() cannot capture foo()")
      end
    end

    sub_test_case 'Cons class' do
      test 'Cons.list etc. ' do
        lst = SourceCode::Cons.list(1, 2, 3)
        assert_equal(3, lst.size)
        assert_equal(1, lst.head)
        assert_equal(2, lst.tail.head)
        assert_equal(3, lst.tail.tail.head)
        assert_nil(lst.tail.tail.tail)
      end

      test 'Cons.append! ' do
        lst = SourceCode::Cons.list(1, 2, 3)
        lst2 = SourceCode::Cons.list(4, 5)
        SourceCode::Cons.append!(lst, lst2)
        assert_equal(5, lst.size)
        assert_equal(4, lst.tail.tail.tail.head)
      end

      test 'Cons.each ' do
        lst = SourceCode::Cons.list(1, 2, 3)
        sum = 0
        lst.each {|e| sum += e }
        assert_equal(6, sum)
      end

      test 'Cons.fold ' do
        lst = SourceCode::Cons.list(1, 2, 3)
        sum = lst.fold(0) {|a, e| a + e }
        assert_equal(6, sum)
      end
    end
  end
end
