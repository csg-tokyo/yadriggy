# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

module Yadriggy

  # abstract evaluator (using visitor pattern)
  #
  class Eval
    def evaluate(expr)
      if expr.nil?
        nil_value(nil)
      else
        expr.accept(self)
      end
      self
    end

    # A root.
    #
    def astree(expr)
      evaluate(expr.tree)
    end

    def nil_value(expr)
      raise NotImplementedError.new('nil_value')
    end

    def name(expr)
      raise NotImplementedError.new('name')
    end

    def identifier_or_call(expr)
      name(expr)
    end

    def identifier(expr)
      identifier_or_call(expr)
    end

    def reserved(expr)
      name(expr)
    end

    def const(expr)
      name(expr)
    end

    def label(expr)
      name(expr)
    end

    def symbol(expr)
      raise NotImplementedError.new('symbol')
    end

    def global_variable(expr)
      name(expr)
    end

    def instance_variable(expr)
      name(expr)
    end

    def variable_call(expr)
      identifier_or_call(expr)
    end

    def super_method(expr)
      raise NotImplementedError.new('super_method')
    end

    def number(expr)
      raise NotImplementedError.new('number')
    end

    # expressions, or progn in Lisp.
    #
    def exprs(expr)
      raise NotImplementedError.new('exprs')
    end

    def paren(expr)
      raise NotImplementedError.new('paren')
    end

    def array(expr)
      raise NotImplementedError.new('array')
    end

    def string_interpolation(expr)
      raise NotImplementedError.new('string_interpolation')
    end

    def string_literal(expr)
      raise NotImplementedError.new('string_literal')
    end

    def const_path_ref(expr)
      raise NotImplementedError.new('const_path_ref')
    end

    def const_path_field(expr)
      const_path_ref(expr)
    end

    def unary(expr)
      raise NotImplementedError.new('unary')
    end

    def binary(expr)
      raise NotImplementedError.new('binary')
    end

    def dots(expr)
      binary(expr)
    end

    def assign(expr)
      if expr.left.is_a?(Array) || expr.right.is_a?(Array)
        raise NotImplementedError.new('multiple assignment')
      else
        binary(expr)
      end
    end

    def array_ref(expr)
      raise NotImplementedError.new('array')
    end

    def array_ref_field(expr)
      array_ref(expr)
    end

    def hash(expr)
      raise NotImplementedError.new('hash')
    end

    def call(expr)
      raise NotImplementedError.new('call')
    end

    def command(expr)
      call(expr)
    end

    def conditional(expr)
      raise NotImplementedError.new('conditional')
    end

    def loop(expr)
      raise NotImplementedError.new('loop')
    end

    def for_loop(expr)
      raise NotImplementedError.new('for_loop')
    end

    def break_out(expr)
      raise NotImplementedError.new('break_out')
    end

    def return_values(expr)
      raise NotImplementedError.new('return_values')
    end

    def block(expr)
      raise NotImplementedError.new('block')
    end

    def lambda_expr(expr)
      block(expr)
    end

    def being_end(expr)
      raise NotImplementedError.new('begin_end')
    end

    # def
    #
    def define(expr)
      raise NotImplementedError.new('define')
    end

    def rescue_end(expr)
      raise NotImplementedError.new('rescue_end')
    end

    def module_def(expr)
      raise NotImplementedError.new('module_def')
    end

    def class_def(expr)
      raise NotImplementedError.new('class_def')
    end

    def singular_class_def(expr)
      raise NotImplementedError.new('singular_class_def')
    end

    def program(expr)
      raise NotImplementedError.new('program')
    end
  end

end
