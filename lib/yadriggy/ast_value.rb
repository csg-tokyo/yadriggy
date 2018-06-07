# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

module Yadriggy
  # Undefined value.
  Undef = :undef

  class ASTnode
    # The value of the name represented by this AST node
    # if the value is immutable.  Otherwise, {Yadriggy::Undef}.
    #
    def const_value() Undef end

    # The immutable value of the name represented by this AST node
    # when it is evaluated in the context of `clazz`.
    # If the value is mutable, {Yadriggy::Undef}.
    #
    # @param [Module] clazz  the context.
    def const_value_in_class(clazz) const_value end

    # The runtime value of the variable, method name, etc.
    # represented by this AST node.
    # The default behavior returns {Yadriggy::Undef}.
    # Subclasses override this method.
    #
    def value() Undef end

    # The runtime value of this AST node
    # when it is evaluated in the context of `clazz`.
    #
    # @param [Module] clazz  the context.
    def value_in_class(clazz) value end

    # Gets the class including this AST node.
    # @return [Module] the context.
    def get_context_class
      c = root.context
      if c.is_a?(Proc)
        c.binding.receiver.class
      else # c is Method or UnboundMethod
        c.owner
      end
    end

    # Gets the receiver object.
    # @return [Object] the receiver object that this proc or method
    #   is bound to.
    def get_receiver_object
      c = root.context
      if c.is_a?(Proc)
        c.binding.receiver
      elsif c.is_a?(Method)
        c.receiver
      else
        nil
      end
    end

    # Checks whether the object is a `Proc` or a method.
    # @param [Object] p  the tested object.
    # @return [Booelan] true if `p` is a `Proc`, `Method`, or lambda object.
    def is_proc?(p)
      p.is_a?(Proc) || p.is_a?(Method)
    end
  end

  class Identifier
    def value()
      c = root.context
      if c.is_a?(Proc)
        if c.binding.local_variable_defined?(name)
          c.binding.local_variable_get(name)
        else
          Undef
        end
      else # c is Method or UnboundMethod
        Undef
      end
    end
  end

  class VariableCall
    # Gets an ASTree object representing the method body
    # invoked by this AST node.
    # Undef may be returned if the method is not found.
    #
    def value()
      mth = invoked_method
      if mth == Undef
        Undef
      else
        root.reify(mth) || Undef
      end
    end

    # Returns Undef because const_value is supposed to return
    # the resulting value of executing this variable call.
    #
    def const_value() Undef end

    # Gets a Method object called by this AST node.
    # If this AST node belongs to UnboundMethod,
    # Undef will be returned.
    #
    def invoked_method()
      obj = get_receiver_object
      if obj.nil?
        Undef
      else
        begin
          obj.method(@name)
        rescue NameError
          Undef
        end
      end
    end

    # Gets the resulting value of the invocation of this method.
    #
    def do_invocation()
      obj = get_receiver_object
      if obj.nil?
        Undef
      else
        begin
          obj.send(@name)
        rescue NameError
          Undef
        end
      end
    end
  end

  class Label
    # Gets the name of this label.
    #
    def value() @name end

    # Gets the name of this label.
    #
    def const_value() @name end
  end

  class Const
    def value()
      value_in_class(get_context_class)
    end

    def const_value() value end

    def value_in_class(clazz)
      if clazz.const_defined?(@name)
        clazz.const_get(@name)
      else
        Undef
      end
    end

    def const_value_in_class(clazz)
      value_in_class(clazz)
    end
  end

  class Reserved
    # Gets self, true, or false.  Otherwise, Undef.
    #
    def value()
      if @name == 'self'
        get_receiver_object || Undef
      elsif @name == 'true'
        true
      elsif @name == 'false'
        false
      else
        Undef
      end
    end

    def const_value() value end
  end

  class GlobalVariable
    # The current value of this global variable.
    #
    def value()
      eval(@name)
    end
  end

  class InstanceVariable
    def value()
      if name.start_with?("@@")
        clazz = get_context_class
        if clazz.class_variable_defined?(name)
          return clazz.class_variable_get(name)
        end
      elsif name.start_with?("@")
        obj = get_receiver_object
        if obj&.instance_variable_defined?(name)
          return obj.instance_variable_get(name)
        end
      end

      Undef
    end

    def value_in_class(clazz)
      if name.start_with?("@@")
        if clazz.class_variable_defined?(name)
          return clazz.class_variable_get(name)
        else
          Undef
        end
      else
        value
      end
    end

    def const_value()
      if name.start_with?("@@")
        clazz = get_context_class
        if clazz.frozen? && clazz.class_variable_defined?(name)
          return clazz.class_variable_get(name)
        end
      elsif name.start_with?("@")
        obj = get_receiver_object
        if obj.frozen? && obj&.instance_variable_defined?(name)
          return obj.instance_variable_get(name)
        end
      end

      Undef
    end
  end

  class Super
    # Gets an ASTree object representing the method body
    # invoked by this call to super.
    # Undef may be returned if the method is not found.
    #
    def value()
      mth = invoked_method
      if mth == Undef
        Undef
      else
        root.reify(mth) || Undef
      end
    end

    # Gets the super method (Method or UnboundMethod object) or nil.
    # If this AST node is not a part of method body,
    # Undef is returned.
    #
    def invoked_method()
      mthd = root.context
      if mthd.is_a?(Method) || mthd.is_a?(UnboundMethod)
        mthd.super_method
      else
        Undef
      end
    end
  end

  class Number
    # This is defined by attr_reader.
    # def value() @value end

    def const_value() value end
  end

  class ArrayLiteral
    def value()
      elements.map {|e| e.value }
    end

    def value_in_class(klass)
      elements.map {|e| e.value_in_class(klass) }
    end

    def const_value()
      elements.map {|e| e.const_value }
    end
  end

  class StringLiteral
    # This is defined by attr_reader.
    # def value() @value end

    def const_value() value end
  end

  class SymbolLiteral
    # Gets the symbol represented by this node.
    def value()
      name.to_sym
    end

    def const_value() value end
  end

  class ConstPathRef
    def value()
      value_in_class(get_context_class)
    end

    def value_in_class(klass)
      if scope.nil?
        clazz = Object
      else
        clazz = scope.value_in_class(klass)
        return Undef if clazz == Undef
      end

      unless clazz.is_a?(Module)
        raise "unknown scope #{scope.class.name} #{clazz&.to_s || 'nil'}"
      end

      name.value_in_class(clazz)
    end

    def const_value() value end

    def const_value_in_class(clazz)
      value_in_class(clazz)
    end
  end

  class Unary
    def value()
      send_op_to_value(@expr.value)
    end

    def value_in_class(klass)
      send_op_to_value(@expr.value_in_class(klass))
    end

    def const_value()
      send_op_to_value(@expr.const_value)
    end

    def const_value_in_class(klass)
      send_op_to_value(@expr.const_value_in_class(klass))
    end

    private
    def send_op_to_value(v)
      if v == Undef || is_proc?(v) || !v.class.public_method_defined?(@op)
        Undef
      else
        v.send(@op)
      end
    end
  end

  class Binary
    def value()
      send_op_to_value(@left.value, @right.value)
    end

    def value_in_class(klass)
      send_op_to_value(@expr.value_in_class(klass),
                       @right.value_in_class(klass))
    end

    def const_value()
      send_op_to_value(@left.const_value, @right.const_value)
    end

    def const_value_in_class(klass)
      send_op_to_value(@expr.const_value_in_class(klass),
                       @right.const_value_in_class(klass))
    end

    private
    def send_op_to_value(v, w)
      if v == Undef || w == Undef || is_proc?(v) || is_proc?(w) ||
          !v.class.public_method_defined?(@op)
        Undef
      else
        v.send(@op, w)
      end
    end
  end

  class Assign
    def value() Undef end

    def value_in_class(klass) Undef end

    def const_value() Undef end

    def const_value_in_class(klass) Undef end
  end

  class Call
    # Gets the invoked method or Undef.
    #
    def value()
      if @receiver.nil?
        lookup_method(get_receiver_object)
      else
        lookup_method(@receiver.value)
      end
    end

    def value_in_class(klass)
      if @receiver.nil?
        lookup_method(get_receiver_object)
      else
        lookup_method(@receiver.value_in_class(klass))
      end
    end

    private
    def lookup_method(obj)
      if obj.nil? || obj == Undef
        Undef
      else
        begin
          obj.method(@name.name)
        rescue NameError
          Undef
        end
      end
    end

  end
end

