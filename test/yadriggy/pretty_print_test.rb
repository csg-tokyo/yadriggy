require 'test_helper'
require 'yadriggy/pretty_print'
require 'yadriggy/ast_test2.rb'

module Yadriggy
  class PPTester < Test::Unit::TestCase
    test 'to string' do
      ast = Yadriggy.reify do
        Yadriggy::PPTester
      end
      str = PrettyPrinter.ast_to_s(ast.tree.body)
      assert_equal('Yadriggy::PPTester', str)
    end

    test 'various ruby code' do
      pp = PrettyPrinter.new(Printer.new(2))
      Yadriggy::check_all_asts do |ast|
        pp.print(ast)
        pp.printer.nl
      end
      puts pp.printer.output
    end
  end
end
