# Copyright (C) 2018- Shigeru Chiba.  All rights reserved.

# Environment variable PYTHON specifies the name of the Python command.
# It has to be Python 3.  If it is not specified, PyCall invokes 'python3'.
ENV['PYTHON'] = 'python3' if ENV['PYTHON'].nil?

require 'pycall'
require 'yadriggy'
require 'yadriggy/py/codegen'
require 'yadriggy/py/py_typechecker'
require 'yadriggy/py/import'

module Yadriggy
  module Py

    Syntax = Yadriggy.define_syntax do
      expr  = Name | Number | Super | Binary | Unary | ternary |
                StringLiteral | Lambda |
                ArrayLiteral | Paren | lambda_call | fun_call | ArrayRef | HashLiteral
      stmnt = Return | ForLoop | Loop | if_stmnt | Break |
                 BeginEnd | Def | ModuleDef
      exprs = Exprs | stmnt | expr

      Name = { name: String }
      Number     = { value: Numeric }
      VariableCall     = Name
      InstanceVariable = nil
      GlobalVariable   = nil
      Reserved   = Name
      Const      = Name
      Binary     = { left: expr, op: Symbol, right: expr }
      ArrayRef   = { array: expr, indexes: expr }
      ArrayRefField  = ArrayRef
      Assign     = { left: [expr] | expr, op: Symbol,
                     right: [expr] | expr }
      Dots       = Binary
      Unary      = { op: Symbol, operand: expr }
      StringLiteral  = { value: String }
      ArrayLiteral   = { elements: ForLoop | [ expr ] }
      Paren      = { expression: expr }
      HashLiteral    = { pairs: [ (expr|Label) * expr ] }
      Return     = { values: [ expr ] }
      ForLoop    = {vars: [ Identifier ], set: expr, body: exprs }
      Loop       = { op: :while, cond: expr, body: exprs }
      Break      = { values: nil }
      if_stmnt   = Conditional + { op: :if, cond: expr, then: exprs,
                      all_elsif: [expr * exprs], else: (exprs) }
      ternary    = Conditional + { op: :ifop, cond: expr, then: expr,
                      all_elsif: nil, else: expr }
      Parameters = { params: [ Identifier ],
                     optionals: [ Identifier * expr ],
                     rest_of_params: (Identifier),
                     params_after_rest: [ Identifier ],
                     keywords: [ Label * expr ],
                     rest_of_keywords: (Identifier),
                     block_param: (Identifier) }
      Block      = Parameters + { body: exprs }
      Lambda     = Block + { body: expr }  # -> (x) { x + 1 }
      lambda_name = { name: "lambda" }
      lambda_call = Call + { receiver: nil, op: nil, name: lambda_name,
                     args: nil, block_arg: nil, block: Block }
      fun_call   = Call + { receiver: (expr), op: (Symbol), name: Identifier,
                     args: [ expr ], block_arg: nil, block: nil }
      Command    = fun_call
      Exprs      = { expressions: [ exprs ] }
      Rescue     = { types: [ Const | ConstPathRef ],
                     parameter: (Identifier),
                     body: (exprs), nested_rescue: (Rescue),
                     else: (exprs), ensure: (exprs) }
      BeginEnd   = { body: exprs, rescue: (Rescue) }
      Def        = Parameters +
                   { singular: (expr), name: Identifier, body: exprs,
                     rescue: (Rescue) }
      ModuleDef  = { name: Const | ConstPathRef, body: exprs,
                     rescue: (Rescue) }
      ClassDef   = ModuleDef +
                   { superclass: (Const | ConstPathRef) }
    end

    raise 'not Python 3' unless PyCall::PYTHON_VERSION >= '3'

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
      if expr_or_subtype(ast.usertype)
        ast
      elsif ast.is_a?(Exprs) && expr_or_subtype(ast.expressions[-1]&.usertype)
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

    def self.expr_or_subtype(usertype)
      usertype == :expr || usertype == :lambda_call || usertype == :fun_call ||
      usertype == :ternary
    end
  end
end
