# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'yadriggy/ast'
require 'yadriggy/ast_location'

module Yadriggy
  # Defines syntax and returns a {Syntax} object.
  # {Yadriggy#define_syntax} is not available in a method body.
  # @param [Proc] block  the syntax definition.
  # @return [Syntax] the defined syntax.
  def self.define_syntax(&block)
    ast = reify(block)
    if Syntax.check_syntax(ast.tree)
      Syntax.new(ast)
    else
      raise Syntax.last_error
    end
  end

  class ASTnode
    # also defined in ast.rb

    # The user type (or non-terminal symbol) corresponding
    # to this node.
    # @return [Symbol|nil] the user type.
    attr_accessor :usertype
  end

  # An exception.
  class SyntaxError < RuntimeError
  end

  # Syntax checker.
  #
  class Syntax
    # @return [Hash] the grammar rules.
    attr_reader :hash

    # debugging mode is on if true.
    attr_writer :debug

    @syntax = nil	# initialized later

    # Checks the syntax of the grammar rules.
    #
    # @param [ASTnode] block  the grammar rules.
    # @return [Boolean] false if a syntax error is found in the given
    #   grammar rules.
    def self.check_syntax(block)
      @syntax.nil? || @syntax.check(block)
    end

    # @return [String] the error message for the grammar rule
    #   last checked.
    def self.last_error
      @syntax.error
    end

    # @param [ASTree] ast  the grammar rules.
    def initialize(ast)
      @error_loc = nil
      @error_msg = nil
      @debug = false
      @hash = {}
      update_hash(ast.tree.body)
    end

    # @private
    # @param [Body] body
    # @return [void]
    def update_hash(body)
      return if body.nil?

      if body.is_a?(Binary)
        key = to_hash_key(body.left)
        @hash[key] = body.right
      else
        body.expressions.each do |e|
          @hash[to_hash_key(e.left)] = e.right
        end
      end
    end

    # Adds rules.
    # @param [Syntax] syntax  the rules of this given syntax are added.
    #   This parameter is optional.
    # @yield the rules in the block are added.
    #   The block is optional.
    def add_rules(syntax=nil, &block)
      if syntax.is_a?(Syntax)
        syntax.hash.each do |k,v|
          @hash[k] = v
        end
      elsif block.is_a?(Proc)
        ast = Yadriggy::reify(block)
        if Syntax.check_syntax(ast.tree)
          update_hash(ast.tree.body)
        else
          raise Syntax.last_error
        end
      end
    end

    # Checks the syntax of the given AST and raise an error if
    # a syntax error is found.
    #
    # @param [ASTree|ASTnode] astree  the AST returned by {Yadriggy::reify}.
    # @return [void]
    # @raise [SyntaxError] when a syntax error is found.
    def check_error(astree)
      raise_error unless check(astree.is_a?(ASTree) ? astree.tree : astree)
    end

    # Checks the syntax of the given AST.
    #
    # @param [ASTnode] tree  the AST.
    # @return [Boolean] true when the given AST is syntactically correct.
    def check(tree)
      error_cleared!
      expr = find_hash_entry(tree.class)
      if expr
        check_expr(expr, tree, false) || error_found!(tree, tree)
      else
        error_found!(tree, tree, "no rule for #{tree.class}")
      end
    end

    # Checks whether the given AST matches the grammar rule for
    # the given user type.
    #
    # @param [String|Symbol] user_type  the name of the user type.
    # @param [ASTnode] tree  the AST.
    # @return [Boolean] true if the given AST matches.
    def check_usertype(user_type, tree)
      error_cleared!
      check_rule_usertype(user_type.to_s, tree, false)
    end

    # Returns an error message.
    # @return [String] an error message when the last invocation of {#check}
    #   returns false.
    def error
      if @error_loc.nil? && @error_msg.nil?
        ''
      else
        "#{@error_loc} DSL syntax error#{@error_msg}"
      end
    end

    # Raises a syntax-error exception.
    # @raise [SyntaxError] always.
    def raise_error
      raise SyntaxError.new(error)
    end

    private

    def to_node_class(name)
      Yadriggy::const_get(name)
    end

    def to_hash_key(left)
      if left.is_a?(Const)
        to_node_class(left.name).name
      else
        left.name
      end
    end

    def error_found!(ast1, ast2, msg=nil)
      if @error_loc.nil?
        @error_loc  = if ast1.is_a?(ASTnode)
                        ast1.source_location_string
                      elsif ast2.is_a?(ASTnode)
                        ast2.source_location_string
                      else
                        ''
                      end
      end
      @error_msg = ", #{msg}#{@error_msg}" unless msg.nil?
      false
    end

    def error_cleared!
      @error_loc = nil
      @error_msg = nil
      true
    end

    # Returns true if no rule for the given (non-user) type is found
    # or if ast matches the rule.
    #
    def check_rule(node_class, ast, in_hash)
      if in_hash
        expr = find_hash_entry(ast.class)
      else
        expr = find_hash_entry(node_class)
      end
      result = (expr.nil? || check_expr(expr, ast, false) || error_found!(ast, ast))
      if @debug && !result || @debug == 1
        warn "check rules for #{node_class}, #{result}"
        @debug = true
      end
      result
    end

    def find_hash_entry(node_class)
      expr = @hash[node_class.name]
      if expr.nil? && !node_class.superclass.nil?
        find_hash_entry(node_class.superclass)
      else
        expr
      end
    end

    def check_rule_usertype(node_type_name, ast, in_hash)
      expr = @hash[node_type_name]
      expr && tag_and_check_expr(node_type_name, expr, ast, in_hash) || error_found!(ast, ast)
    end

    # Adds a user-type tag to the given AST.
    def tag_and_check_expr(node_type_name, expr, ast, in_hash)
      return if ast.is_a?(Array)
      unless ast.nil?
        old_usertype = ast.usertype
        ast.usertype = node_type_name.to_sym
      end

      success = check_expr(expr, ast, in_hash)
      unless success || ast.nil?
        ast.usertype = old_usertype
      end
      success
    end

    def check_expr(expr, ast, in_hash)
      if expr.is_a?(Binary) && expr.op == :|
        check_expr(expr.left, ast, in_hash) ||
        check_add_expr(expr.right, ast, in_hash) && error_cleared!
      else
        check_add_expr(expr, ast, in_hash)
      end
    end

    def check_add_expr(expr, ast, in_hash)
      if expr.is_a?(Binary) && expr.op == :+
        check_add_expr(expr.left, ast, in_hash) &&
        check_operand(expr.right, ast, in_hash)
      else
        check_operand(expr, ast, in_hash)
      end
    end

    def check_operand(operand, ast, in_hash)
      if operand.is_a?(Const)
        clazz = to_node_class(operand.name)
        ast.is_a?(clazz) && check_rule(clazz, ast, in_hash)
      elsif operand.is_a?(Reserved)
        ast == nil || ast == []
      elsif operand.is_a?(IdentifierOrCall)
        check_rule_usertype(operand.name, ast, in_hash)
      elsif operand.is_a?(HashLiteral)
        check_hash(operand, ast)
      else
        false
      end
    end

    def check_hash(hash, ast)
      !ast.nil? && hash.pairs.all? do |p|
        field = p[0].name
        raise_hash_error(field, ast) unless ast.class.method_defined?(field)
        if check_or_constraint(p[1], ast.send(field))
          true
        else
          if @debug
            warn "  failed to check \##{field}"
            @debug = 1
          end
          error_found!(ast.send(field), ast,
                       "#{field} in #{ast.usertype.nil? ? ast.class : ast.usertype}?")
        end
      end
    end

    def raise_hash_error(field, ast)
      raise SyntaxError.new("unknown method `#{field}' in #{ast.class} tested during syntax checking (wrong grammar?)")
    end

    def check_or_constraint(or_con, ast)
      if or_con.is_a?(Binary) && or_con.op == :|
        check_or_constraint(or_con.left, ast) ||
        check_constraint(or_con.right, ast) && error_cleared!
      else
        check_constraint(or_con, ast)
      end
    end

    def check_constraint(con, ast)
      if con.is_a?(StringLiteral)
        con.value == ast
      elsif con.is_a?(SymbolLiteral)
        con.to_sym == ast
      elsif con.is_a?(Reserved)
        ast == nil || ast == []
      elsif con.is_a?(Const)
        check_const_constraint(con, mabye_one_element_array(ast))
      elsif con.is_a?(IdentifierOrCall)
        check_rule_usertype(con.name, mabye_one_element_array(ast), true)
      elsif con.is_a?(Paren)
        ast == nil || check_or_constraint(con.expression, ast)
      elsif con.is_a?(ArrayLiteral)
        ast.is_a?(Array) &&
          if con.elements.size == 0
            ast.size == 0
          elsif con.elements.size == 1
            con0 = con.elements[0]
            ast.all? do |e|
              check_one_array_element(con0, e) || error_found!(e, ast)
            end
          else
            con.elements.size - 1 <= ast.size &&
              check_array_elements(con.elements, ast)
          end
      else
        false
      end
    end

    def check_array_elements(con_elements, ast_elements)
      ast_i = 0
      for i in 0..con_elements.size - 2
        if check_one_array_element(con_elements[i], ast_elements[ast_i])
          ast_i += 1
        else
          unless con_elements[i].is_a?(Paren)
            return error_found!(ast_elements[ast_i], ast_elements)
          end
        end
      end
      con = con_elements.last
      while ast_i < ast_elements.size
        if check_one_array_element(con, ast_elements[ast_i])
          ast_i += 1
        else
          return error_found!(ast_elements[ast_i], ast_elements)
        end
      end
      true
    end

    def check_one_array_element(con, element)
      if element.is_a?(Array)
        check_pair_element(con, element, element.size - 1)
      else
        check_or_constraint(con, element)
      end
    end

    def check_pair_element(con, element, idx)
      if con.is_a?(Binary) && con.op == :*
        idx > 0 && check_or_constraint(con.right, element[idx]) &&
          check_pair_element(con.left, element, idx - 1)
      else
        idx == 0 && check_or_constraint(con, element[0])
      end
    end

    def check_const_constraint(con, ast)
      ast.is_a?(to_node_class(con.name)) &&
        check_rule(ast.class, ast, true)
    end

    # Rule 'expr <= term' accepts a single element array of term.
    # Recall that 'expr <= [ term ]' also accepts an array of term
    # but the length of the array may be more than one.
    #
    def mabye_one_element_array(ast)
      if ast.is_a?(Array) && ast.size == 1
        ast[0]
      else
        ast
      end
    end

    # The syntax of the BNF-like DSL, which is used for describing
    # a syntax in this system.
    #
    # the right-hand side of = cannot be Const when the = expression
    # is in a method body.  In that case, use <=.
    #
    # The operator | is ordered choice as in PEG (parsing expression
    # grammar).
    #
    # (<pat>) specifies <pat> is optional.
    #
    # [<pat>] specifies an array of <pat>.
    #
    # <pat> may match a single-element array of <pat>.
    #
    # The hash literal specifies constraints on node properties.
    # For example, `Binary = { op: :+ }` specifies that the `op` property
    # of `Binary` has to be `:+`.  Note that the other properties such
    # as `left` and `right` are not checked.  Hence, when the rules are
    # <pre>Binary = { op: :+ }
    # Unary = { op: :! }</pre>
    # `a + -b` causes no syntax error since the unary expression `-b` is
    # the right operand of the binary expression.  The rule for {Binary}
    # is passed and hence the rule for {Unary} is not applied to `-b`.
    # <pre>Binary = { op: :+, right: Unary }
    # Unary = { op: :! }</pre>
    #
    # An AST subtree passes syntax checking if no rule is found for that
    # subtree.
    #
    @syntax = Yadriggy.define_syntax do
      nil_value = Reserved + { name: 'nil' }

      ArrayLiteral = { elements: [ array_elem ] }
      array_elem  = Binary + { op: :*, left: array_elem,
                               right: or_constraint } |
                    or_constraint
      Paren      = { expression: or_constraint }
      constraint = Const | IdentifierOrCall | Paren | ArrayLiteral |
                   StringLiteral | SymbolLiteral | nil_value
      or_constraint = Binary + { op: :|, left: or_constraint,
                                 right: constraint } |
                      constraint
      HashLiteral = { pairs: [ Label * or_constraint ] }

      operand    = Const | IdentifierOrCall | HashLiteral | nil_value
      add_expr   = Binary + { op: :+, left: add_expr, right: operand } |
                   operand
      expr       = Binary + { op: :|, left: expr, right: add_expr } |
                   add_expr

      rule       = Binary +
                   { left: Const | IdentifierOrCall, op: :'=' | :'<=',
                     right: expr }
      Exprs      = { expressions: [ rule ] }
      Parameters = { params: [],
                     optionals: [],
                     rest_of_params: nil,
                     params_after_rest: [],
                     keywords: [],
                     rest_of_keywords: nil,
                     block_param: nil }
      Block      = Parameters + { body: nil | rule | Exprs  }
    end

    public

    # Defines Ruby syntax and returns its Syntax object.
    # @return [Syntax] the Ruby syntax.
    def self.ruby_syntax
      Yadriggy.define_syntax do
        expr  <= Name | Number | Super | Binary | Unary | SymbolLiteral |
                ConstPathRef | StringLiteral | StringInterpolation |
                ArrayLiteral | Paren | Call | ArrayRef | HashLiteral |
                Return | ForLoop | Loop | Conditional | Break |
                Lambda | BeginEnd | Def | ModuleDef
        exprs <= Exprs | expr

        Name <= { name: String }
        Number     <= { value: Numeric }
        Super      <= {}
        Identifier <= Name
        SymbolLiteral    <= { name: String }
        VariableCall     <= Name
        InstanceVariable <= Name
        GlobalVariable   <= Name
        Label      <= Name
        Reserved   <= Name
        Const      <= Name
        Binary     <= { left: expr, op: Symbol, right: expr }
        ArrayRef   <= { array: expr, indexes: [ expr ] }
        ArrayRefField  <= ArrayRef
        Assign     <= Binary
        Dots       <= Binary
        Unary      <= { op: Symbol, operand: expr }
        ConstPathRef   <= { scope: (ConstPathRef | Const), name: Const }
        ConstPathField <= ConstPathRef
        StringLiteral  <= { value: String }
        StringInterpolation <= { contents: [ exprs ] }
        ArrayLiteral   <= { elements: [ expr ] }
        Paren      <= { expression: expr }
        HashLiteral    <= { pairs: [ expr * expr ] }
        Return     <= { values: [ expr ] }
        ForLoop    <= {vars: [ Identifier ], set: expr, body: exprs }
        Loop       <= { op: Symbol, cond: expr, body: exprs }
        Conditional <= { op: Symbol, cond: expr, then: exprs,
                         all_elsif: [expr * exprs], else: (exprs) }
        Parameters <= { params: [ Identifier ],
                       optionals: [ Identifier * expr ],
                       rest_of_params: (Identifier),
                       params_after_rest: [ Identifier ],
                       keywords: [ Label * expr ],
                       rest_of_keywords: (Identifier),
                       block_param: (Identifier) }
        Block      <= Parameters + { body: exprs }
        Lambda     <= Block
        Call       <= { receiver: (expr), op: (Symbol), name: Identifier,
                        args: [ expr ], block_arg: (expr), block: (Block) }
        Command    <= Call
        Exprs      <= { expressions: [ expr ] }
        Rescue     <= { types: [ Const | ConstPathRef ],
                        parameter: (Identifier),
                        body: (exprs), nested_rescue: (Rescue),
                        else: (exprs), ensure: (exprs) }
        BeginEnd   <= { body: exprs, rescue: (Rescue) }
        Def        <= Parameters +
                      { singular: (expr), name: Identifier, body: exprs,
                        rescue: (Rescue) }
        ModuleDef  <= { name: Const | ConstPathRef, body: exprs,
                        rescue: (Rescue) }
        ClassDef   <= ModuleDef +
                      { superclass: (Const | ConstPathRef) }
        SingularClassDef <= { name: expr, body: exprs,
                        rescue: (Rescue) }
        Program    <= { elements: exprs }
      end
    end
  end
end
