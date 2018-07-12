# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'yadriggy/eval_all'

# Yadriggy is a platform for building embedded DSLs.
#
# It means mistletoe in Japanese.
#
module Yadriggy
  class ASTnode

    # @return [String] the human-readable location of this AST node.
    def source_location_string
      loc = source_location
      "#{loc[0]}:#{loc[1]}"
    end

    # @return [Array] a tuple of the file name, the line number,
    #   and the column of this AST node.
    def source_location
      g = GetLocation.new
      g.evaluate(self)
      if g.unknown? && !self.parent.nil?
        self.parent.source_location
      else
        g.result(root.file_name)
      end
    end

    # @api private
    class GetLocation < EvalAll
      def initialize
        @unknown = true
        @line_no = 0
        @column = 0
      end

      def unknown?() @unknown end

      def result(file_name)
        [file_name, @line_no, @column]
      end

      def name(expr)
        super
        if @unknown
          @unknown = false
          @line_no = expr.line_no
          @column = expr.column
        else
          if expr.line_no < @line_no
            @line_no = expr.line_no
            @column = expr.column
          elsif expr.line_no == @line_no && expr.column < @column
            @column = expr.column
          end
        end
      end

      def symbol(expr)
        name(expr)
      end

      def number(expr)
        name(expr)
      end

      def string_literal(expr)
        name(expr)
      end
    end
  end
end
