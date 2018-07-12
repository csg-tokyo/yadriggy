# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'ripper'
require 'pry'

module Yadriggy
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

    def self.read_pry_history
      cmds = Pry.commands
      source = ''
      lineno = 0
      lineno1 = Pry.history.original_lines
      File.foreach(Pry.config.history.file) do |line|
        lineno += 1
        if lineno > lineno1
          if cmds.select {|k,v| v.matches?(line) }.empty?
            source << line
          else
            # source << "\n"
          end
        end
      end
      source
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
