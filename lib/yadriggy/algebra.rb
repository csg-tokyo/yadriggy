# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'yadriggy/eval'

module Yadriggy

  # An interface inspired by object algebra (and tag-less final)
  #
  class Algebra

    def initialize(expr)
      EvalAlgebra.new(self).evaluate(expr)
    end

    def nil_value()
      raise NotImplementedError.new('nil_value')
    end

    def name(name, line_no, column)
      raise NotImplementedError.new('name')
    end

    def identifier_or_call(name, line_no, column)
      name(name, line_no, column)
    end

    def identifier(name, line_no, column)
      identifier_or_call(name, line_no, column)
    end

    def reserved(name, line_no, column)
      name(name, line_no, column)
    end

    def const(name, line_no, column)
      name(name, line_no, column)
    end

    def label(name, line_no, column)
      name(name, line_no, column)
    end

    def symbol(name, line_no, column)
      raise NotImplementedError.new('symbol')
    end

    def global_variable(name, line_no, column)
      name(name, line_no, column)
    end

    def instance_variable(name, line_no, column)
      name(name, line_no, column)
    end

    def variable_call(name, line_no, column)
      identifier_or_call(name, line_no, column)
    end

    def super_method(expr)
      raise NotImplementedError.new('super_method')
    end

    def number(value, line_no, column)
      raise NotImplementedError.new('number')
    end

    # exprs() sequentially processes each expression in a series
    # of expressions.
    # So, for example, { e1, e2, ..., e_n } is
    # processed by exprs(.. exprs(exprs(nil, e1), e2).., e_n).
    # In other words, it is by
    # [e1, e2, ..., e_n].inject(nil) {|r,e| exprs(r, evaluate(e))}.
    #
    # RESULT specifies the result of the previous expression.
    # It is nil if EXPR is the first expression.
    #
    def exprs(result, expr)
      raise NotImplementedError.new('exprs')
    end

    # CONTENTS is an array of the results of evaluating
    # each component.
    #
    def string_interpolation(contents)
      raise NotImplementedError.new('string_interpolation')
    end

    def string_literal(value, line_no, column)
      raise NotImplementedError.new('string_literal')
    end

    # A constant value in a scope, such as Foo::Bar.
    #
    def const_path_ref(scope, name)
      raise NotImplementedError.new('const_path_ref')
    end

    # A constant value in a scope as a L-value.
    #
    def const_path_field(scope, name)
      const_path_ref(scope, name)
    end

    def unary(op, expr)
      raise NotImplementedError.new('unary')
    end

    def binary(left, op, right)
      raise NotImplementedError.new('binary')
    end

    def dots(left, op, right)
      binary(left, op, right)
    end

    # @param [Object|Array] left   the left value.
    # @param [Symbol] op           the operator.
    # @param [Object|Array] right  the right value.
    def assign(left, op, right)
      if left.is_a?(Array) || right.is_a?(Array)
        raise NotImplementedError.new('multiple assignment')
      else
        binary(left, op, right)
      end
    end

    def array_ref(array, index)
      raise NotImplementedError.new('array')
    end

    # Array reference as L-value
    #
    def array_ref_field(array, index)
      array_ref(array, index)
    end

    # An expression surrounded with ().
    #
    def paren(element)
      raise NotImplementedError.new('paren')
    end

    # An array literal.
    # ELEMENTS is an array.
    #
    def array(elements)
      raise NotImplementedError.new('array')
    end

    # PAIRS is an array of pairs.  Each pair is
    # an array where the first element is a key
    # and the second element is a value.
    #
    def hash(pairs)
      raise NotImplementedError.new('hash')
    end

    # Method call.
    # ARGS is an array.  BLOCK is a thunk.
    #
    def call(receiver, op, name, args, block_arg, block)
      raise NotImplementedError.new('call')
    end

    # Method call without parentheses.
    # ARGS is an array.  BLOCK is a thunk.
    #
    def command(receiver, op, name, args, block_arg, block)
      call(receiver, op, name, args, block_arg, block)
    end

    # if, unless, modifier if/unless, and ternary if (?:)
    # THEN_EXPRS is a thunk.
    # ALL_ELSIF is an array of pairs of elsif condition and its body.
    # Both are thunks.
    # ELSE_EXPRS is a thiuk or nil.
    #
    def conditional(op, cond, then_exprs, all_elsif, else_exprs)
      raise NotImplementedError.new('conditional')
    end

    # while, until, and modifier while/until.
    # COND and BODY are thunks.
    #
    def loop(op, cond, body)
      raise NotImplementedError.new('loop')
    end

    # for loop.
    # BODY is a thunk.
    #
    def for_loop(var, set, body)
      raise NotImplementedError.new('for_loop')
    end

    # break, next, redo, retry.
    #
    def break_out(op, values)
      raise NotImplementedError.new('break_out')
    end

    # An expression with return.
    #
    def return_values(values)
      raise NotImplementedError.new('return_values')
    end

    # A block.
    # BODY is a thunk.
    #
    def block(params, optionals, rest_params, params_after_rest, keywords,
              rest_of_keywords, block_param, body)
      raise NotImplementedError.new('block')
    end

    # A lambda expression.
    # BODY is a thunk.
    #
    def lambda_expr(params, optionals, rest_params, params_after_rest,
                    keywords, rest_of_keywords, block_param, body)
      block(params, optionals, rest_params, params_after_rest,
            keywords, rest_of_keywords, block_param, body)
    end

    # rescue-else-ensure-end.
    # BODY, NESTED_RESCUE, ELSE_CLAUSE, and ENSURE_CLAUSE are
    # thunks.
    #
    def rescue_end(types, parameter, body, nested_rescue,
                   else_clause, ensure_clause)
      raise NotImplementedError.new('rescue_end')
    end

    def begin_end(body, rescue_clause)
      raise NotImplementedError.new('begin_end')
    end

    # def.
    #
    # BODY and RESCUE_CLAUSE are thunks.
    #
    def define(name, params, optionals, rest_of_params, params_after_rest,
               keywords, rest_of_keywords, block_param,
               body, rescue_clause)
      raise NotImplementedError.new('define')
    end

    def module_def(name, body, rescue_clause)
      raise NotImplementedError.new('module_def')
    end

    def class_def(name, superclass, body, rescue_clause)
      raise NotImplementedError.new('class_def')
    end

    def singular_class_def(name, body, rescue_clause)
      raise NotImplementedError.new('singular_class_def')
    end

    # A whole program.
    #
    # ELEMENTS is the result of processing the program elements.
    #
    def program(elements)
      raise NotImplementedError.new('program')
    end
  end

  # Evaluator for Algebra
  #
  class EvalAlgebra < Eval
    # Initializes.
    #
    # @param [Algebra] algebra
    def initialize(algebra)
      @algebra = algebra
    end

    def evaluate(expr)
      if expr.nil?
        nil_value(nil)
      else
        expr.accept(self)
      end
    end

    def nil_value(expr)
      @algebra.nil_value
    end

    def name(expr)
      raise  'should never happen'
    end

    def identifier(expr)
      @algebra.identifier(expr.name, expr.line_no, expr.column)
    end

    def reserved(expr)
      @algebra.reserved(expr.name, expr.line_no, expr.column)
    end

    def const(expr)
      @algebra.const(expr.name, expr.line_no, expr.column)
    end

    def label(expr)
      @algebra.label(expr.name, expr.line_no, expr.column)
    end

    def symbol(expr)
      @algebra.symbol(expr.name, expr.line_no, expr.column)
    end

    def global_variable(expr)
      @algebra.global_variable(expr.name, expr.line_no, expr.column)
    end

    def instance_variable(expr)
      @algebra.instance_variable(expr.name, expr.line_no, expr.column)
    end

    def variable_call(expr)
      @algebra.variable_call(expr.name, expr.line_no, expr.column)
    end

    def super_method(expr) @algebra.super_method end

    def number(expr)
      @algebra.number(expr.value, expr.line_no, expr.column)
    end

    def exprs(expr)
      expr.expressions.inject(nil) do |result, e|
        @algebra.exprs(result, evaluate(e))
      end
    end

    def paren(expr)
      @algebra.paren(evaluate(expr.expression))
    end

    def array(expr)
      @algebra.array(expr.elements.map {|e| evaluate(e)})
    end

    def string_interpolation(expr)
      @algebra.string_interpolation(expr.contents.map {|e| evaluate(e) })
    end

    def string_literal(expr)
      @algebra.string_literal(expr.value, expr.line_no, expr.column)
    end

    def const_path_ref(expr)
      @algebra.const_path_ref(expr.scope, expr.name)
    end

    def const_path_field(expr)
      @algebra.const_path_field(expr.scope, expr.name)
    end

    def unary(expr)
      @algebra.unary(expr.op, evaluate(expr.operand))
    end

    def binary(expr)
      @algebra.binary(evaluate(expr.left), expr.op, evaluate(expr.right))
    end

    def dots(expr)
      @algebra.dots(evaluate(expr.left), expr.op, evaluate(expr.right))
    end

    def assign(expr)
      right = if expr.right.is_a?(Array)
                expr.right.map {|e| evaluate(e) }
             else
                evaluate(expr.right)
             end
      left = if expr.left.is_a?(Array)
                expr.left.map {|e| evaluate(e) }
             else
                evaluate(expr.left)
             end
      @algebra.assign(left, expr.op, right)
    end

    def array_ref(expr)
      @algebra.array_ref(evaluate(expr.array),
                         expr.indexes.map {|e| evaluate(e) })
    end

    def array_ref_field(expr)
      @algebra.array_ref_field(evaluate(expr.array),
                               expr.indexes.map {|e| evaluate(e) })
    end

    def hash(expr)
      @algebra.hash(expr.pairs.map {|p| p.map {|e| evaluate(e) }})
    end

    def call(expr)
      @algebra.call(evaluate(expr.receiver), expr.op, expr.name,
                    expr.args.map {|e| evaluate(e) },
                    evaluate(expr.block_arg),
                    lambda { evaluate(expr.block) })
    end

    def command(expr)
      @algebra.command(evaluate(expr.receiver), expr.op, expr.name,
                       expr.args.map {|e| evaluate(e) },
                       evaluate(expr.block_arg),
                       lambda { evaluate(expr.block) })
    end

    def conditional(expr)
      @algebra.conditional(expr.op, evaluate(expr.cond),
                           lambda { evaluate(expr.then) },
                           expr.all_elsif.map do |e|
                             [lambda { evaluate(e[0]) },
                              lambda { evaluate(e[1]) }]
                           end,
                           if expr.else.nil?
                             nil
                           else
                             lambda { evaluate(expr.else) }
                           end)
    end

    def loop(expr)
      @algebra.loop(expr.op, lambda { evaluate(expr.cond) },
                    lambda { evaluate(expr.body) })
    end

    def for_loop(expr)
      @algebra.for_loop(expr.vars, evaluate(expr.set),
                        lambda { evaluate(expr.body) })
    end

    def break_out(expr)
      @algebra.break_out(expr.op, expr.values.map {|e| evaluate(e) })
    end

    def return_values(expr)
      @algebra.return_values(expr.values.map {|e| evaluate(e) })
    end

    def block(expr)
      @algebra.block(expr.params, expr.optionals, expr.rest_of_params,
                     expr.params_after_rest, expr.keywords,
                     expr.rest_of_keywords,
                     expr.block_param, lambda { evaluate(expr.body) })
    end

    def lambda_expr(expr)
      @algebra.lambda_expr(expr.params, expr.optionals, expr.rest_of_params,
                           expr.params_after_rest, expr.keywords,
                           expr.rest_of_keywords,
                           expr.block_param, lambda { evaluate(expr.body) })
    end

    def rescue_end(expr)
      @algebra.rescue_end(expr.types, expr.parameter,
                          lambda { evaluate(expr.body) },
                          lambda { evaluate(expr.nested_rescue) },
                          lambda { evaluate(expr.else) },
                          lambda { evaluate(expr.ensure) })
    end

    def begin_end(expr)
      @algebra.begin_end(lambda { evaluate(expr.body) },
                      if expr.rescue.nil?
                        nil
                      else
                        lambda { evaluate(expr.rescue) }
                      end)
    end

    def define(expr)
      @algebra.define(expr.name, expr.params, expr.optionals,
                      expr.rest_of_params, expr.params_after_rest,
                      expr.keywords, expr.rest_of_keywords,
                      expr.block_param, lambda { evaluate(expr.body) },
                      if expr.rescue.nil?
                        nil
                      else
                        lambda { evaluate(expr.rescue) }
                      end)
    end

    def module_def(expr)
      @algebra.module_def(expr.name, lambda { evaluate(expr.body) },
                          if expr.rescue.nil?
                            nil
                          else
                            lambda { evaluate(expr.rescue) }
                          end)
    end

    def class_def(expr)
      @algebra.class_def(expr.name, expr.superclass,
                         lambda { evaluate(expr.body) },
                          if expr.rescue.nil?
                            nil
                          else
                            lambda { evaluate(expr.rescue) }
                          end)
    end

    def singular_class_def(expr)
      @algebra.singular_class_def(expr.name,
                                  lambda { evaluate(expr.body) },
                                  if expr.rescue.nil?
                                    nil
                                  else
                                    lambda { evaluate(expr.rescue) }
                                  end)
    end

    def program(expr)
      @algebra.program(evaluate(expr.elements))
    end
  end
end
