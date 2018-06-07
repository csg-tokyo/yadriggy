require 'test_helper'
require 'yadriggy/ast'
require 'yadriggy/algebra'
require 'yadriggy/eval_test'

module Yadriggy
  class ConcreteAlgebra < Algebra
    def nil_value() nil end

    def name(name, line_no, column) name end

    def super_method() :super_method end

    def number(value, line_no, column) value end

    def symbol(value, line_no, column) value end

    def exprs(result, expr) [result, expr] end

    def string_interpolation(contents) contents end

    def string_literal(value, line_no, column) value end

    def const_path_ref(scope, name) [scope, name] end

    def unary(op, right) [op, right] end

    def binary(left, op, right) [left, op, right] end

    def paren(element) element end

    def array(elements) elements end

    def array_ref(array, indexes)
      [array, indexes]
    end

    def hash(pairs) pairs end

    def call(receiver, op, name, args, block_arg, block)
      [receiver, op, name, args, block_arg, block]
    end

    def conditional(op, cond, then_exprs, all_elsif, else_exprs)
      [op, cond, then_exprs, all_elsif, else_exprs]
    end

    def loop(op, cond, body)
      [op, cond, body]
    end

    def for_loop(vars, set, body)
      [vars, set, body]
    end

    def break_out(op, values)
      [op, values]
    end

    def return_values(values)
      values
    end

    def block(params, optionals, rest_params, params_after_rest, keywords,
              rest_of_keywords, block_param, body)
      [params, optionals, rest_params, params_after_rest, keywords,
       rest_of_keywords, block_param, body.call]
    end

    def rescue_end(type, parameter, body, nested_rescue,
                   else_clause, ensure_clause)
      [type, parameter, body, nested_rescue.call, else_clause.call,
       ensure_clause]
    end

    def begin_end(body, rescue_clause)
      [body.call, rescue_clause&.call]
    end

    def define(name, params, optionals, rest_of_params, params_after_rest,
               keywords, rest_of_keywords, block_param,
               body, rescue_clause)
      [name, params, optionals, rest_of_params, params_after_rest,
       keywords, rest_of_keywords, block_param,
       body.call, rescue_clause&.call]
    end

    def module_def(name, body, rescue_clause)
      [name, body, rescue_clause&.call]
    end

    def class_def(name, superclass, body, rescue_clause)
      [name, superclass, body, rescue_clause&.call]
    end

    def singular_class_def(name, body, rescue_clause)
      [name, body, rescue_clause&.call]
    end

    def program(e) e end
  end

  class TestEvalAlgebra < Test::Unit::TestCase
    test 'check all the methods are implemented' do
      e = EvalAlgebra.new(ConcreteAlgebra.new(nil))
      assert_nothing_raised(NotImplementedError,
                            'some methods are not implemented ') do
        Yadriggy.check_implementations(e)
      end
    end
  end
end

