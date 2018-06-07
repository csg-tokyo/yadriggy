# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'yadriggy/syntax'
require 'yadriggy/checker'
require 'yadriggy/type'

module Yadriggy

  # Type checker for ASTree
  #
  # A type object used by TypeChecker can be an instance of any subclass
  # of Type.  It does not have to necessarily be an object representing
  # a "type".
  #
  class TypeChecker < Checker

    # TypeEnv (type environment) holds bindings between names and types.
    #
    # If you define a subclass of {TypeEnv}, override {#new_tenv} and
    # {#new_base_tenv}.  {TypeChecker#make_base_env} has to be overridden
    # as well.
    #
    class TypeEnv
      # @param [TypeEnv|nil] parent  the parent environment.
      def initialize(parent=nil)
        @parent = parent
        @names = {}
      end

      # Executes `block` for each name in this environment.
      # It passes the name-type pair as parameters to the block.
      #
      # @yield [name, type] gives a `Symbol` (name) and a `Type`.
      def each(&block)
        @names.each(&block)
      end

      # Makes a new type environment where all the bindings
      # are copied from the current type environment.
      #
      def new_tenv
        TypeEnv.new(self)
      end

      # Makes a new type environment.  klass is set to the context class
      # of that new environment.
      #
      # @param [Module] klass  the context class.  If it is `nil`, then
      #   `self`'s context class is passed.
      def new_base_tenv(klass=nil)
        BaseTypeEnv.new(klass.nil? ? context : klass)
      end

      # Binds name to type.
      #
      # @param [Name|String|Symbol|nil] name  the name.
      # @param [Type] type  the type.
      # @return [Type]  the type.
      def bind_name(name, type)
        @names[name.to_sym] = type unless name.nil?
      end

      # Gets the type bound to `name`, or nil if `name` is not bound to
      # any type.
      #
      # @param [Name|String|Symbol] name  the name.
      # @return [Type|nil]  the type bound to `name`.
      def bound_name?(name)
        type = @names[name.to_sym]
        if type.nil?
          @parent&.bound_name?(name)
        else
          type
        end
      end

      # Gets context class (enclosing class) or nil.
      #
      # @return [Module|nil] the context class.
      def context
        @parent&.context
      end

      # @private
      class BaseTypeEnv < TypeEnv
        def initialize(clazz)
          super(nil)
          @clazz = clazz
        end

        def context
          @clazz
        end
      end
    end # of TypeEnv

    # A type environement that collects free variables.
    # {#bound_name?} records the given symbol as a free variable name
    # when it obtains the type of that symbol from its parent type
    # environment.
    #
    class FreeVarFinder < TypeEnv
      # Obtains collected free variables.
      # @return [Hash<Symbol,Type>]  a map from variable names to their types.
      attr_reader :free_variables

      def initialize(parent)
        super
        @free_variables = {}
      end

      def bound_name?(name)
        type = @names[name.to_sym]
        if type.nil?
          t = @parent&.bound_name?(name)
          @free_variables[name.to_sym] = t unless t.nil?
          t
        else
          type
        end
      end
    end

    # Type definition.　It expresses a class (or singular class)
    # definition.　It maps an instance variable name or a method
    # name to its type.
    #
    # @see TypeChecker#typedef
    # @see TypeChecker#add_typedef
    class TypeDef
      def initialize()
        @names = {}
      end

      # Gets the type of an instance variable or a method.
      # @param [String|Symbol] name   its name.
      #  `name` can be any object with `to_sym`.
      # @return [Type|nil] its type.
      def [](name)
        @names[name.to_sym]
      end

      # Adds an instance variable or a method.
      # @param [String|Symbol] name  its name.
      #  `name` can be any object with `to_sym`.
      # @param [Type] type  its type.
      # @return [Type] the added type.
      def []=(name, type)
        @names[name.to_sym] = type
      end
    end

    def initialize
      super
      @typetable = {}
      @typedefs = {}
    end

    # Gets the current type environment.
    #
    def type_env
      @current_env
    end

    # Obtains the type definition associated with `key`.
    # Here, a type definition is a mapping from instance variables
    # or methods to their types.  It is defined per class or
    # individual instance object.
    # If `key` is `nil`, `nil` is returned.
    #
    # @param [Module|Object|nil] key  a class or an instance.
    # @return [TypeDef|nil] the type definition.
    def typedef(key)
      if key.nil?
        nil
      else
        @typedefs[key]
      end
    end

    # Adds a type definition if it does not exist.
    # Here, a type definition is a mapping from instance variables
    # or methods to their types.  It is defined per class or
    # individual instance object.
    #
    # @param [Module|Object] key  a class or an instance.
    # @return [TypeDef] the type definition for the class
    #   or instance given by `key`.
    def add_typedef(key)
      @typedefs[key] || @typedefs[key] = TypeDef.new
    end

    # Applies typing rules to the given AST.
    # It returns the type of the AST or throws
    # a CheckError.
    # This is the entry point of the type checker.  It may also
    # type the other ASTs invoked in the given AST.
    #
    # It assumes that the AST is processed by Syntax and it has
    # usertype method.
    #
    # This is an alias of check_all() but it memoizes the results.
    #
    def typecheck(an_ast)
      check_all(an_ast)
    end

    # Makes a new base type environment with the given context class.
    #
    def make_base_env(klass)
      TypeEnv::BaseTypeEnv.new(klass)
    end

    # @private
    # Internal-use only.  Don't use this method.  Use type().
    #
    def check(an_ast, ast_tenv=nil)
      type(an_ast, ast_tenv)
    end

    # Applies typing rules to determine the type of the given AST.
    # This method is effective in {.rule}.
    #
    # It assumes that the AST is processed by Syntax and it has
    # usertype method.  An exception is thrown when type checking
    # fails.
    #
    # @param [ASTnode|nil] an_ast  an AST or nil.
    # @param [TypeEnv|nil] ast_tenv  a type environment or nil.
    # @return [Type] the type of the given AST.  It memoizes the results.
    def type(an_ast, ast_tenv=nil)
      if an_ast.nil?
        DynType
      else
        ast_type = @typetable[an_ast]
        return ast_type unless ast_type.nil?

        rule = self.class.find_rule_entry(an_ast)
        t = apply_typing_rule(rule, an_ast, ast_tenv)
        @typetable[an_ast] = t
      end
    end

    # Sets the type of an AST to the given type.
    #
    # @param [ASTnode|nil]  an_ast  an AST.
    # @param [Type] a_type  a type.
    # @param [Type|nil] the given type `a_type`.
    def type_as(an_ast, a_type)
      if an_ast.nil?
        DynType
      else
        @typetable[an_ast] = a_type
      end
    end

    def type_assert(is_valid, errmsg='')
      error_found!(@current_ast, errmsg) unless is_valid
    end

    def type_assert_false(is_invalid, errmsg='')
      error_found!(@current_ast, errmsg) if is_invalid
    end

    # Later invokes proc, which performs type checking.
    # This is used for avoiding infinite regression when
    # determining the type of ASTs.
    #
    def type_assert_later(&proc)
      check_later(&proc)
    end

    def error_group
      'type'
    end
  end # of TypeChecker
end
