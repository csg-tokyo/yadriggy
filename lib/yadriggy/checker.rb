# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'yadriggy/ast'

module Yadriggy

  # Exception thrown by a checker.
  class CheckError < RuntimeError
  end

  # AST checker.
  # It visits the AST nodes and does various checks like type checking.
  class Checker
    include Yadriggy

    # Defines the rule for a node type.
    #
    # @param [Class] node_type    the type of the AST node.
    # @yield The block is executed for the node with `node_type`.
    # @return [void]
    def self.rule(node_type, &proc)
      init_class if @rules.nil?
      @rules[node_type] = proc
      @rule_declarators[node_type] = self
    end

    # @api private
    # Initializes this class if necessary.
    def self.check_init_class
      init_class if @rules.nil?
    end

    # @api private
    # @return [Array<Hash>] all the rules defined so far.
    def self.all_rules
      [@rules, @rule_declarators]
    end

    private_class_method def self.init_class
      @rules = {}
      @rule_declarators = {}
      unless self.superclass == Object
        all = self.superclass.all_rules
        unless all[0].nil?
          @rules = all[0].clone
          @rule_declarators = all[1].clone
        end
      end
    end

    # @api private
    # internal-use only.  Don't call this.
    # @return [Pair<Proc,Class>] a rule and the class declaring it, or nil.
    #
    def self.find_rule_entry(ast)
      find_rule_entry2(ast.class, ast.usertype)
    end

    private_class_method def self.find_rule_entry2(ast_class, utype)
      unless utype.nil?
        rule = @rules[utype]
        return [rule, @rule_declarators[utype]] unless rule.nil?
      end

      rule = @rules[ast_class]
      if rule.nil?
        if ast_class.superclass.nil?
          nil
        else
          find_rule_entry2(ast_class.superclass, utype)
        end
      else
        [rule, @rule_declarators[ast_class]]
      end
    end

    # Initializes the object.
    def initialize
      self.class.check_init_class
      @error = nil
      @check_list = []
      @current_ast = nil
      @current_env = nil
      @rule_declarator = nil
    end

    # @return [String] an error message when the last invocation of check()
    # returns nil.
    def error
      @error || ''
    end

    # Applies rules to the given AST.
    # It returns the result of the rule-application or throws
    # a CheckError.
    # This is the entry point of the checker.  It may also
    # check the other ASTs invoked in the given AST.
    #
    # @param [ASTree|ASTnode] an_ast  the AST.
    # @return [Object]
    def check_all(an_ast)
      return nil if an_ast.nil?
      an_ast = an_ast.tree if an_ast.is_a?(ASTree)
      t = check(an_ast, make_base_env(an_ast.get_context_class))
      until (checked = @check_list.pop).nil?
        @current_ast = checked[0]
        @current_env = checked[1]
        checked[2].call
      end
      t
    end

    # Makes a new base environment with the given context class.
    # @param [Module] klass  the context class.
    def make_base_env(klass)
      klass
    end

    # Applies rules to the given AST.
    #
    # It assumes that ast is processed by Syntax and it has usertype method.
    # An exception is thrown when the checking fails.
    # ast may be nil.
    #
    # The environment given to this method can be accessed in the rules
    # through ast_env().  It is optional and can be any object.
    # The initial one is made by make_base_env().
    #
    # @return [Object]
    def check(an_ast, ast_env=nil)
      if an_ast.nil?
        nil
      else
        rule = self.class.find_rule_entry(an_ast)
        apply_typing_rule(rule, an_ast, ast_env)
      end
    end

    # @api private
    # internal use only
    def apply_typing_rule(rule, an_ast, ast_tenv)
      if rule.nil?
        error_found!(an_ast, "no typing rule for #{an_ast.class}")
      else
        old_ast = @current_ast
        old_tenv = @current_env
        old_declarator = @rule_declarator
        @current_ast = an_ast
        @current_env = ast_tenv unless ast_tenv.nil?
        @rule_declarator = rule[1]
        t = instance_exec(&rule[0])
        @rule_declarator = old_declarator
        @current_env = old_tenv
        @current_ast = old_ast
        return t
      end
    end

    # Applies the rule supplied by the superclass.
    # @param [ASTnode] an_ast  an AST.
    # @param [Object] envi  an environment object.
    # @return [Type] the type of the given AST.
    def proceed(an_ast, envi=nil)
      rule = if @rule_declarator&.superclass == Object
               nil
             else
               @rule_declarator&.superclass.find_rule_entry(an_ast)
             end
      if rule.nil?
        error_found!(an_ast, 'no more rule. we cannot proceed')
      else
        apply_typing_rule(rule, an_ast, envi)
      end
    end

    # @return [ASTnode] the current abstract syntax tree.
    def ast
      @current_ast
    end

    # @return [Object] the current environment.
    def ast_env
      @current_env
    end

    # Later invokes the block, which performs checking.
    # The method immediately returns.
    # This is used for avoiding infinite regression during the checking.
    # @yield The block is later executed for checking.
    # @return [void]
    def check_later(&proc)
      cur_ast = @current_ast
      cur_env = @current_env
      @check_list << [cur_ast, cur_env, proc]
    end

    # Throws an error.
    #
    # @param [ASTnode] an_ast  the AST causing the error.
    # @param [String] msg  the error message.
    # @return [void]  always throws an exception.
    def error_found!(an_ast, msg='')
      loc  = if an_ast.is_a?(ASTnode)
               an_ast.source_location_string
             else
               ''
             end
      @error = "#{loc} DSL #{error_group} error. #{msg}"
      binding.pry if Yadriggy.debug > 1
      raise CheckError.new(@error)
    end

    # @api private
    def error_group
      ''
    end

    init_class
  end
end
