# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'yadriggy/typecheck'

module Yadriggy
  # Type checker for Ruby.
  # Most values are typed as DynType but local variables
  # are identified.  So `type(ast)` returns
  # a {LocalVarType} object if `ast` is of a local variable.
  # A {LocalVarType} is a {Type} object that represents not
  # only the value's type but also the fact that the value
  # comes from a local variable.
  #
  # The type of a free variable is the type of the current value
  # of that variable.  {#type} returns an {InstanceType} object.
  #
  # This checker also attempts to recursivly trace a call-graph
  # to reify and type-check the ASTs of the called methods.
  #
  class RubyTypeChecker < TypeChecker
    def initialize(syntax=nil)
      super()
      @syntax = syntax
    end

    # Typing rules
    #
    # Every rule returns a Ruby class or a Type object.
    # When the given AST is a free variable, the type checker captures
    # the current value of that variable and gives the value type to that AST.

    rule(Assign) do
      rtype = type(ast.right)
      ltype = type(ast.left)
      if ast.op != :'='   # if op is += etc.
        LocalVarType.role(ltype)&.definition = ast.left
      elsif ast.left.is_a?(IdentifierOrCall)
        vtype = type_env.bound_name?(ast.left)
        if vtype.nil?
          bind_local_var(type_env, ast.left, DynType)
        else
          LocalVarType.role(vtype)&.definition = ast.left
        end
      end
      DynType
    end

    rule(Name) do
      get_name_type(ast, type_env)
    end

    # Gets the type of a given name, which may be a local variable
    # or a free variable.
    #
    # @param [Name] name_ast    an AST.
    # @param [TypeEnv] tenv     a type environment.
    def get_name_type(name_ast, tenv)
      type = tenv.bound_name?(name_ast)
      if type
        type
      else
        v = name_ast.value
        if v == Undef
          DynType
        else
          InstanceType.new(v)
        end
      end
    end

    rule(Number) do
      v = ast.value
      if v == Undef
        RubyClass::Numeric
      else
        InstanceType.new(v)
      end
    end

    rule(Reserved) do
      case ast.name.to_sym
      when :true
        RubyClass::TrueClass
      when :false
        RubyClass::FalseClass
      when :nil
        RubyClass::NilClass
      else
        DynType
      end
    end

    rule(Super) do
      if type_env.context.nil?
        DynType
      else
        RubyClass[type_env.context.superclass]
      end
    end

    rule(SymbolLiteral) do
      RubyClass::Symbol
    end

    rule(Unary) do
      type(ast.operand)
      DynType
    end

    rule(Binary) do
      type(ast.right)
      type(ast.left)
      DynType
    end

    rule(Dots) do
      RubyClass::Range
    end

    rule(StringInterpolation) do
      RubyClass::String
    end

    rule(StringLiteral) do
      RubyClass::String
    end

    rule(ConstPathRef) do
      klass = ast.value
      if klass.is_a?(Module)
        RubyClass[klass]
      else
        DynType
      end
    end

    rule(ArrayLiteral) do
      RubyClass::Array
    end

    rule(Paren) do
      type(ast.expression)
    end

    rule(HashLiteral) do
      RubyClass::Hash
    end

    # Variable access or a method call without arguments.
    #
    rule(VariableCall) do
      type = type_env.bound_name?(ast)
      if type
        type
      else
        get_call_expr_type(Call.make(name: ast.name, parent: ast.parent),
                           type_env, ast.name)
        # This implementation invokes the method if the expression is
        # a method call.  It returns an {InstanceType} containing the
        # resulting value.
        #
        #v = ast.do_invocation
        #if v == Undef
        #  error_found!(ast, "no such variable or method: #{ast.name}")
        #else
        #  InstanceType.new(v)
        #end
      end
    end

    # This rule can be overridden to delimit reification.  This
    # implementation in RubyTypeChecker does not delimit.  It
    # attempts to reify all methods invoked by the Call node.
    # Another approach to delimit reification is to override
    # get_return_type().
    #
    rule(Call) do
      method_name = ast.name.to_sym
      if method_name == :lambda
        RubyClass::Proc
      elsif method_name == :raise
        RubyClass::Exception
      else
        get_call_expr_type(ast, type_env, method_name)
      end
    end

    rule(ArrayRef) do
      DynType
    end

    rule(Conditional) do
      all_types = []
      type(ast.cond)
      all_types << type(ast.then)
      ast.all_elsif.each do |cond_then|
        type(cond_then[0])
        all_types << type(cond_then[1])
      end
      all_types << type(ast.else)
      UnionType.make(all_types)
    end

    rule(Loop) do
      type(ast.cond)
      type(ast.body)
      DynType
    end

    rule(ForLoop) do
      ast.vars.each {|v| bind_local_var(type_env, v, DynType) }
      type(ast.body)
      DynType
    end

    rule(Return) do
      vs = ast.values
      if vs.size == 1
        type(vs[0])
      elsif vs.size > 1
        vs.map {|v| type(v) }
        RubyClass::Array
      else
        Void
      end
    end

    rule(Break) do
      vs = ast.values
      if vs.size == 1
        type(vs[0])
      elsif vs.size > 1
        vs.map {|v| type(v) }
        RubyClass::Array
      else
        Void
      end
    end

    rule(Block) do
      s = type_env.new_tenv
      type_parameters(ast, s)
      MethodType.new(ast, DynType, type(ast.body, s))
    end

    rule(Exprs) do
      ast.expressions.reduce(DynType) {|t, e| type(e) }
    end

    rule(Rescue) do
      s = type_env.new_tenv
      ts = ast.types
      unless ast.parameter.nil?
        # unify all the exception types into one union type.
        etype = if ts.empty?
                  DynType
                else
                  rts = ts.map do |e|
                    clazz = e.value
                    type_assert(clazz.is_a?(Class), 'bad exception type')
                    RubyClass[clazz]
                  end
                  UnionType.make(rts)
                end
        bind_local_var(s, ast.parameter, etype)
      end

      all_types = []
      all_types << type(ast.body, s)
      all_types << type(ast.nested_rescue) unless ast.nested_rescue.nil?
      all_types << type(ast.else) unless ast.else.nil?
      type(ast.ensure)
      UnionType.make(all_types)
    end

    rule(BeginEnd) do
      body_t = type(ast.body)
      if ast.rescue.nil?
        body_t
      else
        UnionType.make(body_t, type(ast.rescue))
      end
    end

    rule(Def) do
      mtype = MethodType.new(ast, DynType, DynType)
      type_assert_later do
        s = type_env.new_tenv
        type_parameters(ast, s) # ignore parameter types
        body_t = type(ast.body, s)
        res_t = if ast.rescue.nil?
                  body_t
                else
                  UnionType.make(body_t, type(ast.rescue, s))
                end
        type_assert_subsume(mtype.result, res_t, 'bad result type')
      end
      bind_local_var(type_env, ast.name, mtype)
      mtype
    end

    rule(ModuleDef) do
      s = type_env.new_tenv
      type(ast.body, s)
      type(ast.rescue, s) unless ast.rescue.nil?
    end

    rule(ClassDef) do
      s = type_env.new_tenv
      type(ast.body, s)
      type(ast.rescue, s) unless ast.rescue.nil?
    end

    rule(SingularClassDef) do
      s = type_env.new_tenv
      type(ast.body, s)
      type(ast.rescue, s) unless ast.rescue.nil?
    end

    # Helper methods for rules
    # They can be overridden.

    def bind_local_var(env, ast, var_type)
      unless var_type.nil?
        env.bind_name(ast, LocalVarType.new(var_type.copy(OptionalRole), ast))
        @typetable[ast] = var_type
      end
    end

    def type_assert_params(params, args, errmsg='')
      unless params == DynType
        type_assert(params.is_a?(Array), errmsg)
        type_assert(args.is_a?(Array), errmsg)
        type_assert(params.length <= args.length, errmsg)  # ignore keyword params
        params.each_with_index do |p, i|
          type_assert_subsume(p, args[i], errmsg)
        end
      end
    end

    def type_assert_subsume(expected_type, actual_type, errmsg='')
      type_assert(actual_type <= expected_type, errmsg)
    end

    def type_parameters(an_ast, tenv)
      an_ast.params.each {|v| bind_local_var(tenv, v, DynType) }
      an_ast.optionals.each {|v| bind_local_var(tenv, v[0], DynType) }
      bind_local_var(tenv, an_ast.rest_of_params,
                     DynType) unless an_ast.rest_of_params.nil?
      an_ast.keywords.each {|v| bind_local_var(tenv, v, DynType) }
      bind_local_var(tenv, an_ast.rest_of_keywords,
                     DynType) unless an_ast.rest_of_keywords.nil?
      bind_local_var(tenv, an_ast.block_param,
                     DynType) unless an_ast.block_param.nil?
    end

    # Computes the type of {Call} expression.
    # If it finds `method_name` in `type_env`, it returns its type
    # recorded in `type_env`.
    #
    # @param [Call] call_ast  an AST.
    # @param [TypeEnv] type_env  a type environment.
    # @param [String|Symbol] method_name  a method name.
    # @return [ResultType] the type of the resulting value.
    def get_call_expr_type(call_ast, type_env, method_name)
      arg_types = call_ast.args.map {|t| type(t) }
      type(call_ast.block_arg)
      type(call_ast.block)

      if call_ast.receiver.nil?
        found_t = type_env.bound_name?(method_name)
        unless found_t.nil?
          recv_type = DynType
        else
          recv_obj = call_ast.get_receiver_object
          recv_type = if recv_obj.nil?
                        if type_env.context.nil?
                          DynType
                        else
                          RubyClass[type_env.context]    # self's type
                        end
                      else
                        InstanceType.new(recv_obj)
                      end
        end
      else
        found_t = nil
        recv_type = type(call_ast.receiver)
      end

      if !found_t.nil?
        found_t
      elsif DynType == recv_type || DynType == recv_type.exact_type
        DynType
      else
        lookup_builtin(recv_type, method_name) ||
        lookup_ruby_classes(type_env, arg_types, recv_type, method_name)
      end
    end

    # @api private
    # Attempts to find a method by {TypeChecker#typedef}, which
    # searches the method table in this typechecker.
    #
    def lookup_builtin(recv_type, method_name)
      et = recv_type.exact_type
      if DynType == et
        nil
      else
        mt = typedef(et)&.[](method_name)
        if mt.nil?
          nil
        else
          MethodType.role(mt)&.result
        end
      end
    end

    # @api private
    def lookup_ruby_classes(type_env, arg_types, recv_type, method_name)
      begin
        mth = Type.get_instance_method_object(recv_type, method_name)
      rescue CheckError => evar
        error_found!(ast, evar.message)
      end
      new_tenv = type_env.new_base_tenv(recv_type.exact_type)
      get_return_type(ast, mth, new_tenv, arg_types)
    end

    # Type-checks whether the argument types match parameter types.
    # It returns a {ResultType}.
    #
    # Override this method to delimit reification.  The implementation
    # in this class reifies any method.  If its source code is not found,
    # {#get_return_type} reports an error.
    #
    # This method {#get_return_type} does not have to
    # return a ResultType, which can be used in a later phase to
    # obtain the invoked method.
    # This method is invoked by rule(Call).  See rule(Call) for more details.
    #
    # @param [Call] an_ast  the Call node.
    # @param [Proc|Method|UnboundMethod] mthd  the method invoked by an_ast.
    #   if `mthd` is nil, {#get_return_type} reports an error.
    # @param [TypeEnv] new_tenv  a type environment.
    # @param [Array<Type>] arg_types  the types of the actual arguments.
    # @return [ResultType] the result type.
    def get_return_type(an_ast, mthd, new_tenv, arg_types)
      m_ast = an_ast.root.reify(mthd)
      type_assert_false(m_ast.nil?, "no source code: for #{mthd}")
      (@syntax.check(m_ast.tree) || @syntax.raise_error) if @syntax
      mtype = MethodType.role(type(m_ast.tree, new_tenv))
      type_assert(mtype, 'not a method type')
      type_assert_params(mtype.params, arg_types, 'argument type mismatch')
      mtype.result
    end
  end # of RubyTypeChecker
end
