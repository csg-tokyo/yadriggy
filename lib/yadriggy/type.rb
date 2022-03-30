# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

module Yadriggy
  # @abstract
  # Root of the classes representing a type.
  # A {Type} object may consist of a chain of multiple {Type} objects.
  #
  # Don't use `is_a?` but use `has_role?` or `role`.
  #
  class Type
    # @api private
    def self.get_instance_method_object(recv_type, method_name)
      recv_type.get_method_object(method_name)
    end

    # Raises an error.
    # @param [String] msg  an error message.
    def self.error_found!(msg)
      raise TypeChecker::CheckError.new(msg)
    end

    # Obtains the name of this type.
    # @return [String] the type name.
    def name()
      to_s
    end

    # Makes a copy of self.  Note that a {Type} object may consist of
    # a chain of multiple {Type} objects.  The copied chain does not
    # contain an instance of `without_role`.
    #
    # @param [Class] without_role    a subclass of {OptionalRole}.
    # @return [Type] the copy.
    def copy(without_role)
      self
    end

    # Check the inequality.
    # @return [Boolean] false if `self` and `t` represent the same type.
    def != (t)
      !(self == t)
    end

    # An alias to `==`.
    # @return [Boolean] true if `self` and `t` represent the same type.
    def eql?(t)
      self == t
    end

    # Check the subtype relation.
    # @param [Type] t  the other type.
    # @return [Boolean] true if `self` is equivalent to `t` or a subtpye of `t`
    def <= (t)
      self == t
    end

    # @api private
    # Only {DynType}, {UnionType} and {OptionalRole} override this method.
    def is_super_of? (t)
      false
    end

    # Finds an instance of the receiver class in the chain starting with
    # the given {Type} object.
    # If such an instance is not found, the method returns nil.
    # Also see {OptionalRole}.
    #
    # @param [Type] type  a Type object.
    # @return [Type|nil] an instance of the receiver class.
    def self.role(type)
      if type.is_a?(Type)
        type.has_role?(self)
      else
        nil
      end
    end

    # Finds an instance of the receiver class in the chain starting
    # with `self`.
    # If such an instance is not found, the method returns `nil`.
    # Also see {OptionalRole}.
    #
    # @param [Module] a_role  a subclass of Type.
    # @return [Type|nil] an instance of `a_role`.
    def has_role?(a_role)
      if self.is_a?(a_role)
        self
      else
        nil
      end
    end

    # Gets the Ruby class represented by this Type.
    # @return [Module|DynType] the corresponding Ruby class or {DynType}.
    def exact_type
      DynType
    end

    # @api private
    # Gets a method with the given name declared in this type.
    # `nil` is returned when the method is not exactly determined.
    #
    # @return [Method|nil]
    def get_method_object(method_name)
      nil
    end

    # @return [Type] the type containing a wider range of values.
    def supertype
      nil
    end
  end

  # @api private
  class NonRubyType < Type
    def initialize(obj_name, type_name)
      @obj_name = obj_name
      @type_name = type_name
    end

    # Obtains the name of this type.
    # @return [String] the type name.
    def name
      @type_name
    end

    # Checks the equality.
    # @param [Type] t  the other type.
    # @return [Boolean] true if `self` and `t` represent the same type.
    def == (t)
      r = NonRubyType.role(t)
      self.equal?(r)
    end

    # Check the subtype relation.
    # @param [Type] t  the other type.
    # @return [Boolean] true if `self` is equivalent to `t`.
    def <= (t)
      self == t || t.is_super_of?(self)
    end

    def role(t)
      r = NonRubyType.role(t)
      self.equal?(r) ? self : nil
    end

    def inspect()
      @obj_name
    end
  end

  # Dynamic type.
  DynType = NonRubyType.new('#<Yadriggy::DynType>', 'DynType')

  # @api private
  def DynType.is_super_of?(t)
    true
  end

  # Void type.
  Void = NonRubyType.new('#<Yadriggy::Void>', 'Void')

  # Union type.  A value of this type is a value of one of
  # the given types.
  class UnionType < Type
    # @return [Array<Type>] the given types.
    attr_reader :types

    # Makes an instance of {UnionType}
    # @param [Array<Type>] ts  the types included in the union type.
    # @return [UnionType|DynType] the instance.
    def self.make(*ts)
      fts = ts.flatten
      fts.each do |e|
        return DynType if DynType == e
      end

      t = UnionType.new(fts)
      if t.types.size == 1
        t.types[0]
      else
        t
      end
    end

    # @param [Array<Type>] ts  the types included in the union type.
    def initialize(*ts)
      @types = ts.flatten.map {|e| UnionType.role(e)&.types || e }.flatten.uniq
    end

    # Checks equality.
    # Ignores {OptionalRole} when comparing two {UnionType}s.
    # @param [Type] t  the other type.
    # @return [Boolean] true if `self` is equivalent to `t`.
    def == (t)
      ut = UnionType.role(t)
      !ut.nil? && @types.size == ut.types.size &&
        (normalize(self) | normalize(ut)).size <= @types.size
    end

    # @api private
    def normalize(utype)
      utype.types.map {|e| e.copy(OptionalRole) }
    end

    # @api private
    def hash
      @types.hash
    end

    # @api private
    # Check the subtype relation.
    # @param [Type] t  the other type.
    # @return [Boolean] true if `self` is equivalent to `t`
    #                   or a subtype of `t`.
    def <= (t)
      DynType == t || @types.all? {|e| e <= t }
    end

    # @param [Type] t  a type.
    # @return [Boolean] true if `self` is a super type of `t`.
    def is_super_of?(t)
      @types.any? {|e| t <= e }
    end

    # Obtains the name of this type.
    # @return [String] the type name.
    def name
      name = '(' << @types.map{|e| e.name }.join('|') << ')'
      name
    end
  end

  # The most specific common super type.
  # A value of this type is either an instance of `self.type`
  # or a subclass of `self.type`.
  #
  class CommonSuperType < Type
    # @return [Module] the common super type.
    attr_reader :type

    # @param [Module] t  the type.
    def initialize(t)
      @type = t
    end

    # @api private
    def == (t)
      CommonSuperType.role(t)&.type == @type
    end

    # @api private
    def hash
      @type.hash + 1
    end

    # @api private
    # Check the subtype relation.
    # @param [Type] t  the other type.
    # @return [Boolean] true if `self` is equivalent to `t`
    # or a subtype of `t`.
    def <= (t)
      if t.is_super_of?(self)
        true
      else
        ct = CommonSuperType.role(t)
        !ct.nil? && (@type <= ct.type || @type == NilClass)
      end
    end

    # @api private
    def get_method_object(method_name)
      nil
    end

    # @return [CommonSuperType|nil] the {CommonSuperType} for the super class.
    def supertype
      if @type.is_a?(Class) && !@type.superclass.nil?
        CommonSuperType.new(@type.superclass)
      else
        nil
      end
    end

    # Obtains the name of this type.
    # @return [String] the type name.
    def name
      @type.name + '+'
    end
  end

  # Type of immediate instances of a Ruby class.
  # The instances of its subclass are excluded.
  # A class type including its subclasses is represented
  # by {CommonSuperType}.
  #
  class RubyClass < Type
    # @api private
    Table = {}

    # @api private
    def self.make(clazz)
      obj = RubyClass.new(clazz)
      Table[clazz] = obj
      obj
    end

    # @api private
    def self.set_alias(clazz, ruby_class)
      Table[clazz] = ruby_class
    end

    # @param [Module|Object] clazz  a Ruby class or module.
    # @return [RubyClass|Object] a {RubyClass} object for `clazz`
    #   if `clazz` is an instance of `Module`.  Otherwise, `clazz`
    #   is returned.  For example, `RubyClass[Void]` returns `Void`.
    def self.[](clazz)
      Table[clazz] || (clazz.is_a?(::Module) ? RubyClass.new(clazz) : clazz)
    end

    # @param [Module] clazz  the Ruby class or module.
    def initialize(clazz)
      @ruby_class = clazz
    end

    # Checks the equality.
    # @param [Type|Module] t  the other object.
    # @return [Boolean] true if `self` and `t` represent the same Ruby class.
    def == (t)
      RubyClass.role(t)&.exact_type == @ruby_class
    end

    # @api private
    def hash
      @ruby_class.hash
    end

    # @api private
    # Check the subtype relation.
    # @param [Type] t  the other type.
    # @return [Boolean] true if `self` is equivalent to `t`
    #   or a subtype of `t`.
    def <= (t)
      if t.is_super_of?(self)
        true
      else
        rc = RubyClass.role(t)
        if rc.nil?
          CommonSuperType.new(@ruby_class) <= t
        else
          rc.exact_type == @ruby_class || @ruby_class == ::NilClass
        end
      end
    end

    # @api private
    def get_method_object(method_name)
      @ruby_class.instance_method(method_name)
    rescue NameError
      Type.error_found!("no such method: #{@ruby_class}\##{method_name}")
    end

    # @api private
    def exact_type
      @ruby_class
    end

    # @return [CommonSuperType] the {CommonSuperType} for this class.
    def supertype
      CommonSuperType.new(@ruby_class)
    end

    # Obtains the name of this type.
    # @return [String] the type name.
    def name
      @ruby_class.name
    end
  end

  RubyClass::Symbol = RubyClass.make(Symbol)
  RubyClass::String = RubyClass.make(String)
  RubyClass::Integer = RubyClass.make(Integer)
  RubyClass::Float = RubyClass.make(Float)
  RubyClass::Rational = RubyClass.make(Rational)
  RubyClass::Complex = RubyClass.make(Complex)
  RubyClass::Range = RubyClass.make(Range)
  RubyClass::Hash = RubyClass.make(Hash)
  RubyClass::Array = RubyClass.make(Array)
  RubyClass::Proc = RubyClass.make(Proc)
  RubyClass::Exception = RubyClass.make(Exception)
  RubyClass::TrueClass = RubyClass.make(TrueClass)
  RubyClass::FalseClass = RubyClass.make(FalseClass)

  # Fixnum is a subclass of Integer in Ruby earlier than 2.4.
  if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.4')
    RubyClass.set_alias(Fixnum, RubyClass::Integer)
  end

  # The type for `nil`.  Although ::NilClass is not a subtype of
  # other classes, RubyClass::NilClass is a subtype of {RubyClass::String},
  # etc.
  RubyClass::NilClass = RubyClass.make(NilClass)

  # An instance of {UnionType}.  It represents either `TrueClass` or
  # `FalseClass`.
  RubyClass::Boolean = UnionType.new([RubyClass::TrueClass,
                                       RubyClass::FalseClass])

  # An instance of {CommonSuperType}.  It represents `::Numeric` class.
  RubyClass::Numeric = CommonSuperType.new(Numeric)

  # Type of a particular Ruby object.
  #
  class InstanceType < Type
    # @return [Object]  the Ruby object.
    attr_reader :object

    def initialize(obj)
      @object = obj
    end

    # @api private
    def == (t)
      InstanceType.role(t)&.object == @object
    end

    # @api private
    def hash
      @object.hash
    end

    # @api private
    # Check the subtype relation.
    # @param [Type] t  the other type.
    # @return [Boolean] true if `self` is equivalent to `t`
    #                   or a subtype of `t`.
    def <= (t)
      if t.is_super_of?(self)
        true
      else
        it = InstanceType.role(t)
        (!it.nil? && it.object == @object) ||
          RubyClass[exact_type] <= t
      end
    end

    # @api private
    # Recall that `1.class` was `Fixnum` in Ruby earlier than 2.4.
    def exact_type
      @object.is_a?(Integer) ? Integer : @object.class
    end

    # @api private
    def get_method_object(method_name)
      @object.method(method_name)
    rescue NameError
      Type.error_found!("no such method: #{@object.class}\##{method_name}")
    end

    # @return [RubyClass] the {RubyClass} for this class.
    def supertype
      RubyClass[exact_type]
    end

    # Obtains the name of this type.
    # @return [String] the type name.
    def name
      @object.to_s
    end
  end

  # Type of methods.
  #
  class MethodType < Type
    # @param [Parameters|nil] method_def  method definition.
    # @param [Array<Type|Module>|DynType] param_type_array  parameter types.
    #    `param_type_array` can be {DynType}.
    # @param [Type|Module|DynType] result_type  the result type.
    def initialize(method_def=nil, param_type_array, result_type)
      @param_types = if param_type_array.is_a?(Array)
                       param_type_array.map do |t|
                         t.is_a?(Type) ? t : RubyClass[t]
                       end
                     else
                       param_type_array
                     end
      @result_type = if result_type.is_a?(Type)
                       result_type
                     else
                       RubyClass[result_type]
                     end
      @method_def = method_def
    end

    # Gets an array of the parameter types.
    # @return [Array<Type>|DynType]  the parameter types.
    def params() @param_types end

    # @return [Type] the result type.
    def result_type() @result_type end

    # @return [Parameters] the method definition.
    def method_def() @method_def end

    # @api private
    def == (t)
      mt = MethodType.role(t)
      !mt.nil? && @result_type == mt.result_type && @param_types == mt.params
    end

    # @api private
    def hash
      @result_type.hash + @param_types.hash
    end

    # @api private
    def <= (t)
      if t.is_super_of?(self)
        true
      else
        mt = MethodType.role(t)
        !mt.nil? && @result_type <= mt.result_type &&
          compare_params(mt.params, @param_types)
      end
    end

    # @return [ResultType] the result type.  Note that a {ResultType} object
    #  is always returned.
    def result()
      ResultType.new(@result_type, @method_def)
    end

    # Obtains the name of this type.
    # @return [String] the type name.
    def name
      name = ''
      if @param_types.is_a?(Array)
        name << '(' << @param_types.map{|e| e.name }.join(',') << ')'
      else
        name << @param_types.name
      end
      name  << '->' << @result_type.name
      name
    end

    private

    # @return [Boolean] true if p <= q
    def compare_params(p, q)
      if p.is_a?(Array) && q.is_a?(Array)
        p.size == q.size &&
          (0...p.size).reduce(true) {|b,i| b && p[i] <= q[i] }
      else
        DynType == q
      end
    end
  end

  # Parametric types.
  #
  class CompositeType < Type
    # @return [Module] type name.  The value is a Ruby class.
    attr_reader :ruby_class
    # @return [Array<Type>] type arguments.
    attr_reader :args

    # @param [Module] name  type name.
    # @param [Array<Type>|Type] args  type arguments.
    def initialize(name, args)
      @ruby_class = name
      @args = args.is_a?(Array) ? args : [ args ]
    end

    # @return [Type] the first type argument.
    def first_arg
      @args[0]
    end

    # Checks the equality.
    # @param [Type|Module] t  the other object.
    # @return [Boolean] true if `self` and `t` represent the same type
    #                   and their type arguments are equivalent.
    def == (t)
      ct = CompositeType.role(t)
      !ct.nil? && ct.ruby_class == @ruby_class &&
        ct.args == @args
    end

    # @api private
    def hash
      @ruby_class.hash + @args.reduce(0) {|h,p| h + p.hash }
    end

    # @api private
    # Check the subtype relation.
    # @param [Type] t  the other type.
    # @return [Boolean] true if `self` is equivalent to `t`
    #   or a subtype of `t`.
    def <= (t)
      if t.is_super_of?(self)
        true
      else
        ct = CompositeType.role(t)
        if ct.nil?
          RubyClass[@ruby_class] <= t
        else
          ct.ruby_class == @ruby_class &&
            @args.zip(ct.args).all? {|tt| tt[0] <= tt[1] }
        end
      end
    end

    # @api private
    def exact_type
      @ruby_class
    end

    # @return [RubyClass] the {RubyClass} for this class.
    def supertype
      RubyClass[@ruby_class]
    end

    # Obtains the name of this type.
    # @return [String] the type name.
    def name
      name = @ruby_class.name.dup
      name << '<' << @args.map{|e| e.name }.join(',') << '>'
      name
    end

    # @api private
    # Gets a method with the given name declared in this type.
    # `nil` is returned when the method is not exactly determined.
    #
    # @return [Method|nil]
    def get_method_object(method_name)
      exact_type.instance_method(method_name)
    rescue NameError
      Type.error_found!("no such method: #{@ruby_class}\##{method_name}")
    end
  end

  # A role that can be attached to a {Type} object.
  # It makes a chain of {Type} objects.
  #
  class OptionalRole < Type
    # @param [Type] type  a Type object that this role is added to.
    def initialize(type)
      @type = type
    end

    # @api private
    def copy(without_role)
      chain = @type.copy(without_role)
      if self.is_a?(without_role)
        chain
      else
        if @type.equal?(chain)
          self
        else
          new_self = self.clone()
          new_self.update_type = chain
          new_self
        end
      end
    end

    # @api private
    def update_type(t)
      @type = t
    end

    # Checks the equality.  The roles (a {OptionalRole} objects) in the chain
    # are ignored when objects are compared.
    def == (t)
      @type == t
    end

    # @api private
    def hash
      @type.hash
    end

    # @api private
    def <= (t)
      @type <= t
    end

    # @api private
    def is_super_of?(t)
      @type.is_super_of?(t)
    end

    # @api private
    def has_role?(a_role)
      if self.is_a?(a_role)
        self
      else
        @type.has_role?(a_role)
      end
    end

    # @api private
    def exact_type
      @type.exact_type
    end

    # @api private
    def get_method_object(method_name)
      Type.get_instance_method_object(@type, method_name)
    end

    # @return [Type] the super type.
    def supertype
      @type.supertype
    end
  end # of OptionalRole

  # Type of values returned by a method.
  #
  class ResultType < OptionalRole
    # @return [Parameters] The definition of the method returning
    #                      a value of this type.
    attr_reader :method_def

    # @param [Type] type  a Type object that this role is added to.
    # @param [Parameters] method_def  the method.
    def initialize(type, method_def)
      super(type)
      @method_def = method_def
    end
  end

  # Type of the value of a local variable.
  #
  class LocalVarType < OptionalRole
    # @return [ASTnode|Undef|nil] the AST node where the variable appears
    #                   for the first time, in other words,
    #                   where the variable's type is defined.
    #                   `Undef` if a value is assigned to the variable
    #                   more than once.
    #                   `nil` if an initial value has not been assigned
    #                   to the variable yet.
    attr_reader :definition

    # @param [Type] type  a Type object that this role is added to.
    # @param [ASTnode|nil] definition  the AST node of the local variable.
    #                                  `nil` if an initial value is not set.
    def initialize(type, definition)
      super(type)
      @definition = definition
    end

    # @param [ASTnode] ast  the AST node of the local variable where
    #                  a new value is assigned to it.
    # @return [self]
    def definition=(ast)
      if @definition.nil?
        @definition = ast
      else
        @definition = Undef
      end
      self
    end

  end
end
