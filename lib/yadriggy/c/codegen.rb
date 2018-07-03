# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'yadriggy/c/config'
require 'yadriggy/c/ffi'
require 'yadriggy/c/ctype'

module Yadriggy
  module C

    # C-code generator
    #
    # Since Checker implements Visitor pattern, use it for code
    # generation.
    #
    class CodeGen < Checker
      # printer is a Printer object.
      # Only main_method is converted into an extern function.
      # Other methods are converted into static functions.
      # @param [Array<ASTree>] public_methods  publicly exported methods.
      def initialize(printer, typechecker, public_methods)
        super()
        @printer = printer
        @typechecker = typechecker
        @func_counter = 0
        @func_names = {}
        @nerrors = 0
        @messages = []
        @public_methods = {}
        public_methods.each {|m| @public_methods[m.tree] = m.tree }
        @gvariables = {}
      end

      # Tests whether a type error was found.
      #
      def errors?
        @nerrors > 0
      end

      # Gets an array of error messages.
      #
      def error_messages
        @messages
      end

      # Gets the type checker.
      #
      def typechecker
        @typechecker
      end

      # Gets the printer given when object construction.
      #
      def printer
        @printer
      end

      rule(:typedecl) do
        # nothing to be printed
      end

      rule(:return_type) do
        # nothing to be printed
      end

      rule(Number) do
        @printer << ast.value.to_s
      end

      rule(Name) do
        @printer << ast.name
      end

      rule(IdentifierOrCall) do
        t = @typechecker.type(ast)
        rt = ResultType.role(t)
        unless rt.nil?
          mdef = rt.method_def
          @printer << c_function_name(mdef) << '()'
        else
          it = InstanceType.role(t)
          unless it.nil?
            @printer << it.object
          else
            @printer << ast.name
          end
        end
      end

      rule(Const) do
        t = @typechecker.type(ast)
        @printer << InstanceType.role(t)&.object
      end

      rule(ConstPathRef) do
        t = @typechecker.type(ast)
        @printer << InstanceType.role(t)&.object
      end

      rule(InstanceVariable) do
        t = @typechecker.type(ast)
        vname = @gvariables[InstanceType.role(t)&.object]
        error(ast, 'unknown instance variable') if vname.nil?
        @printer << vname
      end

      rule(Exprs) do
        ast.expressions.map do |e|
          check(e)
          unless e.is_a?(Conditional) ||
                 e.is_a?(Loop) || e.is_a?(ForLoop)
            @printer << ';' << :nl
          end
        end
      end

      rule(ArrayLiteral) do
        @printer << ' { '
        ast.elements.map do |e|
          check(e)
          @printer << ', '
        end
        @printer << ' } '
      end

      rule(StringLiteral) do
        @printer << '"' << ast.value.gsub(/\n/, '\\n') << '"'
      end

      rule(Paren) do
        @printer << '('
        check(ast.expression)
        @printer << ')'
      end

      rule(Unary) do
        @printer << ast.real_operator.to_s
        check(ast.operand)
      end

      rule(Binary) do
        check(ast.left)
        @printer << ' ' << ast.op.to_s << ' '
        check(ast.right)
      end

      rule(ArrayRef) do
        check(ast.array)
        ast.indexes.each do |idx|
          @printer << '['
          check(idx)
          @printer << ']'
        end
      end

      rule(Dots) do
        error(ast, 'a range object is not available')
      end

      rule(Call) do
        if @typechecker.method_with_block?(ast.name.name)
          call_with_block(ast)
        else
          t = @typechecker.type(ast)
          mdef = ResultType.role(t).method_def

          if mdef.nil?
            @printer << ast.name.name << '('
          else
            @printer << c_function_name(mdef) << '('
          end

          ast.args.each_with_index do |e, i|
            @printer << ', ' if i > 0
            check(e)
          end
          @printer << ')'
        end
      end

      def call_with_block(call_ast)
        loop_param = call_ast.block.params[0]
        @printer << 'for (' << c_type(RubyClass::Integer) << ' '
        check(loop_param)
        @printer << ' = ('
        check(ast.receiver)
        @printer << ') - 1; '
        check(loop_param)
        @printer << ' >= 0; '
        check(loop_param)
        @printer << '--) {'
        @printer.down
        local_var_declarations(ast.block)
        check(ast.block.body)
        @printer << ';' unless ast.block.body.is_a?(Exprs)
        @printer.up
        @printer << '}' << :nl
      end

      rule(Conditional) do
        case ast.op
        when :unless, :unless_mod
          error(ast, "a bad control statement")
        when :ifop
          @printer << '('
          check(ast.cond)
          @printer << ') ? ('
          check(ast.then)
          @printer << ') : ('
          check(ast.else)
          @printer << ')'
        else
          @printer << "if ("
          check(ast.cond)
          @printer << ') {'
          @printer.down
          check(ast.then)
          @printer << ';' unless ast.then.is_a?(Exprs)
          @printer.up
          unless ast.else.nil?
            @printer << '} else {'
            @printer.down
            check(ast.else)
            @printer << ';' unless ast.else.is_a?(Exprs)
            @printer.up
          end
          @printer << '}' << :nl
        end
      end

      rule(Loop) do
        case ast.op
        when :until, :while_mod, :until_mod
          error(ast, "#{ast.op} is not available")
        else
          @printer << 'while ('
          check(ast.cond)
          @printer << ') {'
          @printer.down
          check(ast.body)
          @printer << ';' unless ast.body.is_a?(Exprs)
          @printer.up
          @printer << '}' << :nl
        end
      end

      rule(ForLoop) do
        var_name = ast.vars[0].name
        @printer << 'for (' << var_name << ' = '
        check(ast.set.left)
        @printer << '; ' << var_name
        if ast.set.op == :'...'
          @printer << ' < '
        else
          @printer << ' <= '
        end
        check(ast.set.right)
        @printer << '; ++' << var_name << ') {' << :nl
        @printer.down
        check(ast.body)
        @printer << ';' unless ast.body.is_a?(Exprs)
        @printer.up
        @printer << '}' << :nl
      end

      rule(Return) do
        @printer << 'return '
        check(ast.values[0])   # ast.values.size is < 2.
      end

      rule(Block) do
        def_function(ast, c_function_name(ast))
      end

      rule(Def) do
        def_function(ast, c_function_name(ast))
      end

      # Obtains the file name of the generated source code.
      # A subclass can redefine this method.
      #
      # @param [String] dir  a directory name.
      # @param [String] lib_name  a library name.
      # @return [String] a source file name.
      def self.c_src_file(dir, lib_name)
        "#{dir}#{lib_name}.c"
      end

      # Runs a compiler.
      # A subclass can redefine this method.
      #
      # @param [String] lib_name  a library name.
      # @param [String] dir  a directory name.
      # @return [void]
      def build_lib(lib_name, dir='./')
        file_name = self.class.c_src_file(dir, lib_name)
        lib_file_name = "#{dir}lib#{lib_name}#{Config::LibExtension}"
        cmd = "#{build_cmd} #{Config::CoptOutput}#{lib_file_name} #{file_name}"
        system(cmd)
        status = $?.exitstatus
        raise BuildError.new(["exit #{status}"]) if status > 0
      end

      # Obtains compiler command.
      # A subclass can redefine this method.
      #
      # @return [String] command.
      def build_cmd
        Config::Compiler
      end

      # Prints `#include` derectives.
      #
      # @return [void]
      def headers()
        Config::Headers.each {|h| @printer << h << :nl }
        @printer << :nl
      end

      # Gives a name to each global variable.
      # @return [void]
      def name_global_variables()
        id = 0
        @typechecker.instance_variables.each do |obj|
          @gvariables[obj] = "_gvar_#{id}_"
          id += 1
        end
      end

      # Prints variable declarations.
      # @return [void]
      def variable_declarations()
        @gvariables.each do |obj, name|
          if obj.is_a?(CType::CArray)
            @printer << 'static ' << c_type(obj.type) << ' ' << name
            obj.sizes.each {|s| @printer << '[' << s << ']' }
            @printer << ';' << :nl
          end
        end
        @printer << :nl
      end

      # Prints a function prototype.
      #
      # @param [Def|Block] expr   the function.
      # @return [void]
      def prototype(expr)
        t = @typechecker.type(expr)
        return if ForeignMethodType.role(t)

        @printer << 'static ' if @public_methods[expr].nil?

        fname_str = c_function_name(expr)
        mt = MethodType.role(t)
        if mt
          parameters(expr, fname_str, mt)
          @printer << ';' << :nl
        else
          error(expr, "bad method #{fname_str}")
        end
        self
      end

      # Prints a preamble.  This method is invoked right after printing
      # function prototypes. A subclass can override this method.
      # The original implementation does not print anything.
      #
      def preamble
      end

      # Appends implicitly generated functions.
      # A subclass can override this method.
      # The original implementation does not append any.
      #
      # @param [Array<String>] func_names  the names of the generated
      #   functions.
      # @param [Array<Type>] func_names  the types of the original methods.
      # @return [Array<String>, Array<Type>]  the names and types.
      def expand_functions(func_names, func_types)
        return func_names, func_types
      end

      # Prints a function implementation.
      #
      # @param [Def|Block] expr   the function.
      # @return [void]
      def c_function(expr)
        check(expr)
      end

      # Gets the function name in C after the translation from a Ruby
      # method into a C function.
      #
      # @param [Block|Def|Call] expr  an expression.
      # @return [String] the function name for `expr`.
      def c_function_name(expr)
        return expr.name.name if expr.is_a?(Def) &&
                                 @public_methods.include?(expr)

        fname_str = @func_names[expr]
        if fname_str.nil?
          @func_counter += 1
          fname_str = if expr.is_a?(Block)
                        "yadriggy_blk#{@func_counter}"
                      else
                        "#{expr.name.name}_#{@func_counter}"
                      end
          @func_names[expr] = fname_str
        end
        fname_str
      end

      private

      def def_function(expr, fname)
        t = @typechecker.type(expr)
        return if ForeignMethodType.role(t)

        @printer << 'static ' if @public_methods[expr].nil?

        mt = MethodType.role(t)
        if mt
          parameters(expr, fname, mt)
        else
          error(expr, 'not a function')
        end

        @printer << ' {'
        @printer.down
        native_t = NativeMethodType.role(t)
        if native_t
          @printer << native_t.body
        else
          local_var_declarations(expr)
          check(expr.body)
          @printer << ';' unless expr.body.is_a?(Exprs)
        end
        @printer.up
        @printer << '}' << :nl
      end

      def parameters(expr, fname_str, mtype)
        ret_type = mtype.result_type
        @printer << c_type(ret_type) << ' '
        @printer << fname_str << '('
        param_types = mtype.params
        if param_types.is_a?(Array)
          expr.params.each_with_index do |p, i|
            @printer << ', ' if i > 0
            @printer << c_type(param_types[i]) << ' ' << p.name
          end
        else
          error(expr, 'bad parameter types')
        end
        @printer << ')'
      end

      # @param [Def|Block] def_or_block
      def local_var_declarations(def_or_block)
        local_vars = @typechecker.local_vars_table[def_or_block]
        if local_vars.nil?
          error(def_or_block, 'bad function definition or block')
        else
          local_vars.each do |name, type|
            @printer << c_type(type) << ' ' << name.to_s << ';' << :nl
          end
        end
      end

      # @param [Type] type
      def c_type(type)
        CFI::c_type_name(type)
      end

      def error(ast, msg)
        @nerrors += 1
        @messages << "#{ast.source_location_string}: #{msg}"
      end

    end # end of CodeGen
  end
end
