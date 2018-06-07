# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'yadriggy/c/ctype'
require 'set'

module Yadriggy
  module C

    class ArrayType < CompositeType
      attr_reader :element_type

      def initialize(element_type)
        super(Array, element_type)
      end

      def element_type()
        first_arg
      end
    end

    # Type for expressions ending with a return statement.
    #
    class WithReturnType < OptionalRole
    end

    # Type for native methods.
    #
    class NativeMethodType < OptionalRole
      # @return [String] the method body.
      attr_reader :body

      # @param [MethodType] method_type a method type.
      # @param [String] body_code the body of a native method.
      def initialize(method_type, body_code)
        super(method_type)
        @body = body_code
      end
    end

    # Type for foreign methods.
    #
    class ForeignMethodType < OptionalRole
      # @param [MethodType] method_type a method type.
      def initialize(method_type)
        super(method_type)
      end
    end

    class ClangTypeChecker < RubyTypeInferer
      include Yadriggy::C::CType

      # @return [Hash<Def,Hash<Symbol,Type>>] a map from functions to their
      #    local variables.
      attr_reader :local_vars_table

      # @return [Set<IvarObj>] accessed instance variables.
      attr_reader :instance_variables

      def initialize(syntax=nil)
        super(syntax || C::syntax)
        @local_vars_table = {}
        @instance_variables = Set.new
      end

      def valid_var_type?(t)
        if t.is_a?(Type)
          et = t.exact_type
          et == Integer || et == Float || et == String || et == Float32
        else
          false
        end
      end

      def valid_type?(t)
        valid_var_type?(t) || ArrayType.role(t)
      end

      def is_subsumed_by?(sub_type, super_type)
        (valid_var_type?(sub_type) && valid_var_type?(super_type)) ||
          sub_type <= super_type
      end

      rule(:typedecl) do
        unless ast.args.nil?
          type_assert(ast.args.size == 1, 'bad typedecl')
          type(ast.args[0])
        end
        Void
      end

      rule(:typedecl_hash) do
        ast.pairs.each do |e|
          t = typedecl_type(e[1])
          declare_type(e[0].name, e[0], t)
        end
        Void
      end

      # @private
      # @param [ASTnode] type_expr
      def typedecl_type(type_expr)
        if type_expr.is_a?(Call)
          type_assert(type_expr.args.size == 1, 'bad array type')
          etype = RubyClass[type_expr.args[0].value]
          type_assert(etype != Undef, 'cannot resolve a type name')
          type_assert(valid_var_type?(etype), "bad array type: #{etype}")
          ArrayType.new(etype)
        else
          rt = type_expr.value
          type_assert(rt != Undef, 'cannot resolve a type name')
          if rt.is_a?(Module) && rt <= FFIArray
            ArrayType.new(RubyClass[rt.element_type])
          else
            RubyClass[rt]
          end
        end
      end

      # @private
      def declare_type(name, name_ast, t)
        if name == 'return' || name == 'foreign'
          type_assert(valid_type?(t) || t == Void,
                      "bad return type: #{t.name}")
          check_duplicate(name, t)
          type_env.bind_name(name.to_sym, t)
        elsif name == 'native'
          type_assert(t.is_a?(String), 'bad native argument. not String.')
          type_assert(type_env.bound_name?(:native).nil?,
                      'duplicate declaration: native')
          type_env.bind_name(:native, InstanceType.new(t))
        else
          type_assert(valid_type?(t), "bad parameter type: #{name}")
          check_duplicate(name, t)
          bind_local_var(type_env, name_ast, t, false)
        end
      end

      # @private
      def check_duplicate(name, t)
        old_type = type_env.bound_name?(name)
        type_assert(old_type.nil? || old_type == t,
                    "incompatible or duplicate declaration: #{name}")
      end

      rule(:return_type) do
        typedecl_type(ast.expr)
      end

      rule(Number) do
        if ast.value.is_a?(Float)
          RubyClass::Float
        else
          RubyClass::Integer
        end
      end

      rule(Const) do
        t = proceed(ast)
        type_assert(t != Undef, 'unknown constant')
        type_assert(valid_var_type?(t), 'bad constant type')
        t
      end

      rule(ConstPathRef) do
        v = ast.value
        type_assert(v != Undef, 'unknown constant')
        t = InstanceType.new(v)
        type_assert(valid_var_type?(t), 'bad constant type')
        t
      end

      rule(InstanceVariable) do
        v = ast.value
        key = type_env.context
        if v == Undef
          get_instance_variable_type(key, ast, false, DynType)
        else
          type_assert(v.is_a?(IvarObj), 'badly typed instance variable')
          @instance_variables << v
          get_instance_variable_type(key, ast, true, InstanceType.new(v))
        end
      end

      rule(Assign) do
        rtype = type(ast.right)
        type_assert(valid_var_type?(rtype), 'bad assigned value')
        if ast.left.is_a?(ArrayRef)
          type(ast.left)
        else
          type_assert(ast.left.is_a?(IdentifierOrCall), 'bad assignment')
          ltype = type_env.bound_name?(ast.left)
          if ltype.nil?  # if a new name is found,
            bind_local_var(type_env, ast.left, rtype)
          else
            LocalVarType.role(ltype)&.definition = ast.left
            ltype
          end
        end
      end

      rule(Binary) do
        t1 = type(ast.left)
        t2 = type(ast.right)
        binary_cexpr_type(ast.op, t1, t2)
      end

      # @private
      def binary_cexpr_type(op, t1, t2)
        case op
        when :+, :-, :*, :/
          if t1 <= RubyClass::Float || t2 <= RubyClass::Float
            return RubyClass::Float
          elsif t1 <= Float32Type || t2 <= Float32Type
            return Float32Type
          else
            return RubyClass::Integer
          end
        when :%
          type_assert(t1 <= RubyClass::Integer &&
                      t2 <= RubyClass::Integer, 'bad operand type')
          return RubyClass::Integer
        when :<, :>, :<=, :>=, :==, :'&&', :'||'
          return RubyClass::Boolean
        else
          type_assert(false, "bad operator: #{ast.op}")
        end
      end

      rule(ArrayRef) do
        array_type = type(ast.array)
        indexes = ast.indexes
        if InstanceType.role(array_type)&.object.is_a?(IvarObj)
          sizes = array_type.object.sizes
          type_assert(indexes.size == sizes.size, 'bad array index')
          indexes.each do |idx|
            type_assert(type(idx) <= RubyClass::Integer, 'bad array index')
          end
          array_type.object.type
        else
          type_assert(indexes.size == 1, 'bad array index')
          itype = type(indexes[0])
          type_assert(itype <= RubyClass::Integer, 'bad array index')

          atype = ArrayType.role(array_type)
          type_assert_false(atype.nil?, 'bad array access')
          atype.element_type
        end
      end

      rule(Unary) do
        t = type(ast.expr)
        type_assert(ast.op == :-@, "bad operator: #{ast.op}")
        t
      end

      rule(Conditional) do
        type(ast.cond)
        t1 = type(ast.then)
        ast.all_elsif.each do |cond_then|
          type(cond_then[0])
          type(cond_then[1])
        end
        t2 = type(ast.else)
        if WithReturnType.role(t1) && WithReturnType.role(t2)
          WithReturnType.new(UnionType.make(t1, t2))
        elsif ast.op == :ifop
          UnionType.make(t1, t2)
        else
          Void
        end
      end

      rule(Loop) do
        type(ast.cond)
        type(ast.body, type_env)
        Void
      end

      rule(ForLoop) do
        ast.vars.each {|v| bind_local_var(type_env, v.name,
                                          RubyClass::Integer) }
        type_assert(type(ast.set.left) <= RubyClass::Integer, 'bad for-range')
        type_assert(type(ast.set.right) <= RubyClass::Integer, 'bad for-range')
        type(ast.body, type_env)
        Void
      end

      rule(Return) do
        t = proceed(ast)
        ret_type = type_env.bound_name?(:return)
        if ret_type == Void
          type_assert(ast.values.size == 0, 'bad return')
        else
          type_assert(is_subsumed_by?(t, ret_type), 'bad return type')
        end
        WithReturnType.new(t)
      end

      rule(Call) do
        method_name = ast.name.name
        if method_with_block?(method_name)
          type_assert(ast.block,
                      "no block given: #{method_name}")
          type_assert(ast.receiver,
                      "no receiver given: #{method_name}")
          typecheck_call_with_block(ast)
        else
          type_assert_false(ast.block,
                            "a block is not taken: #{method_name}")
          t = proceed(ast)
          type_assert(ResultType.role(t), "bad call to: #{method_name}")
          t
        end
      end

      # Specifies the names of methods with a block.
      #
      # @param [String] name  a method name.
      # @see {CodeGen#call_with_block}
      # @see {#typecheck_call_with_block}
      def method_with_block?(name)
        name == 'times'
      end

      def typecheck_call_with_block(call_ast)
        type_assert(ast.name.name == 'times',
                    "no such method: #{ast.name.name}")
        type_assert(type(ast.receiver) == RubyClass::Integer,
                    'the receiver must be an integer')
        type_assert(ast.block.params.size == 1,
                    "wrong number of block parameters")
        type_as(ast.block.params[0], RubyClass::Integer)
        tenv = type_env.new_tenv
        tenv.bind_name(ast.block.params[0], RubyClass::Integer)
        tenv.bind_name(:return, Void)
        type(ast.block, tenv)
        Void
      end

      rule(Block) do
        if ast.params.size == 0 && type_env.bound_name?(:return).nil? &&
            ast.body.is_a?(Return)
          case ast.body.values[0].usertype
          when :expr, :method_call
            type_env.bind_name(:return, type(ast.body.values[0]))
          end
        end

        # a new type environment is created by a caller
        # (i.e. typecheck_call_with_block).
        def_block_rule(true, type_env)
      end

      rule(Def) do
        def_block_rule(false, type_env.new_tenv)
      end

      private

      def def_block_rule(is_block, new_tenv)
        type_block(ast, new_tenv)

        ptypes = ast.params.map { |v| new_tenv.bound_name?(v.name) }
        ptypes.each_with_index do |t, i|
          type_assert(t, "missing parameter type: #{ast.params[i].name}")
        end
        result_t = new_tenv.bound_name?(:return)
        result_t = new_tenv.bound_name?(:foreign) if result_t.nil?
        type_assert(result_t, 'no return type specified')

        mtype = MethodType.new(ast, ptypes, result_t)
        type_env.bind_name(ast.name.name, mtype.result) unless is_block

        code = new_tenv.bound_name?(:native)
        if code
          ins_t = InstanceType.role(code)
          type_assert(ins_t, 'bad native declaration')
          return NativeMethodType.new(mtype, ins_t.object)
        end

        foreign_value = new_tenv.bound_name?(:foreign)
        if foreign_value && !is_block
          mtype2 = MethodType.new(nil, DynType, result_t)
          return ForeignMethodType.new(mtype2)
        end

        type_assert_later_unless(is_block) do
          body_t = type(ast.body, new_tenv)
          wt = WithReturnType.role(body_t)
          if result_t == Void
            type_assert(wt.nil? || body_t == Void, 'non-void return statement')
          else
            type_assert(wt, 'no return statement')
            type_assert(is_subsumed_by?(result_t, body_t), 'bad result type')
          end

          local_vars = {}
          new_tenv.each do |name, type|
            lvt = LocalVarType.role(type)
            local_vars[name] = type unless lvt.nil?
          end
          ast.params.each do |p|
            local_vars.delete(p.name.to_sym)
          end

          @local_vars_table[ast] = local_vars
        end
        mtype
      end

      def type_assert_later_unless(value, &proc)
        unless value
          check_later(&proc)
        else
          yield
        end
      end

      # Do typing the given block according to typedecl.
      #
      def type_block(block_ast, new_env)
        expr0 = nil
        expr1 = nil
        if block_ast.body.is_a?(Exprs)
          size = block_ast.body.expressions.size
          expr0 = block_ast.body.expressions[0] if size > 0
          expr1 = block_ast.body.expressions[1] if size > 1
        else
          expr0 = block_ast.body
        end

        if expr0&.usertype == :return_type
          new_env.bind_name(:return, type(expr0))
        end

        if expr0&.usertype == :typedecl
          type(expr0, new_env)
        elsif expr1&.usertype == :typedecl
          type(expr1, new_env)
        end

        unless new_env.bound_name?(:return) || new_env.bound_name?(:foreign)
          new_env.bind_name(:return, Void)
        end
      end

    end
  end
end
