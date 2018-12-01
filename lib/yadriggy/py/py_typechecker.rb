# Copyright (C) 2018- Shigeru Chiba.  All rights reserved.

require 'yadriggy/py/python'

module Yadriggy
  module Py
    class PyTypeChecker < RubyTypeChecker
      def initialize()
        super(Py::Syntax)
        @free_variables = Hash.new
      end

      # @return [Hash<Object,String>] all free variables.  A hash table from
      # values to their free variable names.
      def references
        @free_variables
      end

      # Makes the references set empty.  The references set is a set of constants
      # returned by {#references}.
      #
      def clear_references
        @free_variables = Hash.new
      end

      rule(Name) do
        type = proceed(ast, type_env)
        collect_free_variables(ast, type)
        type
      end

      # Collect free variables.
      # @param [Name|VariableCall] an_ast
      def collect_free_variables(an_ast, type)
        unless InstanceType.role(type).nil?
          obj = type.object
          unless obj.is_a?(Numeric) || obj.is_a?(String) || obj.is_a?(Symbol) || obj.is_a?(Module)
            @free_variables[obj] = an_ast.name
          end
        end
      end

      # Computes the type of the {Call} expression
      # by searching the receiver class for the called method.
      # If the method is not found or the method is provided by
      # `Object` or its super class, {DynType} is returned.
      #
      # This overrides the super's method but if the called method is not
      # found, it returns DynType; it does not raise an error.
      def lookup_ruby_classes(type_env, arg_types, recv_type, method_name)
        begin
          mth = Type.get_instance_method_object(recv_type, method_name)
        rescue CheckError
          return DynType
        end
        return DynType if mth.owner > Object
        new_tenv = type_env.new_base_tenv(recv_type.exact_type)
        get_return_type(ast, mth, new_tenv, arg_types)
      end
    end # class PyTypeChecker
  end # module Py
end
