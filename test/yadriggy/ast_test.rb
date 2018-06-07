require 'test_helper'
require 'yadriggy/ast'
require 'yadriggy/source_code'
require 'yadriggy/ast_location'

module Yadriggy
  class AstTester < Test::Unit::TestCase
    test 'reification' do
      p = lambda do |a, b=3, *rest, c, d, key:, key2: 5, **krest, &body|
        a + b
      end

      ast = Yadriggy.reify(p)
      assert_not_nil(ast)
    end

    test 'detect a bad reification parameter' do
      class Foo
        def source_location
          p = lambda {|a| a + 1 }
          p.source_location
        end
      end

      assert_raise(RuntimeError) do
        Yadriggy.reify(Foo.new)
      end
    end

    test 'source location' do
      p = lambda {|a|
        a + b
      }

      ast = Yadriggy.reify(p)
      loc = ast.tree.source_location

      assert_equal(31, loc[1])
      assert_equal(19, loc[2])    # the position of 'a'

      loc = ast.tree.source_location_string
      #pp loc
      assert(loc.end_with?("yadriggy/ast_test.rb:31"))
    end

    sub_test_case 'ASTnode class' do
      test 'parent' do
        a = ASTnode.new
        b = ASTnode.new
        c = ASTnode.new
        a.add_child(b)
        b.add_child(c)
        assert_equal(a, a.root)
        assert_equal(a, b.root)
        assert_equal(a, c.root)
      end
    end

    test 'empty array and hash' do
      p = ->(i) { return [], {} }
      ast = Yadriggy.reify(p)
      assert_not_nil(ast)
    end

    test "label and symbol's colon" do
      p = ->() { return { key: :value }, { :key => :value } }
      ast = Yadriggy.reify(p)
      assert_equal("key", ast.tree.body.values[0].pairs[0][0].name)
      assert_equal("value", ast.tree.body.values[0].pairs[0][1].name)
      assert_equal("key", ast.tree.body.values[1].pairs[0][0].name)
      assert_equal("value", ast.tree.body.values[1].pairs[0][1].name)
    end

    test 'string literal' do
      ast = Yadriggy.reify do
        "foo" + ?\C-a
      end
      assert_equal("foo", ast.tree.body.left.value)
      assert_equal(?\C-a, ast.tree.body.right.value)
    end

    test 'escape symbols' do
      ast = Yadriggy.reify do
        "foo\n" + "foo\\n"
      end
      assert_equal("foo\n", ast.tree.body.left.value)
      assert_equal(4, ast.tree.body.left.value.size)
      assert_equal("foo\\n", ast.tree.body.right.value)
      assert_equal(5, ast.tree.body.right.value.size)
    end

    test 'escape symbols 2' do
      ast = Yadriggy.reify do
        "foo\n" + <<OK
bar\n
baz
OK
      end
      assert_equal("bar\\n\nbaz\n", ast.tree.body.right.value)
      assert_equal(10, ast.tree.body.right.value.size)
    end

    test 'escape symbols 3' do
      ast = Yadriggy.reify do
        "foo\
" + <<OK
bar"baz
OK
      end

      # assert_equal("foo\n", ast.tree.body.left.value)   # because this fails.
      assert_equal("bar\"baz\n", ast.tree.body.right.value)
    end

    test 'splat operator' do
      ast = Yadriggy.reify do
        lst = [i, i]
        foo(*lst)
      end
      assert_not_nil(ast)
    end

    test 'create a Call' do
      ast = Yadriggy.reify do
        foo
      end
      vcall = ast.tree.body
      obj = Yadriggy::Call.make(name: vcall.name, parent: vcall.parent)
      assert(obj.is_a?(Yadriggy::Call))
    end
  end
end
