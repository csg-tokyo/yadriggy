# Copyright (C) 2018- Shigeru Chiba.  All rights reserved.

require 'yadriggy'

module Yadriggy
  module Py
    class CodeGen < Checker
      # @return [Printer] the printer.
      attr_reader :printer

      # @param [Printer] printer
      # @param [PyTypeChecker] checker
      def initialize(printer, checker)
        super()
        @printer = printer
        @typechecker = checker
      end

      # @api private
      def error_group
        'code generation'
      end

      # Prints a given AST by {#printer}.
      # @param [ASTree|ASTnode] an_ast  the AST.
      # @return [CodeGen] the `self` object.
      def print(an_ast)
        check_all(an_ast)
        if errors?
          error_messages.each do |m|
            STDERR.puts(m)
          end
          raise RuntimeError.new('Python code generation failure')
        end
        self
      end

      # Starts a new line.
      def newline
        @printer.nl
      end

      # The name of the function for initializing free variables.
      FreeVarInitName = 'yadpy_initialize'

      # Prints a function for initializing free variables in Python.
      # @return [Array<Object>]  the arguments to the function.
      def print_free_vars_initializer
        @printer << 'def ' << FreeVarInitName << '(_yadpy_values):' << :nl
        @printer << '  global '
        @typechecker.references.each do |pair|
          @printer << pair[1]
        end
        @printer << :nl
        args = []
        i = 0
        @typechecker.references.each do |pair|
          @printer << '  ' << pair[1] << ' = ' << '_yadpy_values[' << i.to_s << ']' << :nl
          args << pair[0]
          i += 1
        end
        @printer << :nl
        return args
      end

      rule(Name) do
        @printer << ast.name
      end

      rule(Label) do
        @printer << "'" << ast.name << "'"
      end

      rule(IdentifierOrCall) do
        t = @typechecker.type?(ast)
        rt = ResultType.role(t)
        unless rt.nil?
          @printer << ast.name << '()'
        else
          it = InstanceType.role(t)
          unless it.nil?
            value = it.object
            name = @typechecker.references[value]
            if name.nil?
              if value.is_a?(Numeric)
                @printer << value.to_s
              else
                @printer << value.to_s.dump
              end
            else
              @printer << name
            end
          else
            @printer << ast.name
          end
        end
      end

      rule(Number) do
        @printer << ast.value.to_s          # complex numbrer?
      end

      rule(Super) do
        @printer << 'super()'
      end

      rule(Reserved) do
        case ast.name
        when 'true'
          @printer << 'True'
        when 'false'
          @printer << 'False'
        when 'nil'
          @printer << 'None'
        else
          @printer << ast.name
        end
      end

      rule(Paren) do
        @printer << '('
        print(ast.expression)
        @printer << ')'
      end

      rule(Exprs) do
        ast.expressions.each do |e|
          print(e)
          @printer.nl
        end
      end

      rule(StringLiteral) do
        @printer << ast.value.dump
      end

      # Python List
      rule(ArrayLiteral) do
        @printer << '['
        if ast.elements.size == 1 && ast.elements[0].is_a?(ForLoop)
          loop = ast.elements[0]
          print(loop.body)
          @printer << ' for '
          print_each(loop.vars, true)
          @printer << ' in '
          print(loop.set)
        else
          print_each(ast.elements, true)
        end
        @printer << ']'
      end

      rule(HashLiteral) do
        @printer << '{'
        print_each(ast.pairs, true) do |pair|
          print(pair[0])
          @printer << ': '
          print(pair[1])
        end
        @printer << '}'
      end

      # Slicing in Python like [1:n] is written
      # as [1..n] in Ruby.
      rule(ArrayRef) do
        print(ast.array)
        @printer << '['
        idx = ast.indexes[0]
        if idx.is_a?(Dots)
          error!(ast, "#{idx.op} should be ..") unless idx.op == :'..'
          print(idx.left) unless is_omitted?(idx.left)
          @printer << ':'
          print(idx.right) unless is_omitted?(idx.right)
        else
          print(ast.indexes[0])
        end
        @printer << ']'
      end

      # @api private
      # [:n] in Python is written as [_..n] in Ruby.
      def is_omitted?(ast)
        ast.is_a?(Name) && ast.name == '_'
      end

      rule(Call) do
        if ast.name.name == 'tuple' && ast.receiver.nil?
          # tuple(), tuple(1, 2, 3) => (), (1, 2, 3)
          print_tuple(ast)
        elsif ast.name.name == 'in' && !ast.receiver.nil? && ast.args&.size == 1
          # a .in b, a.in(b) => a in b
          print_binary(ast, ' in ')
        elsif ast.name.name == 'idiv' && !ast.receiver.nil? && ast.args&.size == 1
          # a .idiv b, a.idiv(b) => a // b
          print_binary(ast, ' // ')
        elsif ast.op == :"::" && ast.args.empty?
          if ast.receiver
            @printer << '('
            print(ast.receiver)
            @printer << ')'
          end
          @printer << '.'
          @printer << ast.name.name
        else
          if ast.receiver
            @printer << '('
            print(ast.receiver)
            @printer << ')'
          end
          unless ast.op.nil?
            error!(ast, "#{ast.op} should be .") unless ast.op == :"."
            @printer << ast.op
          end
          @printer << ast.name.name
          @printer << '('
          print_each(ast.args, true)
          @printer << ')'
        end
      end

      # @api private
      def print_tuple(an_ast)
        @printer << '('
        print_each(an_ast.args, true)
        @printer << ', ' if an_ast.args.size == 1
        @printer << ')'
      end

      # @api private
      def print_binary(an_ast, op)
        @printer << '('
        print(an_ast.receiver)
        @printer << ')'
        @printer << op
        @printer << '('
        print(an_ast.args[0])
        @printer << ')'
      end

      # @api private
      def print_each(array, first, &block)
        array.each do |e|
          if e
            if first
              first = false
            else
              @printer << ', '
            end
            if block.nil?
              print(e)
            else
              block.call(e)
            end
          end
        end
        first
      end

      rule(Unary) do
        if ast.real_operator == :!
          @printer << 'not '
        else
          @printer << ast.real_operator
        end
        print(ast.operand)
      end

      rule(Binary) do
        if ast.op == :'..'
          @printer << 'range('
          print(ast.left)
          @printer << ', '
          print(ast.right)
          @printer << ')'
        else
          print(ast.left)
          @printer << ' ' << python_binary_op(ast.op) << ' '
          print(ast.right)
        end
      end

      rule(Assign) do
        if ast.left.is_a?(Array) && ast.right.is_a?(Array) &&
            ast.left.size < ast.right.size
          error!(ast, 'too many right operands')
        end

        if ast.left.is_a?(Array)
          print_each(ast.left, true)
        else
          print(ast.left)
        end
        @printer << ' ' << python_binary_op(ast.op) << ' '
        if ast.right.is_a?(Array)
          print_each(ast.right, true)
        else
          print(ast.right)
        end
      end

      def python_binary_op(op)
        if op == :'&&'
          'and'
        elsif op == :'||'
          'or'
        else
          op
        end
      end

      rule(Lambda) do
        print_lambda(ast)
      end

      def print_lambda(func)
        @printer << '(lambda '
        print_parameters(func.params)
        @printer << ': '
        print(func.body)    # has to be a simple expression?
        @printer << ')'
      end

      rule(:lambda_call) do
        print_lambda(ast.block)
      end

      rule(Conditional) do
        if ast.op == :if
          @printer << ast.op << ' '
          print(ast.cond)
          @printer << ':'
          @printer.down
          print(ast.then)
          @printer.up
          ast.all_elsif.each do | expr |
            @printer << 'elif '
            print(expr[0])
            @printer << ':'
            @printer.down
            print(expr[1])
            @printer.up
          end
          if ast.else
            @printer << 'else:'
            @printer.down
            print(ast.else)
            @printer.up
          end
        else # :ifop
          print(ast.then)
          @printer << ' if '
          print(ast.cond)
          @printer << ' else '
          print(ast.else)
        end
      end

      rule(Loop) do
        if ast.op == :while
          @printer << 'while '
          print(ast.cond)
          @printer << ':'
          @printer.down
          print(ast.body)
          @printer.up
          # while else?
        else
          error!(ast, 'unsupported loop')
        end
      end

      rule(ForLoop) do
        @printer << 'for '
        print_each(ast.vars, true)
        @printer << ' in '
        print(ast.set)      # could be multiple expressions
        @printer << ':'
        @printer.down
        print(ast.body)
        @printer.up
        # for .. else?
      end

      rule(Break) do
        @printer << ast.op
        error!(ast, "bad #{ast.op}") unless ast.values.nil?
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

      rule(Def) do
        @printer << 'def '
        @printer << method_name(ast.name.name)
        @printer << '('
        print_parameters(ast.params)
        @printer << '):' << :nl
        @printer.down
        print(ast.body)
        @printer.up
        @printer << :nl
      end

      # @api private
      def print_parameters(params)
        params.each_with_index do |p, i|
          @printer << ', ' if i > 0
          @printer << p.name
        end
      end

      # @api private
      def method_name(name)
        if name == 'initialize'
          '__init__'
        else
          name
        end
      end

      rule(ClassDef) do
        @printer << 'class '
        print(ast.name)
        if ast.superclass
          @printer << '('
          print(ast.superclass)     # only single inheritance
          @printer << ')'
        end
        @printer << ':'
        @printer.down
        print(ast.body)
        @printer.up
      end

    end
  end
end
