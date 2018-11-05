# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'yadriggy/typecheck'
require 'yadriggy/printer'

module Yadriggy
  # Pretty printer for Ruby
  class PrettyPrinter < Checker
    # Obtains the string representation of the given AST.
    #
    # @param [ASTree|ASTnode] an_ast  the AST.
    # @return [String] the string representation of the AST.
    def self.ast_to_s(an_ast)
      pp = PrettyPrinter.new(Printer.new)
      pp.print(an_ast).printer.output
    end

    # @return [Printer] a {Printer} object.
    attr_reader :printer

    # @param [Printer] printer
    def initialize(printer)
      super()
      @printer = printer
    end

    # Prints a given AST by {#printer}.
    # @param [ASTree|ASTnode] an_ast  the AST.
    # @return [PrettyPrinter] the `self` object.
    def print(an_ast)
      check_all(an_ast)
      self
    end

    rule(Assign) do
      if ast.left.is_a?(Array)
        print_each(ast.left, true)
      else
        print(ast.left)
      end
      @printer << ' ' << ast.op << ' '
      if ast.right.is_a?(Array)
        print_each(ast.right, true)
      else
        print(ast.right)
      end
    end

    rule(Name) do
      @printer << ast.name
    end

    rule(Label) do
      @printer << ast.name << ':'
    end

    rule(Super) do
      @printer << 'super'
    end

    rule(Number) do
      @printer << ast.value.to_s
    end

    rule(SymbolLiteral) do
      @printer << ":'" << ast.name << "'"
    end

    rule(Exprs) do
      ast.expressions.each do |e|
        print(e)
        @printer.nl
      end
    end

    rule(Paren) do
      @printer << '('
      print(ast.expression)
      @printer << ')'
    end

    rule(ArrayLiteral) do
      @printer << '['
      print_each(ast.elements, true)
      @printer << ']'
    end

    rule(StringInterpolation) do
      @printer << '"'
      ast.contents.each do |c|
        if c.is_a?(StringLiteral)
          @printer << c.value.dump[1..-2]
        else
          @printer << '#{'
          print(c)
          @printer << '}'
        end
      end
      @printer << '"'
    end

    rule(StringLiteral) do
      @printer << ast.value.dump
    end

    rule(ConstPathRef) do
      print(ast.scope)
      @printer << '::'
      print(ast.name)
    end

    rule(Unary) do
      @printer << ast.real_operator
      print(ast.operand)
    end

    rule(Binary) do
      print(ast.left)
      @printer << ' ' << ast.op << ' '
      print(ast.right)
    end

    rule(Dots) do
      print(ast.left)
      @printer << ast.op
      print(ast.right)
    end

    rule(HashLiteral) do
      @printer << '{'
      print_hash_elements(ast)
      @printer << '}'
    end

    def print_hash_elements(hash_ast)
      print_list(hash_ast.pairs, true) do |pair|
        print(pair[0])
        @printer << ' '
        @printer << '=> ' unless pair[0].is_a?(Label)
        print(pair[1])
      end
    end

    rule(Call) do
      is_cmd = ast.is_a?(Command)
      print(ast.receiver) if ast.receiver
      @printer << ast.op if ast.op
      @printer << ast.name.name if ast.name
      print_arguments(ast.args, ast.block_arg, ast.block, is_cmd)
    end

    # Prints an argument list.
    #
    # @param [Array<ASTnode>] args_ast  an argument list.
    # @param [ASTnode] block_arg  a block argument.
    # @param [ASTnode] block  a block.
    # @param [Boolean] is_cmd  true if opening/closing parentheses are not written
    #    (true if the arguments are for a command).
    # @param [Boolean] no_empty_paren  true if `()` is not printed when an argument list is empty.
    # @return [void]
    def print_arguments(args_ast, block_arg, block, is_cmd, no_empty_paren=true)
      if is_cmd
        @printer << ' '
      else
        @printer << '(' unless no_empty_paren && args_ast.empty?
      end

      is_first = print_list(args_ast, true) do |a|
        if a.is_a?(HashLiteral) && args_ast.last == a
          print_hash_elements(a)
        else
          print(a)
        end
      end

      if block_arg
        @printer << ', ' unless is_first
        @printer << '&'
        print(block_arg)
      end
      unless is_cmd
        @printer << ')' unless no_empty_paren && args_ast.empty?
      end
      if block
        @printer << ' '
        print(block)
      end
    end

    rule(ArrayRef) do
      print(ast.array)
      @printer << '['
      print_each(ast.indexes, true)
      @printer << ']'
    end

    rule(Conditional) do
      case ast.op
      when :if, :unless
        @printer << ast.op << ' '
        print(ast.cond)
        @printer.down
        print(ast.then)
        @printer.up
        ast.all_elsif.each do | expr |
          @printer << 'elsif '
          print(expr[0])
          @printer.down
          print(expr[1])
          @printer.up
        end
        if ast.else
          @printer << 'else'
          @printer.down
          print(ast.else)
          @printer.up
        end
        @printer << 'end' << :nl
      when :if_mod, :unless_mod
        print(ast.then)
        @printer << (ast.op == :if_mod ? ' if ' : ' unless ')
        print(ast.cond)
      else # :ifop
        print(ast.cond)
        @printer << ' ? '
        print(ast.then)
        @printer << ' : '
        print(ast.else)
      end
    end

    rule(Loop) do
      case ast.op
      when :while, :until
        @printer << ast.op << ' '
        print(ast.cond)
        @printer.down
        print(ast.body)
        @printer.up
        @printer << 'end'
      else # :while_mod, :until_mod
        print(ast.body)
        @printer << ' ' << ast.real_operator << ' '
        print(ast.cond)
      end
    end

    rule(ForLoop) do
      @printer << 'for '
      print_each(ast.vars, true)
      @printer << ' in '
      print(ast.set)
      @printer.down
      print(ast.body)
      @printer.up
      @printer << 'end'
    end

    rule(Break) do
      @printer << ast.op
      first = true
      ast.values.each do |v|
        if first
          @printer << ' '
          first = false
        else
          @printer << ', '
        end
        print(v)
      end
    end

    rule(Return) do
      @printer << 'return'
      first = true
      ast.values.each do |v|
        if first
          @printer << ' '
          first = false
        else
          @printer << ', '
        end
        print(v)
      end
    end

    # @api private
    def print_parameters(params_ast)
      is_first = true
      is_first = print_each(params_ast.params, is_first)

      is_first = print_list(params_ast.optionals, is_first) do |p|
        print(p[0])
        @printer << '='
        print(p[1])
      end

      is_first = print_list([params_ast.rest_of_params], is_first) do |p|
        @printer << '*'
        print(p)
      end

      is_first = print_each(params_ast.params_after_rest, is_first)

      is_first = print_list(params_ast.keywords, is_first) do |kv|
        print(kv[0])
        @printer << ': '
        print(kv[1])
      end

      is_first = print_list([params_ast.rest_of_keywords], is_first) do |p|
        @printer << '**'
        print(p)
      end

      is_first = print_list([params_ast.block_param], is_first) do |p|
        @printer << '&'
        print(p)
      end
    end

    # @param [Parameters] params_ast  a parameter list.
    # @return [Boolean] true if the given parameter list is empty.
    def empty_params?(params_ast)
      params_ast.params.empty? && params_ast.optionals.empty? &&
        params_ast.rest_of_params.nil? &&
        params_ast.params_after_rest.empty? && params_ast.keywords.empty? &&
        params_ast.rest_of_keywords.nil? && params_ast.block_param.nil?
    end

    rule(Block) do
      if ast.body.is_a?(Exprs)
        @printer << 'do'
        unless empty_params?(ast)
          @printer << ' |'
          print_parameters(ast)
          @printer << '|'
        end
        @printer.down
        print(ast.body)
        @printer.up
        @printer << 'end'
      else
        if empty_params?(ast)
          @printer << '{ '
        else
          @printer << '{|'
          print_parameters(ast)
          @printer << '| '
        end
        print(ast.body)
        @printer << ' }'
      end
    end

    rule(Lambda) do
      @printer << '-> ('
      print_parameters(ast)
      @printer << ') '
      body = ast.body
      if body.is_a?(Exprs) || body.is_a?(Conditional) || body.is_a?(Loop) ||
          body.is_a?(ForLoop) || body.is_a?(BeginEnd) || body.is_a?(Def)
        @printer << 'do'
        @printer.down
        print(body)
        @printer.up
        @printer << 'end'
      else
        @printer << '{ '
        print(body)
        @printer << ' }'
      end
    end

    rule(Rescue) do
      @printer << 'rescue '
      print_each(ast.types, true)
      if ast.parameter
        @printer << ' => '
        print(ast.parameter)
      end
      @printer.down
      print(ast.body)
      @printer.up
      print(ast.nested_rescue)

      if ast.else
        @printer << 'else'
        @printer.down
        print(ast.else)
        @printer.up
      end

      if ast.ensure
        @printer << 'ensure'
        @printer.down
        print(ast.ensure)
        @printer.up
      end
    end

    rule(BeginEnd) do
      @printer << 'begin'
      @printer.down
      print(ast.body)
      @printer.up
      print(ast.rescue)
      @printer << 'end' << :nl
    end

    rule(Def) do
      @printer << 'def '
      if ast.singular
        print(ast.singular)
        @printer << '.'
      end
      @printer << ast.name.name
      @printer << '('
      print_parameters(ast)
      @printer << ')' << :nl
      @printer.down
      print(ast.body)
      @printer.up
      print(ast.rescue)
      @printer << 'end' << :nl
    end

    rule(ModuleDef) do
      @printer << 'module '
      print(ast.name)
      @printer.down
      print(ast.body)
      @printer.up
      print(ast.rescue)
      @printer << 'end' << :nl
    end

    rule(ClassDef) do
      @printer << 'class '
      print(ast.name)
      if ast.superclass
        @printer << ' < '
        print(ast.superclass)
      end
      @printer.down
      print(ast.body)
      @printer.up
      print(ast.rescue)
      @printer << 'end' << :nl
    end

    rule(SingularClassDef) do
      @printer << 'class << '
      print(ast.name)
      @printer.down
      print(ast.body)
      @printer.up
      print(ast.rescue)
      @printer << 'end' << :nl
    end

    rule(Program) do
      ast.elements.each do |e|
        print(e)
        @printer.nl
      end
    end

    # @api private
    def print_each(array, first)
      array.each do |e|
        if e
          if first
            first = false
          else
            @printer << ', '
          end
          print(e)
        end
      end
      first
    end

    # @api private
    def print_list(array, first)
      array.each do |e|
        if e
          if first
            first = false
          else
            @printer << ', '
          end
          yield e
        end
      end
      first
    end

  end
end
