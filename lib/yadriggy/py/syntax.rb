# Copyright (C) 2018- Shigeru Chiba.  All rights reserved.

require 'yadriggy'

module Yadriggy
  module Py
    Syntax = Yadriggy.define_syntax do
      expr  = Name | Number | Super | Binary | Unary | ternary |
              StringLiteral | Lambda |
              ArrayLiteral | Paren | lambda_call | with_call | fun_call |
              ArrayRef | HashLiteral
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
      HashLiteral    = { pairs: [ (expr|Label|SymbolLiteral) * expr ] }
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
      with_name  = { name: "with" }
      with_call  = Call + { receiver: nil, op: nil, name: with_name,
                            args: HashLiteral, block_arg: nil, block: Block }
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
  end
end
