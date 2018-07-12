# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'set'
require 'yadriggy/ruby_typecheck'

module Yadriggy

  # Type checker for Ruby with type inference.
  #
  class RubyTypeInferer < RubyTypeChecker

    # Binds a local variable name to a type.
    # @param [TypeEnv] env  a type environment.
    # @param [ASTnode] ast  a local variable name.
    # @param [Type] var_type  a type.
    # @param [Boolean] is_def  true if the variable is initialized there.
    def bind_local_var(env, ast, var_type, is_def=true)
      unless var_type.nil?
        t = if UnionType.role(var_type)
              ts = UnionType.role(var_type).types
              UnionType.new(ts.map {|t| to_non_instance_type(t) })
            else
              ins_t = InstanceType.role(var_type)
              to_non_instance_type(var_type)
            end
        lvt = LocalVarType.new(t.copy(OptionalRole), is_def ? ast : nil)
        env.bind_name(ast, lvt)
        @typetable[ast] = lvt
      end
    end

    # @api private
    # When the initial value of a variable is an InstanceType,
    # the type of the variable has to be a RubyCass type
    # corresponding to that instance type.
    # The variable type can be set to that InstanceType only when
    # it is guaranteed that the value of the variable is never changed
    # later.
    def to_non_instance_type(t)
      ins_t = InstanceType.role(t)
      if ins_t.nil?
        t
      else
        ins_t.supertype
      end
    end

    # Note that obj.name += ... is regarded as obj.name=(obj.name + ...).
    #
    rule(Assign) do
      rtype = type(ast.right)
      left_expr = ast.left
      if ast.op != :'='    # if op is += etc.
        ltype = type(left_expr)
        LocalVarType.role(ltype)&.definition = left_expr
        ltype
      elsif left_expr.is_a?(IdentifierOrCall)
        vtype = type_env.bound_name?(left_expr)
        if vtype.nil?  # if a new name is found,
          method_name = left_expr.name  + '='
          if is_attr_accessor?(ast, type_env, method_name.to_sym)  # self.name=()?
            call_expr = Call.make(name: method_name, args: [ ast.right ])
            get_call_expr_type(call_expr, type_env, method_name)
          else
            bind_local_var(type_env, left_expr, rtype)
          end
        else
          type_assert(rtype <= vtype, 'incompatible assignment type')
          LocalVarType.role(vtype)&.definition = left_expr
          vtype
        end
      elsif left_expr.is_a?(Call) && left_expr.op == :'.'      # obj.name=()?
        method_name = left_expr.name.name + '='
        call_expr = Call.make(receiver: left_expr.receiver,
                              name: method_name, args: [ ast.right ],
                              parent: ast.parent)
        get_call_expr_type(call_expr, type_env, method_name)
      elsif left_expr.is_a?(InstanceVariable)     # @var = ..., @@cvar = ..., @var += ...
        get_instance_variable_type(type_env.context, left_expr, true,
                                   InstanceType.role(rtype)&.supertype || rtype)
      elsif left_expr.is_a?(GlobalVariable)
        get_instance_variable_type(:global_variables, left_expr, true,
                                   InstanceType.role(rtype)&.supertype || rtype)
      else
        type(left_expr)           # a[i] = ..., <expr> = ... or <expr> += ...
      end
    end

    # @api private
    def is_attr_accessor?(expr, tenv, name)
      self_t = type_env.context
      !self_t.nil? &&
        (self_t.method_defined?(name) ||
         self_t.private_method_defined?(name))
    end

    rule(Name) do
      tenv = type_env
      name_ast = ast
      type = tenv.bound_name?(name_ast)
      if type
        type
      else
        method_name = name_ast.to_sym
        if is_attr_accessor?(name_ast, tenv, method_name.to_sym)
          call_expr = Call.make(name: method_name, parent: name_ast.parent)
          get_call_expr_type(call_expr, tenv, method_name)
        else
          # this name is a free variable.
          v = name_ast.value
          if v == Undef
            DynType
          else
            InstanceType.new(v)
          end
        end
      end
    end

    rule(Const) do
      v = ast.value
      if v == Undef
        DynType
      else
        InstanceType.new(v)
      end
    end

    rule(GlobalVariable) do
      v = ast.value
      if v == Undef
        get_instance_variable_type(:global_variables, ast, false, DynType)
      else
        get_instance_variable_type(:global_variables, ast, true, RubyClass[v.class])
      end
    end

    rule(InstanceVariable) do
      v = ast.value
      key = type_env.context
      if v == Undef
        get_instance_variable_type(key, ast, false, DynType)
      else
        get_instance_variable_type(key, ast, true, RubyClass[v.class])
      end
    end

    # Obtains the type of the given instance variable `ivar` declared
    # in the given class (i.e. module) or the instance object `key`.
    # If the type of `ivar` is not defined, `value_type` is recorded
    # as its type.
    #
    # @param [Module|Object] key  the key when looking into the typedef table.
    # @param [InstanceVariable] ivar  an instance variable.
    # @param [Boolean] is_valid_type  true if `value_type` is valid.
    # @param [Type] value_type  the type suggested for `ivar`.
    # @return [Type] the type of `ivar`.
    def get_instance_variable_type(key, ivar, is_valid_type, value_type)
      td = add_typedef(key)
      ivar_t = td[ivar]
      if ivar_t.nil?
        td[ivar] = value_type
      else
        type_assert_subsume(ivar_t, value_type,
                  "bad type value for #{ivar.name}") if is_valid_type
        ivar_t
      end
    end

    # +@, -@, !, ~, not
    rule(Unary) do
      expr_t = type(ast.operand)
      op = ast.op
      if op == :! || op == :not
        RubyClass::Boolean
      else
        if (op == :~ && expr_t <= RubyClass::Integer) ||
            ((op == :+@ || op == :-@) && expr_t <= RubyClass::Numeric)
          expr_t
        else
          call_expr = Call.make(receiver: ast.operand, name: op,
                                parent: ast.parent)
          get_call_expr_type(call_expr, type_env, op)
        end
      end
    end

    rule(Binary) do
      right_t = type(ast.right)
      left_t = type(ast.left)
      binary_type(ast, right_t, left_t)
    end

    # @api private
    def binary_type(bin_expr, right_t, left_t)
      op = bin_expr.op
      case op
      when :'&&', :'||', :and, :or	# not overridable
        return UnionType.new([right_t, left_t])
      when :>, :>=, :<, :<=, :==, :===, :!=
        if left_t <= RubyClass::Numeric
          return RubyClass::Boolean
        end
      when :**, :*, :/, :%, :+, :-
        if left_t <= RubyClass::Numeric
          if left_t <= RubyClass::Float || right_t <= RubyClass::Float
            return RubyClass::Float
          else
            return RubyClass::Integer
          end
        end
      when :<<, :>>, :&, :|, :^
        return RubyClass::Integer if left_t <= RubyClass::Integer
      # when :=~, :!~, :<=>
      end

      if left_t <= RubyClass::String
        if op == :% || op == :+ || op == :<<
          return RubyClass::String
        elsif op == :=~ || op == :<=>
          return UnionType.new(RubyClass::Integer, RubyClass::NilClass)
        elsif op == :!~
          return RubyClass::Boolean
        end
      end

      call_expr = Call.make(receiver: bin_expr.left, name: op,
                            args: [bin_expr.right], parent: bin_expr.parent)
      return get_call_expr_type(call_expr, type_env, op)
    end

    rule(Dots) do
      CompositeType.new(RubyClass::Range, type(ast.left))
    end

    rule(ArrayLiteral) do
      ele = ast.elements
      if 0 < ele.size && ele.size < 17
        t = type(ele[0])
        et = InstanceType.role(t)&.supertype || t
        if ele.all? {|e| type(e) <= et }
          CompositeType.new(RubyClass::Array, et)
        else
          RubyClass::Array
        end
      else
        RubyClass::Array
      end
    end

    # Variable access or a method call without arguments.
    # This implementation invokes the method if the expression is
    # a method call.  It returns a InstanceType containing the
    # resulting value.
    #
    rule(VariableCall) do
      type = type_env.bound_name?(ast)
      if type
        type
      else
        call_expr = Call.make(name: ast.name, parent: ast.parent)
        get_call_expr_type(call_expr, type_env, call_expr.name.to_sym)
      end
    end

    # @api private
    # Overrides {RubyTypeChecker#get_return_type}.
    #
    def get_return_type(an_ast, mthd, new_tenv, arg_types)
      m_ast = an_ast.root.reify(mthd)
      type_assert_false(m_ast.nil?, "no source code: for #{mthd}")
      (@syntax.check(m_ast.tree) || @syntax.raise_error) if @syntax

      m_ast.tree.params.each_with_index do |p, i|
        bind_local_var(new_tenv, p, arg_types[i])
      end

      nparams = m_ast.tree.params.length
      m_ast.tree.optionals.each_with_index do |p, i|
        bind_local_var(new_tenv, p, arg_types[nparams + i])
      end

      mtype = MethodType.role(type(m_ast.tree, new_tenv))
      type_assert(mtype, 'not a method type')
      type_assert_params(mtype.params, arg_types, 'argument type mismatch')
      mtype.result
    end

    rule(ArrayRef) do
      array_t = CompositeType.role(type(ast.array))
      if array_t&.ruby_class == Array
        array_t.first_arg
      else
        DynType
      end
    end

    rule(ForLoop) do
      set_type = type(ast.set)
      var_type = CompositeType.role(set_type)&.first_arg
      ast.vars.each do |v|
        bind_local_var(type_env, v, var_type.nil? ? DynType : var_type)
      end
      type(ast.body)
      DynType
    end

    rule(Def) do
      ptypes = ast.params.map do |v|
        t = type_env.bound_name?(v.name)
        t || DynType
      end

      ptypes = ptypes + ast.optionals.map do |v|
        t = type_env.bound_name?(v[0].name)
        t || type(v[1])
      end

      mtype = MethodType.new(ast, ptypes, DynType)
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
      mtype
    end

  end
end
