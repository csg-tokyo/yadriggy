# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'yadriggy/eval'

module Yadriggy

  # A simple visitor.
  #
  class EvalAll < Eval
    def nil_value(expr) end

    def name(expr) end

    def symbol(expr) end

    def super_method(expr) end

    def number(expr) end

    # expressions, or progn in Lisp.
    #
    def exprs(expr)
      expr.expressions.each {|e| evaluate(e) }
    end

    def paren(expr)
      evaluate(expr.expression)
    end

    def array(expr)
      expr.elements.each {|e| evaluate(e) }
    end

    def string_interpolation(expr)
      expr.contents.each {|e| evaluate(e) }
    end

    def string_literal(expr) end

    def const_path_ref(expr)
      evaluate(expr.scope)
      evaluate(expr.name)
    end

    def unary(expr)
      evaluate(expr.operand)
    end

    def binary(expr)
      evaluate(expr.left)
      evaluate(expr.right)
    end

    def hash(expr)
      expr.pairs.each {|p| p.each {|e| evaluate(e) }}
    end

    def call(expr)
      evaluate(expr.receiver)
      expr.args.each {|e| evaluate(e) }
      evaluate(expr.block_arg)
      evaluate(expr.block)
    end

    def array_ref(expr)
      evaluate(expr.array)
      expr.indexes.each {|e| evaluate(e) }
    end

    def conditional(expr)
      evaluate(expr.cond)
      evaluate(expr.then)
      expr.all_elsif.each do |e|
        evaluate(e[0])	# condition
        evaluate(e[1])  # elsif body
      end
      evaluate(expr.else) unless expr.else.nil?
    end

    def loop(expr)
      evaluate(expr.cond)
      evaluate(expr.body)
    end

    def for_loop(expr)
      evaluate(expr.set)
      evaluate(expr.body)
    end

    def break_out(expr)
      expr.values.each {|e| evaluate(e) }
    end

    def return_values(expr)
      expr.values.each {|e| evaluate(e) }
    end

    def block(expr)
      parameters(expr)
      evaluate(expr.body)
    end

    def begin_end(expr)
      evaluate(expr.body)
      evaluate(expr.rescue)
    end

    # def
    #
    def define(expr)
      evaluate(expr.singular)
      evaluate(expr.name)
      parameters(expr)
      evaluate(expr.body)
      evaluate(expr.rescue)
    end

    def rescue_end(expr)
      evaluate(expr.body)
      evaluate(expr.nested_rescue)
      evaluate(expr.else)
      evaluate(expr.ensure)
    end

    def module_def(expr)
      evaluate(expr.name)
      evaluate(expr.body)
      evaluate(expr.rescue)
    end

    def class_def(expr)
      evaluate(expr.name)
      evaluate(expr.superclass)
      evaluate(expr.body)
      evaluate(expr.rescue)
    end

    def singular_class_def(expr)
      evaluate(expr.name)
      evaluate(expr.body)
      evaluate(expr.rescue)
    end

    def program(expr)
      evaluate(expr.elements)
    end

    private
    def parameters(expr)
      expr.params.each {|e| evaluate(e) }
      expr.optionals.each {|p| p.each {|e| evaluate(e) }}
      evaluate(expr.rest_of_params)
      expr.params_after_rest.each {|e| evaluate(e) }
      expr.keywords.each {|e| evaluate(e[0]); evaluate(e[1]) }
      evaluate(expr.rest_of_keywords)
      evaluate(expr.block_param)
    end
  end
end
