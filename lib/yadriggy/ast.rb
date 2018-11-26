# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'yadriggy/source_code'

module Yadriggy

  # Gets the abstract syntax tree (AST) of the given procedure `proc`.
  # If `proc` is nil, the block argument is converted into an abstract
  # syntax tree.  The returned {ASTree} object is a container holding
  # not only an AST but also other data.  To get an AST, call {ASTree#tree}
  # on the {ASTree} object.
  #
  # {ASTree#reify} on the {ASTree} object obtains the ASTs of other
  # procs and methods.  It returns the same AST for the same proc or
  # method since it records ASTs obtained before.  The table of
  # the recorded ASTs are shared among {ASTree} objects.
  # Every call to {Yadriggy#reify} on {Yadriggy} makes a new table.  Hence,
  #
  # ```
  # ast1 = Yadriggy.reify(proc1)
  # ast2 = ast.reify(proc2)
  # a1 = Yadriggy.reify(proc1)  # a1 != ast1
  # a2 = a1.reify(proc2)        # a2 != ast2
  # b2 = a1.reify(proc2)        # b2 == a2
  # ```
  #
  # Although `ast1` and `a1`, and `ast2` and `a2` are different copies
  # of the AST of the same proc, `a2` and `b2` refer to the same AST.
  #
  # @param [Method|UnboundMethod|Proc] proc the procedure.
  # @yield the block is used as the procedure if `proc` is `nil`.
  # @return [ASTree|nil] the abstract syntax tree.
  #
  # @see ASTree#reify
  def self.reify(proc = nil, &block)
    code = proc || block
    return nil if code.nil?
    # a is used only for bootstrapping.
    a = ASTree.new(ASTreeTable.new, code, '?', [:zsuper])
    a.astrees.delete(code)
    a.reify(code)
  end

  # The common ancestor class of AST nodes.
  #
  class ASTnode
    # @return [ASTnode] the parent node.
    attr_accessor :parent

    # Overrides the printer printer.
    def pretty_print(pp)
      Yadriggy::simpler_pretty_print(pp, self, '@parent')
    end

    # @param [ASTnode] node  adds a child node.
    # @return [void]
    def add_child(node)
      node.parent = self unless node.nil?
    end

    # @param [Array<ASTnode>] nodes  adds child nodes.
    # @return [void]
    def add_children(nodes)
      nodes.map {|e| e.parent = self unless e.nil? }
    end

    # @return [ASTnode] the root node.
    def root
      parent&.root || self
    end
  end

  # Abstract class.
  #
  class Name < ASTnode
    # @return [String] the name.
    attr_reader :name

    # @return [Integer] the line number.
    attr_reader :line_no

    # @return [Integer] the column.
    attr_reader :column

    # Converts the name to a symbol
    # @return [Symbol] the converted symbol.
    def to_sym
      @name.to_sym
    end

    private
    def initialize(sexp)
      @name = sexp[1]
      @line_no = sexp[2][0].to_i
      @column = sexp[2][1].to_i
    end
  end

  # @abstract
  # The super class of {Identifier} and {VariableCall}.
  #
  class IdentifierOrCall < Name
    def initialize(sexp)
      super(sexp)
    end
  end

  # Identifier.
  class Identifier < IdentifierOrCall
    def self.tags() [:@ident, :@op] end

    def initialize(sexp)
      super(sexp)
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.identifier(self)
    end
  end

  # Constant variable such as a class name.
  #
  class Const < Name
    def self.tag() :@const end

    def initialize(sexp)
      super(sexp)
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.const(self)
    end
  end

  # Reserved words such as self, nil, true, and false.
  #
  class Reserved < Name
    def self.tag() :@kw end

    def initialize(sexp)
      super(sexp)
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.reserved(self)
    end
  end

  # Label such as `length:`.
  #
  class Label < Name
    def self.tag() :@label end

    def initialize(sexp)
      super([:@label, sexp[1].chop, sexp[2]])
    end

    # @return [String] the label name.
    #   For example, if this object represents `length:`,
    #   then `"length"` (without a colon) is returned.
    def name() super end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.label(self)
    end
  end

  # Global variable.
  class GlobalVariable < Name
    def self.tag() :@gvar end

    def initialize(sexp)
      super(sexp)
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.global_variable(self)
    end
  end

  # Instance variable and class variable, such as `@x` and `@@x`.
  # The value returned by `name` contains `@`.
  #
  class InstanceVariable < Name
    def self.tags() [:@ivar, :@cvar] end

    def initialize(sexp)
      super(sexp)
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.instance_variable(self)
    end
  end

  # Method call without parentheses or arguments.
  #
  class VariableCall < IdentifierOrCall
    def self.tag() :vcall end

    def initialize(sexp)
      super(sexp[1])
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.variable_call(self)
    end
  end

  # Reserved word `super`.
  # `super` is a reserved word but no position (line numbre) is
  # associated with it.  Hence {Super} is not a subclass of
  # {Reserved}.
  #
  class Super < ASTnode
    def self.tag() :zsuper end

    def initialize(sexp) end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.super_method(self)
    end
  end

  # Numeric literal.
  #
  class Number < ASTnode
    # @return [Numeric] the number.
    attr_reader :value
    # @return [Integer] the line number.
    attr_reader :line_no
    # @return [Integer] the column.
    attr_reader :column

    def self.tags()
      [:@int, :@float]
    end

    def initialize(sexp)
      @value = case sexp[0]
               when :@int
                 if sexp[1].start_with? "0x"
                   sexp[1].hex
                 else
                   sexp[1].to_i
                 end
               when :@float
                 sexp[1].to_f
               else
                 raise "unknown symbol " + sexp[0]
               end
      @line_no = sexp[2][0].to_i
      @column = sexp[2][1].to_i
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.number(self)
    end
  end

  # Helper module
  #
  module AstHelper
    # @param [Array] s  an S-expression.
    # @return [ASTnode] an AST.
    def to_node(s) ASTree.to_node(s) end

    # @param [Array] s  an array of S-expression.
    # @return [Array<ASTnode>] ASTs.
    def to_nodes(s)
      raise "not an array: #{s}" unless s.class == Array
      s.map {|e| ASTree.to_node(e) }
    end

    # @param [Array] s  an S-expression.
    # @param [Symbol] tag
    # @return [Array] the S-expression if it starts with the tag.
    #   Otherwise, raise an error.
    def has_tag?(s, tag)
      raise "s-exp is not :#{tag.to_s}. #{s}" if !s.nil? && s[0] != tag
      s
    end
  end

  # Symbol.
  #
  class SymbolLiteral < ASTnode
    include AstHelper
    # @return [String] the symbol name.
    #   For example, if the object represents `:sym`, then
    #   `"sym"` (without a colon) is returned.
    attr_reader :name
    # @return [Integer] the line number.
    attr_reader :line_no
    # @return [Integer] the column.
    attr_reader :column

    def self.tags() [:symbol, :symbol_literal, :dyna_symbol] end

    def initialize(sexp)
      if sexp[0] == :dyna_symbol
        init(has_tag?(sexp[1][0], :@tstring_content))
      elsif sexp[0] == :symbol_literal
        init(has_tag?(sexp[1], :symbol)[1])
      else
        init(has_tag?(sexp, :symbol)[1])
      end
    end

    # @return [Symbol] a symbol the literal represents.
    def to_sym
      name.to_sym
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.symbol(self)
    end

    private
    def init(sexp)
      @name = sexp[1]
      @line_no = sexp[2][0].to_i
      @column = sexp[2][1].to_i
    end
  end

  # expressions, or progn in Lisp.
  #
  class Exprs < ASTnode
    include AstHelper

    # @return [Array<ASTnode>] the expressions.
    #   It may be an empty array.
    attr_reader :expressions

    # @param [Array] sexp  an S-expression.
    # @return [Exprs|ASTnode] an AST.
    def self.make(sexp)
      if sexp.length == 1
        if sexp[0][0] == :void_stmt
          Exprs.new([])
        else
          ASTree.to_node(sexp[0])
        end
      else
        Exprs.new(sexp)
      end
    end

    def initialize(sexp)
      @expressions = to_nodes(sexp)
      add_children(@expressions)
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.exprs(self)
    end
  end

  # Parenthesis.
  #
  class Paren < ASTnode
    include AstHelper

    # @return [ASTnode] the expression surrounded with the parentheses.
    attr_reader :expression

    def self.tag() :paren end

    def initialize(sexp)
      e = if sexp[1][0].is_a?(Array) then sexp[1][0] else sexp[1] end
      @expression = to_node(e)
      add_child(@expression)
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.paren(self)
    end
  end

  # Array literal.
  #
  class ArrayLiteral < ASTnode
    include AstHelper

    # @return [Array<ASTnode>] the array elements.
    attr_reader :elements

    def self.tag() :array end

    def initialize(sexp)
      if sexp[1].nil?
        @elements = []
      elsif is_percent_literal(sexp[1])
        @elements = sexp[1].map do |e|
          StringInterpolation.new([:string_literal, [:string_content] + e])
        end
      else
        @elements = to_nodes(sexp[1])
      end
      add_children(@elements)
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.array(self)
    end

    private

    def is_percent_literal(sexp)
      sexp.is_a?(Array) && sexp.size > 0 &&
      sexp.all? do |e|
        e.is_a?(Array) && e.all? {|ee| ee.is_a?(Array) }
      end
    end
  end

  # String interpolation.
  #
  class StringInterpolation < ASTnode
    include AstHelper

    # @return [Array<ASTnode>] the strings and the embedded expressions.
    attr_reader :contents

    def self.tag() :string_literal end

    def initialize(sexp)
      s = has_tag?(sexp[1], :string_content)
      elements = s[1..s.length]
      @contents = elements.map do |e|
        case e[0]
        when :string_embexpr
          Exprs.make(e[1])
        when :@tstring_content
          StringLiteral.new(e)
        else
          raise "unknown string contents #{e[0]}"
        end
      end
      add_children(@contents)
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.string_interpolation(self)
    end
  end

  # String literal.
  #
  class StringLiteral < ASTnode
    # @return [String] the character string.
    attr_reader :value

    # @return [Integer] the line number.
    attr_reader :line_no

    # @return [Integer] the column.
    attr_reader :column

    def self.tags()
      [:@tstring_content, :@CHAR]
    end

    def initialize(sexp)
      @value = case sexp[0]
                 when :@CHAR
                   eval(sexp[1])
                 else # :@tstring_content
                   if sexp[1] =~ /\n$/
                     sexp[1]    # maybe here document
                   else
                     eval( "<<_YAD_STRING_\n#{sexp[1]}\n_YAD_STRING_\n").chop
                   end
               end
      @line_no = sexp[2][0].to_i
      @column = sexp[2][1].to_i
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.string_literal(self)
    end

    # @param [ASTnode] node  an AST.
    # @return [ASTnode] the given AST.
    #   If it is a {StringInterpolation} with a single element,
    #   it is converted into a single {StringLiteral}.
    def self.normalize(node)
      if node.class == StringInterpolation
        if node.contents.length == 1
          return node.contents[0]
        end
      end
      node
    end
  end

  # Constant path reference, such as `Yadriggy::ConstPathRef`.
  #
  class ConstPathRef < ASTnode
    include AstHelper

    # @return [ConstPathRef|Const] the scope.
    attr_reader :scope

    # @return [Const] the class or module name.
    attr_reader :name

    def self.tags() [:const_path_ref, :top_const_ref] end

    def initialize(sexp)
      if sexp[0] == :const_path_ref || sexp[0] == :const_path_field
        @scope = to_node(sexp[1])
        @name = to_node(has_tag?(sexp[2], :@const))
        add_child(@scope)
      else
        @scope = nil
        @name = to_node(has_tag?(sexp[1], :@const))
      end
      add_child(@name)
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.const_path_ref(self)
    end
  end

  # Constant path reference as a L-value.
  #
  class ConstPathField < ConstPathRef
    def self.tags() [:const_path_field, :top_const_field] end

    def initialize(sexp)
      super
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.const_path_field(self)
    end
  end

  # Unary expression.
  # The splat operator `*` is also a unary operator.
  #
  class Unary < ASTnode
    include AstHelper

    # Returns the operator name.
    # @return [Symbol] the operator name.
    #   If this is a unary plus/minus expression, `:+@` or `:-@` is
    #   returned.
    attr_reader :op

    # @return [ASTnode] the operand.
    attr_reader :operand

    def self.tag() :unary end

    def initialize(sexp)
      @op = sexp[1]
      @operand = to_node(sexp[2])
      add_child(@operand)
    end

    # Returns the real operator name.
    # @return [Symbol] the real operator name.
    #   If the operator is a unary plus or minus, the method returns
    #   `:+` or `:-` although {#op} returns `:+@` or `:-@`.
    #
    def real_operator
      case @op
      when :+@
        :+
      when :-@
        :-
      else
        @op
      end
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.unary(self)
    end
  end

  # Binary expression.
  #
  class Binary < ASTnode
    include AstHelper

    # @return [ASTnode] the left operand.
    attr_reader :left
    # @return [Symbol] the operator.
    attr_reader :op
    # @return [ASTnode] the right operand.
    attr_reader :right

    def self.tag() :binary end

    def initialize(sexp)
      @left = to_node(sexp[1])
      @op = sexp[2]	# symbol
      @right = to_node(sexp[3])
      add_child(@left)
      add_child(@right)
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.binary(self)
    end
  end

  # Range.
  #
  class Dots < Binary
    def self.tags() [:dot2, :dot3] end

    def initialize(sexp)
      @left = to_node(sexp[1])
      @op = if sexp[0] == :dot2 then :'..' else :'...' end
      @right = to_node(sexp[2])
      add_child(@left)
      add_child(@right)
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.dots(self)
    end
  end

  # Assignment such as `=` and `+=`.
  # `Assign#left` and `Assign#right` return an `ASTnode`,
  # or an array of `ASTnode` if the node represents multiple
  # assignment.
  #
  class Assign < Binary
    def self.tags() [:assign, :opassign, :massign] end

    def initialize(sexp)
      case sexp[0]
      when :assign
        @left = to_node(sexp[1])
        add_child(@left)
        @op = :'='
        init_right(sexp[2])
      when :opassign
        @left = to_node(sexp[1])
        add_child(@left)
        @op = has_tag?(sexp[2], :@op)[1].to_sym
        init_right(sexp[3])
      when :massign
        @left = to_nodes(sexp[1])
        add_children(@left)
        @op = :'='
        init_right(sexp[2])
      else
        raise "unknown assignment " + sexp[0].to_s
      end
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.assign(self)
    end

    private

    # @api private
    def init_right(right_operand)
      if right_operand[0] == :mrhs_new_from_args
        @right = to_nodes(right_operand[1]) + [to_node(right_operand[2])]
        add_children(@right)
      else
        @right = to_node(right_operand)
        add_child(@right)
      end
    end
  end

  # Hash table.
  #
  class HashLiteral < ASTnode
    include AstHelper

    # Returns the elements in the hash table.
    # @return [Array<Array<ASTnode>>] the hash elements.
    #    Each element is a key-value pair.
    #    For example, if the source code is
    #    `{key1 => value1, key2 => value2}`,
    #    then `[[key1, value2], [key2, value2]]` is returned.
    attr_reader :pairs

    def self.tags() [:hash, :bare_assoc_hash] end

    def initialize(sexp)
      if sexp[0] == :hash && sexp[1]
        list = has_tag?(sexp[1], :assoclist_from_args)[1]
      else
        list = sexp[1]
      end
      if list.nil?
        @pairs = []
      else
        @pairs = list.map do |e|
          has_tag?(e, :assoc_new)
          [to_node(e[1]), to_node(e[2])]
        end
      end
      @pairs.map do |p|
        add_child(p[0])
        add_child(p[1])
      end
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.hash(self)
    end
  end

  # Method call following parentheses.
  # @see Command
  # @see VariableCall
  class Call < ASTnode
    include AstHelper

    # @return [ASTnode|nil] the callee object.
    attr_reader :receiver

    # Returns either `:"."`, `:"::"`, or `nil`.
    # @return [Symbol] the symbol used as a separator between
    #   the receiver and the method name.
    #   It is either `:"."`, `:"::"`, or `nil`.
    attr_reader :op

    # @return [Identifier] the method name.
    attr_reader :name

    # @return [Array<ASTnode>] the method-call arguments.
    attr_reader :args

    # @return [ASTnode|nil] the argument preceded by an ampersand.
    attr_reader :block_arg

    # @return [ASTnode|nil] the block passed to the method.
    attr_reader :block

    # Makes an instance of {Call} with the given values for its
    # instance variables.
    # @param [ASTnode|nil] receiver  the receiver object.
    # @param [Symbol|nil] op  the operator.
    # @param [Identifeir] name  the method name.
    # @param [Array<ASTnode>] args  the method-call arguments.
    # @param [ASTnode|nil] block_arg  the argument preceded by an ampersand.
    # @param [ASTnode|nil] block  the block passed to the method.
    # @param [ASTnode] parent  the parent node.
    # @param [Boolean] link_from_children  if true, links from children
    #                                      to `self` are added.
    # @return [Call] the created object.
    def self.make(receiver: nil, op: nil, name:, args: [],
                  block_arg: nil, block: nil,
                  parent:, link_from_children: false)
      obj = self.allocate
      obj.initialize2(receiver, op, name, args, block_arg, block,
                      parent, link_from_children)
    end

    # @api private
    def initialize2(recv, op, name, args, barg, blk,
                    parent, link_from_children)
      @receiver = recv
      @op = op
      @name = name
      @args = args
      @block_arg = barg
      @block = blk
      @parent = parent
      if link_from_children
        add_child(@receiver)
        add_child(@name)
        add_children(@args)
        add_child(@block_arg)
        add_child(@block)
      end
      self
    end

    def self.tags() [:method_add_arg, :call, :method_add_block, :field] end

    def initialize(sexp)
      @args = []
      @block_arg = nil
      @block = nil

      case sexp[0]
      when :call, :field
        initialize_call(sexp)
      when :method_add_block
        marg = sexp[1]
        if marg[0] == :method_add_arg
          initialize_method_arg(marg[1], marg[2])
        elsif marg[0] == :command
          initialize_call([:call, nil, nil, marg[1]])
          initialize_args(marg[2]) if marg.length > 2
        elsif marg[0] == :command_call
          initialize_call([:call, marg[1], marg[2], marg[3]])
          initialize_args(marg[4]) if marg.length > 4
        else
          initialize_method_arg(marg, [])
        end
        @block = to_node(sexp[2])
        add_child(@block)
      else
        initialize_method_arg(sexp[1], sexp[2])
      end
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.call(self)
    end

    private

    def initialize_method_arg(msg, arg_paren)
      if msg[0] == :fcall
        initialize_call([:call, nil, nil, msg[1]])
      elsif msg[0] == :call
        initialize_call(msg)
      else
        raise 'unknown pattern ' + msg.to_s
      end

      if arg_paren.length > 0
        args_block = has_tag?(arg_paren, :arg_paren)[1]
        unless args_block.nil?
          initialize_args(args_block)
        end
      end
    end

    def initialize_call(sexp)
      @receiver = to_node(sexp[1])
      @op = sexp[2]	# :"." or :"::" or nil.
      @name = if sexp[3] == :call
                nil
              else
                @name = to_node(has_tag?(sexp[3], :@ident))
              end
      add_child(@receiver)
      add_child(@name)
    end

    def initialize_args(args_block)
      args = if args_block[0] == :args_add_block
               args_block[1]
             else
               args_block
             end
      args2 = initialize_star_arg(args)
      @args = to_nodes(args2)
      @block_arg = if args_block[2]
                     to_node(args_block[2])
                   else
                     nil
                   end
      add_children(@args)
      add_child(@block_arg)
    end

    def initialize_star_arg(args)
      if args[0] == :args_add_star
        new_args = initialize_star_arg(args[1]) + [[:unary, :*, args[2]]]
        for i in 3...args.size
          new_args << args[i]
        end
        new_args
      else
        args
      end
    end
  end

  # A method call without parentheses.
  #
  class Command < Call
    def self.tags() [:command, :command_call] end

    def initialize(sexp)
      if sexp[0] == :command
        initialize_call([:call, nil, nil, sexp[1]])
        arg_exp = sexp[2]
      elsif sexp[0] == :command_call
        initialize_call([:call, sexp[1], sexp[2], sexp[3]])
        arg_exp = sexp[4]
      else
        raise "unknown pattern " + sexp.to_s
      end

      if arg_exp[0] == :args_add_block
        initialize_args(arg_exp)
      else
        @args = to_nodes(arg_exp)
        @block_arg = nil
        add_children(@args)
      end

      @block = nil
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.command(self)
    end
  end

  # Array reference.
  #
  class ArrayRef < ASTnode
    include AstHelper

    # @return [ASTnode] the array object.
    attr_reader :array

    # @return [Array<ASTnode>] all the comma-separated indexes.
    #   It may be an empty array.
    attr_reader :indexes

    def self.tag() :aref end

    def initialize(sexp)
      @array = to_node(sexp[1])
      args_block = sexp[2]
      if args_block.nil?
        @indexes = []
      else
        args = has_tag?(args_block, :args_add_block)[1]
        @indexes = to_nodes(args)
      end

      add_child(@array)
      add_children(@indexes)
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.array_ref(self)
    end
  end

  # Array reference as L-value.
  #
  class ArrayRefField < ArrayRef
    def self.tag() :aref_field end

    def initialize(sexp)
      super sexp
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.array_ref_field(self)
    end
  end

  # if, unless, modifier if/unless, and ternary if (`?:`).
  #
  class Conditional < ASTnode
    include AstHelper
    # @return [Symbol] `:if`, `:unless`, `:if_mod`, `:unless_mod`,
    #   or `:ifop`.
    attr_reader :op

    # @return [ASTnode] the condition expression.
    attr_reader :cond

    # @return [ASTnode] the then-expressin.
    attr_reader :then

    # Returns the elsif-expressions.
    # @return [Array<ASTnode>] an array of the elsif-expressions.
    #   It may be an empty array.
    attr_reader :all_elsif

    # @return [ASTnode|nil] the else-expression.
    attr_reader :else

    def self.tags() [:if, :unless, :ifop, :if_mod, :unless_mod] end

    def initialize(sexp)
      @op = sexp[0]
      @cond = to_node(sexp[1])
      @all_elsif = []
      case @op
      when :ifop                   # ternary if
        @then = to_node(sexp[2])
        @else = to_node(sexp[3])
      when :if_mod, :unless_mod    # modifier if/unless
        @then = to_node(sexp[2])
        @else = nil
      else                         # if/unless
        @then = Exprs.make(sexp[2])
        initialize_else(sexp[3])
      end
      add_child(@cond)
      add_child(@then)
      add_child(@else)
      @all_elsif.each do |pair|
        pair.each { |e| add_child(e) }
      end
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.conditional(self)
    end

    private
    def initialize_else(else_part)
      if else_part.nil?
        @else = nil
      elsif else_part[0] == :elsif
        @all_elsif << [to_node(else_part[1]), Exprs.make(else_part[2])]
        initialize_else(else_part[3])
      else
        @else = Exprs.make(has_tag?(else_part, :else)[1])
      end
    end
  end

  # while, until, and modifier while/until.
  #
  class Loop < ASTnode
    include AstHelper

    # @return [Symbol] `:while`, `:until`, `:while_mod`, or `:until_mod`.
    attr_reader :op

    # @return [ASTnode] the condition expression.
    attr_reader :cond

    # @return [ASTnode] the loop body.
    attr_reader :body

    def self.tags() [:while, :until, :while_mod, :until_mod] end

    def initialize(sexp)
      @op = sexp[0]
      @cond = to_node(sexp[1])
      case @op
      when :while_mod, :until_mod
        @body = to_node(sexp[2])
      else
        @body = Exprs.make(sexp[2])
      end
      add_child(@cond)
      add_child(@body)
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.loop(self)
    end

    # Returns the real operator name.
    # @return [Symbol] the real operator name, `while` or `until`.
    def real_operator
      case @op
      when :while_mod
        :while
      when :until_mod
        :until
      else
        @op
      end
    end
  end

  # For statement.
  #
  class ForLoop < ASTnode
    include AstHelper

    # @return [Array<ASTnode>] the variables.
    attr_reader :vars

    # @return [ASTnode] the elements.
    attr_reader :set

    # @return [ASTnode] the loop body.
    attr_reader :body

    def self.tag() :for end

    def initialize(sexp)
      if sexp[1][0] == :var_field
        @vars = [ to_node(sexp[1][1]) ]
      else
        @vars = to_nodes(sexp[1])
      end
      @set = to_node(sexp[2])
      @body = Exprs.make(sexp[3])
      add_children(@vars)
      add_child(@set)
      add_child(@body)
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.for_loop(self)
    end
  end

  # break, next, redo, or retry.
  #
  class Break < ASTnode
    include AstHelper
    # @return [Symbol] `:break`, `:next`, `:redo`, or `:retry`.
    attr_reader :op
    # @return [Array<ASTnode>] an array of the break/next arguments.
    attr_reader :values

    def self.tags() [:break, :next, :redo, :retry] end

    def initialize(sexp)
      @op = sexp[0]
      if @op == :break || @op == :next
        if sexp[1].size == 0
          @values = []
        else
          values = has_tag?(sexp[1], :args_add_block)[1]
          @values = to_nodes(values)
        end
        add_children(@values)
      else
        @values = []
      end
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.break_out(self)
    end
  end

  # Return.
  #
  class Return < ASTnode
    include AstHelper
    # Gets the returned values.
    # @return [Array<ASTnode>] the returned values.
    #   It may be an empty array.
    attr_reader :values

    def self.tags() [:return, :return0] end

    def initialize(sexp)
      if sexp.length < 2    # return0
        @values = []
      else
        values = has_tag?(sexp[1], :args_add_block)[1]
        @values = to_nodes(values)
        add_children(@values)
      end
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.return_values(self)
    end
  end

  # @abstract
  #
  class Parameters < ASTnode
    include AstHelper
    # @return [Array<ASTnode>] the parameter list.
    attr_reader :params
    # @return [Array<Array<ASTnode>>] the list of parameters with default values.
    #   Each element is `[name, value]`.
    attr_reader :optionals
    # @return [ASTnode|nil] the parameter preceded by an asterisk (`*`).
    attr_reader :rest_of_params
    # @return [Array<ASTnode>] the parameters following the parameter
    #   with asterisk (`*`).
    attr_reader :params_after_rest
    # @return [Array<Array<ASTnode>>] the keyword parameters.
    #   Each element is `[keyword, value]`.
    attr_reader :keywords
    # @return [ASTnode|nil] the parameters preceded by two asterisks (`**`).
    attr_reader :rest_of_keywords
    # @return [ASTnode|nil] the parameter preceded by an ampersand (`&`).
    attr_reader :block_param

    # @param [Array] params  `[:params, ... ]`.
    def initialize(params)
      initialize_params(params)
    end

    def initialize_params(params)
      if params.nil?
        @params = []
        @optionals = []
        @rest_of_params = nil
        @params_after_rest = []
        @keywords = []
        @rest_of_keywords = nil
        @block_param = nil
      else
        if params[1].nil?
          @params = []
        else
          @params = to_nodes(params[1])
          add_children(@params)
        end

        if params[2].nil?
          @optionals = []
        else
          # [[name, value], ...]
          @optionals = params[2].map {|p| to_nodes(p) }
          @optionals.map {|p| add_children(p) }
        end

        if params[3].nil?
          @rest_of_params = nil
        else
          @rest_of_params = to_node(has_tag?(params[3], :rest_param)[1])
          add_child(@rest_of_params)
        end

        if params[4].nil?
          @params_after_rest = []
        else
          @params_after_rest = to_nodes(params[4])
          add_children(@params_after_rest)
        end

        if params[5].nil?
          @keywords = []
        else
          # [[keyword, value], ...]      value may be nil
          @keywords = params[5].map do |p|
            default_value = if p[1] then to_node(p[1]) else nil end
            [ to_node(p[0]), default_value ]
          end
          @keywords.map {|p| add_children(p) }
        end

        if params[6].nil?
          @rest_of_keywords = nil
        else
          rkeys = if params[6][0] == :@ident
                    params[6]  # Ruby 2.4 or earlier
                  else
                    has_tag?(params[6], :kwrest_param)[1]
                  end
          @rest_of_keywords = to_node(has_tag?(rkeys, :@ident))
        end

        if params[7].nil?
          @block_param = nil
        else
          @block_param = to_node(has_tag?(params[7], :blockarg)[1])
          add_child(@block_param)
        end
      end
    end
  end

  # Block.
  #
  class Block < Parameters
    # @return [ASTnode] the body.
    attr_reader :body
    # @return [Rescue|nil] the rescue clause.
    attr_reader :rescue

    def self.tags() [:brace_block, :do_block] end

    def initialize(sexp)
      var = has_tag?(sexp[1], :block_var)
      if var.nil?
        params = nil
      else
        params = has_tag?(var[1], :params)
      end
      initialize_vars(params, sexp[2])
    end

    def initialize_vars(params, body)
      initialize_params(params)
      if body.is_a?(Array) && body.length > 0 && body[0] == :bodystmt
        bodystmnt = body[1]
        @rescue = Rescue.make(body[2], body[3], body[4])
      else # if Ruby 2.4 or earlier
        bodystmnt = body
        @rescue = nil
      end
      @body = Exprs.make(bodystmnt)
      add_child(@body)
      add_child(@rescue)
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.block(self)
    end
  end

  # A lambda expression such as `-> (x) {x + 1}`.
  #
  # `lambda {|x|x+1}` is parsed as a call to `lambda` with
  # an argument `{|x|x + 1}`.  So it is an instance of {Call}.
  #
  class Lambda < Block
    def self.tag() :lambda end

    def initialize(sexp)
      if sexp[1][0] == :paren
        params = sexp[1][1]
      else
        params = sexp[1]
      end
      initialize_vars(params, sexp[2])
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.lambda_expr(self)
    end
  end

  # begin-rescue-ensure.
  #
  # `raise` is parsed as a method call (or a command).
  #
  class Rescue < ASTnode
    include AstHelper
    # @return [Array<ASTnode>] the exception types.  It may be empty.
    attr_reader :types
    # @return [ASTnode|nil] the rescue parameter.
    attr_reader :parameter
    # @return [ASTnode|nil] the body of the rescue clause.
    attr_reader :body
    # @return [Rescue|nil] the rest of rescue clauses.
    #   The returned object's {#else} and {#ensure} are `nil`.
    attr_reader :nested_rescue
    # @return [ASTnode|nil] the else clause.
    attr_reader :else
    # @return [ASTnode|nil] the ensure clause.
    attr_reader :ensure

    def self.tag() :rescue end

    def self.make(rescue_expr, else_expr, ensure_expr)
      if rescue_expr.nil? && else_expr.nil? && ensure_expr.nil?
        nil
      else
        Rescue.new(rescue_expr, else_expr, ensure_expr)
      end
    end

    def initialize(rescue_expr, else_expr=nil, ensure_expr=nil)
      if rescue_expr.nil?
        @types = []
        @parameter = nil
        @body = nil
        @nested_rescue = nil
      else
        expr = has_tag?(rescue_expr, :rescue)
        rescue_clause = expr[1]
        if rescue_clause.nil?
          @types = []
        elsif rescue_clause[0] == :mrhs_new_from_args
          types1 = to_nodes(rescue_clause[1])
          @types = types1 << to_node(rescue_clause[2])
        else
          @types = to_nodes(rescue_clause)
        end

        if expr[2].nil?
          @parameter = nil
        else
          @parameter = to_node(has_tag?(has_tag?(expr[2], :var_field)[1],
                                        :@ident))
        end

        @body = Exprs.make(expr[3])
        @nested_rescue = to_node(expr[4])
        add_children(@types)
        add_child(@parameter)
        add_child(@body)
        add_child(@nested_rescue)
      end

      if else_expr.nil?
        @else = nil
      else
        elsexpr = has_tag?(else_expr, :else)
        @else = Exprs.make(elsexpr[1])
        add_child(@else)
      end

      if ensure_expr.nil?
        @ensure = nil
      else
        ensexpr = has_tag?(ensure_expr, :ensure)
        @ensure = Exprs.make(ensexpr[1])
        add_child(@ensure)
      end
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.rescue_end(self)
    end

    # @return [Boolean] true if the rescue clause is included.
    def has_rescue?
      !@body.nil?
    end

    # @return [Boolean] true if the else clause is included.
    def has_else?
      !@else.nil?
    end

    # @return [Boolean] true if the ensure clause is included.
    def has_ensure?
      !@ensure.nil?
    end
  end

  # begin-end.
  #
  class BeginEnd < ASTnode
    include AstHelper
    # @return [Exprs|ASTnode] the body.
    attr_reader :body
    # @return [Rescue|nil] the rescue clause.
    attr_reader :rescue

    def self.tag() :begin end

    def initialize(sexp)
      bodystmt = has_tag?(sexp[1], :bodystmt)
      @body = Exprs.make(bodystmt[1])
      @rescue = Rescue.make(bodystmt[2], bodystmt[3], bodystmt[4])
      add_child(@body)
      add_child(@rescue)
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.begin_end(self)
    end
  end

  # Method definition or a singular method definition.
  #
  class Def < Parameters
    # @return [ASTnode|nil] the object if the definition is a singular method.
    attr_reader :singular
    # @return [Identifier] the method name.
    attr_reader :name
    # @return [Exprs|ASTnode] the body.
    attr_reader :body
    # @return [Rescue|nil] the rescue clause.
    attr_reader :rescue

    def self.tags() [:def, :defs] end

    def initialize(sexp)
      if sexp[0] == :def
        @singular = nil
        offset = 0
      else
        @singular = to_node(sexp[1])
        add_child(@singular)
        offset = 2
      end

      def_name = sexp[1 + offset]
      @name = if def_name[0] == :@op
                to_node(def_name)
              else
                to_node(has_tag?(def_name, :@ident))
              end
      add_child(@name)

      params = sexp[2 + offset]
      if !params.nil? && params[0] == :paren
        super(params[1])
      else
        super(params)
      end

      bodystmt = has_tag?(sexp[3 + offset], :bodystmt)
      @body = Exprs.make(bodystmt[1])
      @rescue = Rescue.make(bodystmt[2], bodystmt[3], bodystmt[4])
      add_child(@body)
      add_child(@rescue)
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.define(self)
    end
  end

  # Module definition.
  #
  class ModuleDef < ASTnode
    include AstHelper
    # @return [Const|ConstPathRef] the module name.
    attr_reader :name
    # @return [Exprs|ASTnode] the body.
    attr_reader :body
    # @return [Rescue|nil] the rescue clause.
    attr_reader :rescue

    def self.tag() :module end

    def initialize(sexp)
      @name = to_node(sexp[1])  # Const or ConstPathRef
      add_child(@name)
      initialize_body(has_tag?(sexp[2], :bodystmt))
    end

    def initialize_body(bodystmt)
      @body = Exprs.make(bodystmt[1] - [[:void_stmt]])
      @rescue = Rescue.make(bodystmt[2], bodystmt[3], bodystmt[4])
      add_child(@body)
      add_child(@rescue)
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.module_def(self)
    end
  end

  # Class definition.
  #
  class ClassDef < ModuleDef
    # @return [ASTnode|nil] the super class.
    attr_reader :superclass

    def self.tag() :class end

    def initialize(sexp)
      @name = to_node(sexp[1])  # Const or ConstPathRef
      add_child(@name)
      @superclass = to_node(sexp[2])
      add_child(@superclass)
      initialize_body(has_tag?(sexp[3], :bodystmt))
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.class_def(self)
    end
  end

  # Singular class definition.
  #
  class SingularClassDef < ModuleDef
    def self.tag() :sclass end

    def initialize(sexp)
      @name = to_node(sexp[1])  # Keyword, VariableCall, ...
      add_child(@name)
      initialize_body(has_tag?(sexp[2], :bodystmt))
    end

    # @return [Keyword|VariableCall|ASTnode] self, the object, ...
    def name() super end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.singular_class_def(self)
    end
  end

  # Program.
  #
  class Program < ASTnode
    include AstHelper
    # @return [Exprs|ASTnode] the program elements.
    attr_reader :elements

    def self.tag() :program end

    def initialize(sexp)
      @elements = Exprs.make(sexp[1])
      add_child(@elements)
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.program(self)
    end
  end

  # @api private
  # A table of reified abstract syntax trees.
  # It is used for guaranteeing the uniqueness
  # of ASTree objects.
  #
  class ASTreeTable
    # @return [Hash] all the elements.
    attr_reader :trees

    def initialize()
      @trees = {}
    end

    # Records a key-value pair.
    # @param [Proc|Method|UnboundMethod] context  the key.
    # @param [ASTnode] ast  the value.
    def []=(context, ast)
      @trees[context] = ast
    end

    # Deletes a key-value pair.
    # @param [Proc|Method|UnboundMethod] context  the key.
    def delete(context)
      @trees.delete(context)
    end

    # Gets the value associated with the key.
    # @param [Proc|Method|UnboundMethod] context  the key.
    def [](context)
      @trees[context]
    end

    # Executes a block once for each element.
    def each(&blk)
      @trees.each_value(&blk)
    end
  end

  # Abstract syntax tree (AST).
  #
  class ASTree < ASTnode
    # @return [ASTreeTable] all the reified ASTs.
    attr_reader :astrees

    # @return [Method|Proc] the Method or Proc object given
    #   for the reification.
    attr_reader :context

    # @return [String] the source file name.
    attr_reader :file_name

    # @return [ASTnode] the AST.
    attr_reader :tree

    def initialize(ast_table, proc, file, sexp)
      unless proc.is_a?(Proc) || proc.is_a?(Method) ||
             proc.is_a?(UnboundMethod)
        raise "unknown context #{proc.class.name}"
      end

      @astrees = ast_table   # ASTreeTable
      @context = proc	# Proc or Method
      @file_name = file
      @tree = ASTree.to_node(sexp)
      add_child(@tree)
      @astrees[proc] = self
    end

    def pretty_print(pp)
      Yadriggy::simpler_pretty_print(pp, self, "@astrees")
    end

    # Gets the abstract syntax tree of the given procedure.
    #
    # @param [Proc|Method|UnboundMethod] proc the procedure or method.
    # @return [ASTree|nil] the reified AST.
    # @see Yadriggy.reify
    def reify(proc)
      ast_obj = @astrees[proc]
      unless ast_obj.nil?
        ast_obj
      else
        ast = SourceCode.get_sexp(proc)
        ast && ast[1] && ASTree.new(@astrees, proc, ast[0], ast[1])
      end
    end

    # A method for Visitor pattern.
    # @param [Eval] evaluator the visitor of Visitor pattern.
    # @return [void]
    def accept(evaluator)
      evaluator.astree(self)
    end

    @tags = {
        Const.tag => Const,
        Reserved.tag => Reserved,
        Label.tag => Label,
        GlobalVariable.tag => GlobalVariable,
        VariableCall.tag => VariableCall,
        Super.tag => Super,
        Paren.tag => Paren,
        ArrayLiteral.tag => ArrayLiteral,
        StringInterpolation.tag => StringInterpolation,
        Unary.tag => Unary,
        Binary.tag => Binary,
        ArrayRef.tag => ArrayRef,
        ArrayRefField.tag => ArrayRefField,
        ForLoop.tag => ForLoop,
        Lambda.tag => Lambda,
        Rescue.tag => Rescue,
        BeginEnd.tag => BeginEnd,
        ModuleDef.tag => ModuleDef,
        ClassDef.tag => ClassDef,
        SingularClassDef.tag => SingularClassDef,
        Program.tag => Program
    }

    def self.append_tags(clazz)
      clazz.tags.each {|t| @tags[t] = clazz }
    end

    append_tags(Identifier)
    append_tags(SymbolLiteral)
    append_tags(InstanceVariable)
    append_tags(Number)
    append_tags(StringLiteral)
    append_tags(ConstPathRef)
    append_tags(ConstPathField)
    append_tags(Dots)
    append_tags(Assign)
    append_tags(HashLiteral)
    append_tags(Call)
    append_tags(Command)
    append_tags(Conditional)
    append_tags(Loop)
    append_tags(Break)
    append_tags(Return)
    append_tags(Block)
    append_tags(Def)

    def self.to_node(sexp)
      if sexp.nil?
        nil
      elsif sexp[0] == :var_ref || sexp[0] == :var_field ||
            sexp[0] == :const_ref
        to_node(sexp[1])
      else
        klass = @tags[sexp[0]]
        if klass.nil?
          sexp_name = if sexp.is_a?(Array)
                        sexp[0].to_s
                      else
                        ':' + sexp.to_s
                      end
          raise "unknown s-expression " + sexp_name
        else
          node = klass.new(sexp)
          StringLiteral.normalize(node)
        end
      end
    end
  end

  private
  def self.simpler_pretty_print(pp, obj, key)
    pp.object_address_group(obj) do
      obj.instance_variables.each do |v|
        pp.breakable
        v = v.to_s if Symbol === v
        pp.text(v)
        pp.text('=')
        pp.group(1) do
          if v == key
            pp.text('...')
          else
            pp.breakable
            pp.pp(obj.instance_eval(v))
          end
        end
      end
    end
  end

end
