# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'ripper'
require 'pry'

# Interactive shell.
class Pry
  # Log.
  class History
    # Records a line.
    # We modify the original `Pry::History::push` to record a duplicated line as well.
    # @param [String] line  an input.
    def push(line)
      unless line.empty? || line.include?("\0")
        @pusher.call(line)
        @history << line
        if !should_ignore?(line) && Pry.config.history.should_save
          @saver.call(line)
        end
      end
      line
    end
    alias << push
  end
end

module Yadriggy
  # Discards all the code given to Pry before.
  # This should be called when the code given before includes
  # a syntax error and hence {reify} cannot obtain an
  # abstract syntax tree.
  def self.reset_pry
    SourceCode.reset_pry
  end

  # @api private
  # Retrieves source code in the S-expression style.
  class SourceCode

    # Gets an S-expression.
    #
    def self.get_sexp(proc)
      return nil unless proc.is_a?(Proc) || proc.is_a?(Method) ||
                        proc.is_a?(UnboundMethod)

      file_name, line = proc.source_location
      return nil if file_name.nil?
      src = if file_name == "(pry)" then read_pry_history
                                    else File.read(file_name) end
      prog = Ripper.sexp(src)
      prog && [file_name, find_sexp(prog, line)]
    end

    @pry_offset = 0

    def self.reset_pry
      @pry_offset = Pry.history.history_line_count - Pry.history.original_lines
    end

    def self.read_pry_history
      cmds = Pry.commands
      his = Pry.history.to_a[Pry.history.original_lines + @pry_offset ...
                             Pry.history.history_line_count]
      his.reduce("\n" * @pry_offset) do |source, line|
        if cmds.select {|k,v| v.matches?(line) }.empty?
          source << line << "\n"
        else
          source # << "\n"
        end
      end
    end

    def self.min(a, b)
      if a < b then a else b end
    end

    def self.max(a, b)
      if a > b then a else b end
    end

    def self.find_sexp(prog, line)
      find_sexp2(prog, line, [1, nil])
    end

    # @param [Array] current  the current location `[line, block]`
    def self.find_sexp2(prog, line, current)
      if prog.nil? || !prog.is_a?(Array)
        return nil
      else
        t = prog[0]
        if t == :@ident || t == :@tstring_content || t == :@const ||
           t == :@int || t == :@float || t == :@kw || t == :@label ||
           t == :@gvar || t == :@CHAR
          #current[0] = prog[2][0]
          current_line = prog[2][0]
          if line < current_line && !current[1].nil?
            return current[1]
          else
            current[0] = current_line
            return nil
          end
        else
          is_block = (t == :brace_block || t == :do_block ||
                      t == :def || t == :defs || t == :lambda)
          if is_block && line == current[0] || def_at?(line, t, prog)
            return prog
          else
            current[1] = nil
            prog.each do |e|
              r = find_sexp2(e, line, current)
              return r unless r.nil?
            end
            if is_block
              if line <= current[0]
                return prog
              else
                current[1] = prog
                return nil
              end
            else
              nil
            end
          end
        end
      end
    end

    def self.def_at?(line, t, prog)
      (t == :def || t == :defs) &&
        prog[1].is_a?(Array) && prog[1][0] == :@ident &&
          prog[1][2][0] == line
    end

    # @api private
    class Cons
      include Enumerable
      attr_accessor :head, :tail

      def initialize(head, tail=nil)
        @head = head
        @tail = tail
      end

      def self.list(*elements)
        list = nil
        elements.reverse_each do |e|
          list = Cons.new(e, list)
        end
        list
      end

      def self.append!(lst1, lst2)
        if lst1 == nil
          lst2
        elsif lst2 == nil
          lst1
        else
          p = lst1
          while p.tail != nil
            p = p.tail
          end
          p.tail = lst2
          lst1
        end
      end

      def size()
        size = 0
        list = self
        while list != nil
          list = list.tail
          size += 1
        end
        size
      end

      def each()
        list = self
        while list != nil
          yield list.head
          list = list.tail
        end
      end

      def fold(acc)
        list = self
        while list != nil
          acc = yield acc, list.head
          list = list.tail
        end
        acc
      end
    end
  end
end
