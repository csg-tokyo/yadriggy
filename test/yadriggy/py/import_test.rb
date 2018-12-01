require 'test_helper'
require 'yadriggy/py/import'

module Yadriggy
  class PyImportTester < Test::Unit::TestCase
    include Yadriggy::Py::PyImport

    def source_code
      Yadriggy::Py::Import.source
    end

    test 'get source and clear' do
      pyimport('foo.bar')
      assert_equal("\nimport foo.bar", source_code)
      assert_equal('', source_code)
    end

    test 'import' do
      pyimport('foo')
      pyimport('bar.baz')
      assert_equal("\nimport foo\nimport bar.baz", source_code)
    end

    test 'import two modules' do
      pyimport('foo').import('bar.baz')
      assert_equal("\nimport foo, bar.baz", source_code)
    end

    test 'import as' do
      pyimport('foo.bar').as('fb')
      assert_equal("\nimport foo.bar as fb", source_code)
    end

    test 'two import as' do
      pyimport('foo.bar').as('fb').import('baz').as('bz')
      assert_equal("\nimport foo.bar as fb, baz as bz", source_code)
    end

    test 'import foo as f as oo' do
      assert_raise do
        pyimport('foo').as('f').as('oo')
      end
    end

    test 'from foo import bar as b' do
      pyfrom('foo').import('bar').as('b')
      assert_equal("\nfrom foo import bar as b", source_code)
    end

    test 'from foo import bar; from bar import foo' do
      pyfrom('foo').import('bar')
      pyfrom('bar').import('foo')
      assert_equal("\nfrom foo import bar\nfrom bar import foo", source_code)
    end

    test 'from foo as f' do
      assert_raise do
        pyfrom('foo').as('f')
      end
    end

  end
end
