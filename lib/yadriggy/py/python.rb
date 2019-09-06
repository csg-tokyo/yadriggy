# Copyright (C) 2018- Shigeru Chiba.  All rights reserved.

require 'pycall'
require 'yadriggy'
require 'yadriggy/py/syntax'
require 'yadriggy/py/codegen'
require 'yadriggy/py/py_typechecker'
require 'yadriggy/py/import'

module Yadriggy
  module Py
    def self.run(&blk)
      ast = Yadriggy::reify(blk)
      Syntax.raise_error unless Syntax.check(ast.tree)
      checker = PyTypeChecker.new
      checker.typecheck(ast.tree.body)
      PyCall.exec(Import.source)
      init_free_variables(checker)
      gen = CodeGen.new(Printer.new, checker)
      ast.astrees.each {|t| gen.print(t) unless t == ast }
      last_expr = generate_except_last(ast.tree.body, gen)
      PyCall.exec(gen.printer.output)
      unless last_expr.nil?
        PyCall.eval(CodeGen.new(Printer.new, checker).print(last_expr).printer.output)
      end
    end

    def self.init_free_variables(checker)
      unless checker.references.empty?
        gen = CodeGen.new(Printer.new, checker)
        args = gen.print_free_vars_initializer
        PyCall.exec(gen.printer.output)
        f = PyCall.eval(CodeGen::FreeVarInitName)
        f.call(args)
      end
    end

    def self.generate_except_last(ast, gen)
      if expr_or_subtype(ast)
        ast
      elsif ast.is_a?(Exprs) && expr_or_subtype(ast.expressions[-1])
        ast.expressions[0...-1].each do |e|
          gen.print(e)
          gen.newline
        end
        ast.expressions[-1]
      else
        gen.print(ast)
        nil
      end
    end

    def self.expr_or_subtype(ast)
      if ast.nil? || ast.is_a?(Assign)
        false
      else
        usertype = ast.usertype
        if usertype == :fun_call
          ast.name.name != 'print'
        else
          usertype == :expr || usertype == :lambda_call || usertype == :ternary
        end
      end
    end
  end
end
