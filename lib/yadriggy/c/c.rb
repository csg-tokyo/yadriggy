# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'yadriggy'
require 'yadriggy/c/ctypecheck'
require 'yadriggy/c/codegen'
require 'yadriggy/c/ffi'
require 'yadriggy/c/config'

module Yadriggy
  module C
    # yadriggy/c/ffi.rb also defiens methods in this module.

    # An error thrown during compilation.
    #
    class BuildError < RuntimeError
      attr_accessor :all_messages

      # @param [Array<String>] msg  an array of strings.
      def initialize(msg)
        super(msg.empty? ? '' : msg.is_a?(String) ? msg : msg[0])
        @all_messages = msg.is_a?(String) ? [msg] : msg
      end
    end

    @syntax = Yadriggy::define_syntax do
      expr  <= Name | Number | Binary | Unary |
               ConstPathRef | StringLiteral | ArrayRef |
               Paren | typedecl | method_call
      stmnt <= expr | Return | ForLoop | Loop | Conditional
      exprs <= Exprs + { expressions: [ stmnt ] } | stmnt

      Name <= {}
      Number     <= {}
      SymbolLiteral    <= nil
      InstanceVariable <= {}
      GlobalVariable   <= nil
      Reserved   <= nil
      Const      <= Name
      ConstPathRef   <= { scope: (ConstPathRef | Const), name: Const }
      StringLiteral  <= {}
      Paren      <= { expression: expr }
      Return     <= { values: expr | nil }    # only single return value
      ForLoop    <= {vars: Name, set: Dots, body: exprs }
      Loop       <= { op: Symbol, cond: expr, body: exprs }
      Conditional <= { op: Symbol, cond: expr, then: exprs,
                       all_elsif: [expr * exprs], else: (exprs) }
      method_call <= Call +
                     { receiver: (expr), op: (Symbol), name: Name,
                       args: [ expr ], block_arg: nil }

      arrayof_name <= Identifier + { name: 'arrayof' }
      arrayof     <= Call + { receiver: nil, op: nil, name: arrayof_name,
                              args: [ expr ], block_arg: nil, block: nil }
      typedecl_hash <= HashLiteral + { pairs: [ Label * label_value ] }
      label_value <= Const | ConstPathRef | arrayof | StringLiteral
      typedecl_name <= Identifier + { name: 'typedecl' }
      typedecl   <= Call +
                   { name: typedecl_name, args: [ typedecl_hash ] }

      return_type <= Unary + { operand: Const | ConstPathRef | arrayof }
      func_body  <= return_type | stmnt |
                    Exprs + { expressions: [ (return_type), stmnt ] }

      Parameters <= { params: [ Identifier ], optionals: nil,
                      rest_of_params: nil, params_after_rest: nil,
                      keywords: nil, rest_of_keywords: nil,
                      block_param: nil }
      Block      <= Parameters + { body: func_body }
      Def        <= Parameters + { singular: nil, name: Identifier,
                                   body: func_body, rescue: nil }
      Program    <= { elements: exprs }
    end

    # @return [Syntax] the syntax.
    def self.syntax
      @syntax
    end

    # Compiles methods into binary code.
    #
    # @param [Proc|Method|UnboundMethod|Object] obj  the exposed method
    #   or a block.  If `obj` is neither a method or a block,
    #   all the public methods available on `obj` are exposed.
    #   The methods invoked by the exposed methods are also compiled.
    # @param [String] lib_name  the library name.
    # @param [String] dir  the directory name.
    # @param [String] module_name  the module name where the exposed methods
    #   are attached when the generated Ruby script is executed.
    #   If `method_name` is nil, no Ruby script is generated.
    # @return [Module] the module object where the exposed methods
    #   are attached.  It does not have a name.
    def self.compile(obj, lib_name=nil, dir=Config::WorkDir, module_name=nil)
      mod, funcs = compile0(obj, lib_name, dir, module_name,
                            ClangTypeChecker, CodeGen)[0]
      mod
    end

    # @private
    # @return [Pair<Module,Array<String>>]
    def self.compile0(obj, lib_name, dir, module_name,
                      typechecker_class, gen_class)
      begin
        compile1(obj, lib_name, dir, module_name,
                 typechecker_class, gen_class)
      rescue SyntaxError, CheckError, BuildError => err
        raise err if Yadriggy.debug > 0
        warn err.message
        nil
      end
    end

    # @private
    # @return [Pair<Module,Array<String>>]
    def self.compile1(obj, lib_name, dir, module_name,
                      typechecker_class, gen_class)
      lib_name0 = obj.class.name
      method_objs = if obj.is_a?(Proc) || obj.is_a?(Method) ||
                        obj.is_a?(UnboundMethod)
                      lib_name0 += obj.object_id.to_s(16)
                      [obj]
                    else
                      obj.public_methods(false).map do |name|
                        obj.method(name)
                      end
                    end
      lib_name = lib_name0.gsub('::', '_').downcase if lib_name.nil?

      raise BuildError.new('no methods specified') if method_objs.size < 1

      checker = typechecker_class.new(@syntax)
      pub_methods = compiled_methods(checker, method_objs)

      dir += File::Separator unless dir.end_with?(File::Separator)
      FileUtils.mkdir_p(dir)
      printer = Yadriggy::FilePrinter.new(gen_class.c_src_file(dir, lib_name))
      gen = gen_class.new(printer, checker, pub_methods)

      generate_funcs(pub_methods[0], gen, printer)
      gen.build_lib(lib_name, dir)

      attach_funcs(pub_methods, checker, gen, module_name, lib_name, dir)
    end

    # @private
    # @return [Array<ASTree>] the ASTs of compiled methods.
    def self.compiled_methods(checker, method_objs)
      ast = nil
      pub_methods = method_objs.map do |mthd|
        if ast.nil?
          ast = Yadriggy::reify(mthd)
        else
          ast = ast.reify(mthd)
        end

        if ast.nil?
          raise SyntaxError.new(
            "cannot locate the source: #{mthd.name.to_s} in #{mthd.receiver.class}")
        end

        @syntax.raise_error unless @syntax.check(ast.tree)
        checker.typecheck(ast.tree)
        ast
      end

      return pub_methods
    end

    # @private
    def self.generate_funcs(ast, gen, printer)
      gen.name_global_variables
      gen.headers
      gen.variable_declarations
      ast.astrees.each do |e|
        gen.prototype(e.tree)
      end
      gen.preamble
      ast.astrees.each do |e|
        printer << :nl
        gen.c_function(e.tree)
      end

      printer.output
      printer.close

      raise BuildError.new(gen.error_messages) if gen.errors?
    end

    # @private
    # @return [Pair<Module,Array<String>>] the module where the methods
    #   are attached.  The second element is method names.
    def self.attach_funcs(pub_methods, checker, gen, module_name,
                          lib_name, dir)
      func_names = pub_methods.map { |ast| gen.c_function_name(ast.tree) }
      func_types = pub_methods.map { |ast| checker.type(ast.tree) }

      func_names, func_types = gen.expand_functions(func_names, func_types)

      unless module_name.nil?
        make_attach_file(module_name, func_names, func_types,
                         lib_name, dir)
      end

      [attach(Module.new, func_names, func_types, lib_name, dir),
        func_names]
    end

    # Compiles and runs a block.
    #
    # @param [String] lib_name  the library name.
    # @param [String] dir  the directory name.
    # @param [Object...] args  the arguments to the block.
    # @return [Object] the result of running the given block.
    def self.run(lib_name=nil, *args, dir: Config::WorkDir, &block)
      raise BuildError.new('no block given') if block.nil?
      mod, mths = compile0(block, lib_name, dir, nil,
                           ClangTypeChecker, CodeGen)
      mod.method(mths[0]).call(*args)
    end
  end
end
