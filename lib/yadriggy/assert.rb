# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'yadriggy'

module Yadriggy
  # Power assert by Yadriggy
  module Assert

    # Checks the given assertion is correct and prints the result
    # if the assertion fails.
    #
    # @param [Proc] block  the assertion.
    def self.assert(&block)
      reason = Reason.new
      begin
        res = assertion(reason, block)
        puts_reason(reason) unless res
        return res
      rescue AssertFailure => evar
        puts_reason(evar.reason, evar)
        raise evar.cause
      end
    end

    # @api private
    def self.puts_reason(reason, evar=nil)
      puts '--- Yadriggy::Assert ---'
      print evar.cause.class.name, ': ' if evar&.cause
      puts evar.message if evar&.message
      puts(reason.ast.source_location_string)
      puts(reason.show)
      puts '------------------------'
    end

    # Checks the given assertion is correct.
    #
    # @param [Reason] reason  the object where the reason that the assertion
    #   fails will be stored.
    # @param [Proc] block  the assertion.
    # @return [Object] the result of executing the given block.
    def self.assertion(reason, block)
      return if block.nil?
      ast = Yadriggy::reify(block)
      begin
        results = {}
        reason.setup(ast.tree.body, results)
        run_ast(ast.tree.body, block.binding, results)[1]
      rescue => evar
        raise AssertFailure.new(reason, evar.message, evar)
      end
    end

    # Reason that an assertion fails.
    class Reason
      # @api private
      def setup(ast, results)
        @ast = ast
        @results = results
      end

      # Gets the AST of the block given to {Yadriggy::Assert#assertion}.
      # @return [ASTnode] an abstract syntax tree.
      def ast() @ast end

      # Gets the detailed results.
      # @return [Hash<ASTnode,Pair<String,Object>>]  a map from sub-expressions
      #   to their source and resulting vales.  The sub-expressions are {ASTnode}
      #   objects.
      def results() @results end

      # Gets the text showing the values of the sub-expressions.
      # @return [Array<String>]  an array of lines.
      def show
        output = []
        header = show2(@ast, '', output)
        output << header
        src, value = @results[ast]
        if src.nil?
          pp = PrettyPrinter.new(Printer.new(2))
          pp.print(ast)
          output << pp.printer.output
        else
          output << src
        end
        output.reverse!
      end

      # @api private
      # @return [String] the new header.
      def show2(ast, header, output)
        if ast.is_a?(Paren)
          show2(ast.expression, header + ' ', output) + ' '
        elsif ast.is_a?(Call) && ast.block_arg.nil? && ast.block.nil?
          header2 = show2(ast.receiver, header, output)
          src2, value2 = @results[ast.receiver]
          src, value = @results[ast]
          if src.nil?
            src = PrettyPrinter.ast_to_s(ast)
            if src2.nil?
              "#{header}#{' ' * src.size}"
            else
              "#{header2}#{' ' * (src.size - src2.size)}"
            end
          else
            output << "#{header2} #{str_rep(value)}"
            "#{header2} |#{' ' * (src.size - src2.size - 2)}"
          end
        elsif ast.is_a?(Binary)
          header = show2(ast.left, header, output)
          src, value = @results[ast]
          if src.nil?
            header = header + '   '
          else
            output << "#{header} #{str_rep(value)}"
            header = "#{header} | #{' ' * (ast.op.to_s.size - 1)}"
          end
          show2(ast.right, header, output)
        elsif ast.is_a?(Unary)
          src, value = @results[ast]
          if src.nil?
            header = header + ' '
          else
            output << "#{header}#{str_rep(value)}"
            header = "#{header}|"
          end
          show2(ast.operand, header, output)
        else
          src, value = @results[ast]
          if src.nil?
            src = PrettyPrinter.ast_to_s(ast)
            return "#{header}#{' ' * src.size}"
          else
            output << header + str_rep(value)
            "#{header}|#{' ' * (src.size - 1)}"
          end
        end
      end

      # @api private
      # Obtains the text representation of the given value.
      def str_rep(v)
        max = 70
        str = v.inspect
        if str.length < max
          str
        else
          str[0, max] + '...'
        end
      end
    end

    # Exception thrown by {Yadriggy::Assert#assertion}.
    #
    class AssertFailure < StandardError
      def initialize(reason, msg=nil, cause=nil)
        super(msg)
        @reason = reason
        @cause = cause
      end

      # Gets the cause.
      # @return [StandardError] an exception.
      def cause() @cause end

      # Gets the reason.
      # @return [Reason] the reason.
      def reason() @reason end
    end

    # @api private
    # Executes the given AST and records the result.
    # @param [ASTnode] ast  the given AST.
    # @param [Binding] blk_binding  the binding for executing the AST.
    # @param [Hash<ASTnode,Pair<String,Object>>] results  a map from ASTs
    #   to their source and values.
    # @return [Pair<String,Object>] the result of the execution of the given AST.
    #   It is also recorded in `results`.
    #   The first element is the source code and the second one is the resulting value.
    def self.run_ast(ast, blk_binding, results)
      if ast.is_a?(Paren)
        res = run_ast(ast.expression, blk_binding, results)
        src = "(#{res[0]})"
        results[ast] = [src, res[1]]
      elsif ast.is_a?(Call) && ast.block_arg.nil? && ast.block.nil?
        if ast.receiver.nil?
          receiver = ['self', blk_binding.eval('self')]
        else
          receiver = run_ast(ast.receiver, blk_binding, results)
        end
        args = ast.args.map {|e| run_ast(e, blk_binding, results) }
        arg_values = args.map {|e| e[1] }
        res = receiver[1].send(ast.name.name, *arg_values)
        arg_src = args.each_with_object('') do |e, code|
          code << ', ' if code.size > 0
          code << e[0]
        end
        src = "#{receiver[0]}.#{ast.name.name.to_s}(#{arg_src.to_s})"
        results[ast] = [src, res]
      elsif ast.is_a?(Binary)
        left_value = run_ast(ast.left, blk_binding, results)
        right_value = run_ast(ast.right, blk_binding, results)
        res = left_value[1].send(ast.op, right_value[1])
        results[ast] = ["#{left_value[0]} #{ast.op.to_s} #{right_value[0]}", res]
      elsif ast.is_a?(Unary)
        value = run_ast(ast.operand, blk_binding, results)
        res = value[1].send(ast.op)
        results[ast] = ["#{ast.real_operator.to_s}#{value[0]}", res]
      else
        results[ast] = eval_by_ruby(ast, blk_binding)
      end
    end

    # @api private
    # Eval the AST by the RubyVM
    # @return [Pair<String,Object>]  an array.  The first element is the source code
    #   and the second element is the resulting value.
    def self.eval_by_ruby(ast, blk_binding)
      src = PrettyPrinter.ast_to_s(ast)
      loc = ast.source_location
      [src, eval(src, blk_binding, loc[0], loc[1])]
    end
  end
end
