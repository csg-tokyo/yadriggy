# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'yadriggy/c/ctype.rb'
require 'yadriggy/c/codegen'
require 'yadriggy/c/ctypecheck'
require 'yadriggy/c/program'
require 'yadriggy/c/config'

module Yadriggy
  module C
    # Compiles OpenCL methods into binary code.
    #
    def self.ocl_compile(obj, lib_name=nil, dir=Config::WorkDir,
                         module_name=nil)
      mod, funcs = compile0(obj, lib_name, dir, module_name,
                            OclTypeChecker, OclCodeGen)
      mod
    end

    class Program
      # Compiles this class and makes a module including the
      # compiled OpenCL methods.
      #
      # @param [String] module_name  a module name.
      # @param [String] lib_name  the name of the generated library.
      # @param [String] dir  the directory name where generated files
      #   are stored.  The default value is `.`.
      # @param [Array<Object>] args  an array of the arguments to the
      #   `initialize` method.  The default value is `nil` (no arguments).
      # @return [Module] the module where methods are attached.
      def self.ocl_compile(module_name=nil, lib_name=nil,
                           dir: Config::WorkDir, args: nil)
        if args.nil?
          obj = self.new
        else
          obj = self.new(*args)
        end
        Yadriggy::C.ocl_compile(obj, lib_name, dir, module_name)
      end
    end

    module CType  # also see ctype.rb
      # OpenCL array.
      #
      class OclArray < IvarObj
        def initialize(size)
          @size = size
        end

        def self.type()
          Float32Type
        end

        def type()
          Float32Type
        end

        def size()
          @size
        end

        def sizes()
          [ @size ]
        end

        def copyfrom(array, len) ! Integer
          typedecl array: arrayof(Float32), len: Integer,
                   native: 'return 0;'
          return 0
        end

        def copyto(array, len) ! Integer
          typedecl array: arrayof(Float32), len: Integer,
                   native: 'return 0;'
          return 0
        end
      end
    end

    class OclTypeChecker < ClangTypeChecker
      # A map from blocks to their names and free variables.
      #
      # @return [Hash<Block,Tuple<String,Hash<Symbol,Type>,Set<Object>>]
      #   a map to tuples of a block name, free variables, and instance
      #   variables accessed in the block.
      attr_reader :blocks

      def initialize(syntax=nil)
        super(syntax)
        @blocks = {}
        @block_count = 0
      end

      def method_with_block?(name)
        super || name == 'ocl_times'
      end

      def typecheck_call_with_block(ast)
        if ast.name.name == 'ocl_times'
          type_assert(type(ast.receiver) == RubyClass::Integer,
                      'the receiver must be an integer')
          type_assert(ast.block.params.size == 1,
                      "wrong number of block parameters")
          tenv = FreeVarFinder.new(type_env)
          type_as(ast.block.params[0], RubyClass::Integer)
          tenv.bind_name(ast.block.params[0], RubyClass::Integer)
          tenv.bind_name(:return, Void)

          old_ins_vars = @instance_variables
          @instance_variables = Set.new
          type(ast.block, tenv)
          captured_ins_vars = @instance_variables
          @instance_variables = old_ins_vars
          @instance_variables += captured_ins_vars

          @blocks[ast.block] = ["block#{@block_count}", tenv.free_variables,
            captured_ins_vars]
          @block_count += 1
          Void
        else
          super
        end
      end

      rule(ArrayRef) do
        array_type = type(ast.array)
        if array_type <= RubyClass[OclArray]
          indexes = ast.indexes
          type_assert(indexes.size == 1, 'bad array index')
          itype = type(indexes[0])
          type_assert(itype <= RubyClass::Integer, 'bad array index')
          OclArray.type
        else
          proceed(ast)
        end
      end
    end

    # OpenCL-code generator
    #
    class OclCodeGen < CodeGen

      # @see {OclTypeChecker#method_with_block?}
      rule(Call) do
        if ast.name.name == 'copyfrom'
          @printer << 'ocl_err_check(clEnqueueWriteBuffer(commands, '
          check(ast.receiver)
          @printer << ', CL_TRUE, 0, sizeof(float) * '
          check(ast.args[1]) # length
          @printer << ', '
          check(ast.args[0]) # array
          @printer << ', 0, NULL, NULL), "' << ast.name.name << '")'
        elsif ast.name.name == 'copyto'
          @printer << 'ocl_err_check(clEnqueueReadBuffer(commands, '
          check(ast.receiver)
          @printer << ', CL_TRUE, 0, sizeof(float) * '
          check(ast.args[1]) # length
          @printer << ', '
          check(ast.args[0]) # array
          @printer << ', 0, NULL, NULL), "' << ast.name.name << '")'
        elsif ast.name.name == 'ocl_times'
          name_and_vars = @typechecker.blocks[ast.block]
          @printer << name_and_vars[0] << '_call('
          check(ast.receiver)
          name_and_vars[1].each do |sym, t|
            @printer << ', ' << sym.to_s
          end
          @printer << ')'
        else
          proceed(ast)
        end
      end

      def build_cmd
        super + Config::OpenCLoptions
      end

      def headers()
        super
        Config::OpenCLHeaders.each {|h| @printer << h << :nl }
        @printer << :nl
      end

      def variable_declarations()
        super
        @gvariables.each do |obj, name|
          if obj.is_a?(CType::OclArray)
            @printer << 'static cl_mem ' << name << ';' << :nl
          end
        end
        @typechecker.blocks.each do |obj, name_and_vars|
          @printer << 'static cl_kernel ' << name_and_vars[0] << ';' << :nl
        end
        @printer << :nl
      end

      def preamble
        super
        @printer << 'int ocl_init(int);'  << :nl
        @printer << 'void ocl_finish();' << :nl << :nl

        print_kernel_source
        @printer << HelperSource
        print_ocl_init
        print_ocl_finish
        print_callers
      end

      def expand_functions(func_names, func_types)
        voidFunc = MethodType.new([], Void)
        return func_names + ['ocl_init', 'ocl_finish'],
               func_types + [MethodType.new([Integer], Void),
                             MethodType.new([], Void)]
      end

      private

      def print_ocl_init
        @printer << 'int ocl_init(int is_gpu) {' << :nl
        @printer << '  if (ocl_initialized) return 0;' << :nl
        @printer << '  ocl_initialized = 1;' << :nl
        @printer << '  if (ocl_init0(is_gpu)) return 1;' << :nl << :nl
        print_create_kernel_code
        print_create_buffer_code
        @printer << :nl << '  return 0;' << :nl << '}' << :nl << :nl
      end

      def print_ocl_finish
        @printer << 'void ocl_finish() {' << :nl
        @printer << '  if (!ocl_initialized) return;' << :nl
        @printer << '  ocl_initialized = 0;' << :nl
        @gvariables.each do |obj, name|
          if obj.is_a?(CType::OclArray)
            @printer << "  clReleaseMemObject(#{name});" << :nl
          end
        end

        @typechecker.blocks.each do |obj, name_vars|
          @printer << '  clReleaseKernel(' << name_vars[0] << ');' << :nl
        end

        @printer << '  clReleaseProgram(program);' << :nl
        @printer << '  clReleaseCommandQueue(commands);' << :nl
        @printer << '  clReleaseContext(context);' << :nl
        @printer << '}' << :nl << :nl
      end

      # generate kenrel source.
      def print_kernel_source
        @printer << 'static const char* kernelSource = ' << :nl << '"'
        @printer = KernelPrinter.new(@printer)
        @typechecker.blocks.each do |blk, name_vars|
          func_name = name_vars[0]
          @printer << '__kernel void ' << func_name << '('

          all_free_vars = name_vars[1].to_a
          all_free_vars += name_vars[2].map do |obj|
            [@gvariables[obj], obj.class]
          end

          first = true
          all_free_vars.each do |name, type|
            if first then first = false else @printer << ', ' end
            print_type_in_kernel(type)
            @printer << name
          end
          @printer << ') {'
          @printer.down
          local_var_declarations(blk)
          @printer << 'int ' << blk.params[0].name
          @printer << ' = get_global_id(0);' << :nl
          check(blk.body)
          @printer << ';' unless blk.body.is_a?(Exprs)
          @printer.up
          @printer << '}' << :nl
        end
        @printer = @printer.printer
        @printer << ' ";' << :nl << :nl
      end

      # @param [Type|Class] type
      def print_type_in_kernel(type)
        if type == CType::OclArray || type == RubyClass[CType::OclArray]
          @printer << '__global float* '
        else
          @printer << c_type(type) << ' '
        end
      end

      def c_type(type)
        if @printer.is_a?(KernelPrinter) &&
            (type == RubyClass::Integer || type == Integer)
          return 'int'
        else
          super
        end
      end

      class KernelPrinter
        attr_reader :printer

        def initialize(printer)
          @printer = printer
        end

        def down()
          @printer << "\"\\"
          @printer.down
          @printer << '"'
        end

        def up()
          @printer << "\"\\"
          @printer.up
          @printer << '"'
        end

        def nl()
          @printer << "\"\\" << :nl << '"'
          self
        end

        def << (code)
          code == :nl ? nl : @printer << code
          self
        end
      end

      # generate the code for creating kernels.
      def print_create_kernel_code
        @printer << '  int err;' << :nl
        @typechecker.blocks.each do |blk, name_vars|
          @printer << '  ' << name_vars[0]
          @printer << ' = clCreateKernel(program, "' << name_vars[0] << '", &err);' << :nl
          @printer << '  if (err != CL_SUCCESS) {' << :nl
          @printer << '    fprintf(stderr, "error: clCreateKernel\n");' << :nl
          @printer << '    return 1; }' << :nl
        end
        @printer << :nl
      end

      # generate the code for creating buffers.
      def print_create_buffer_code
        @gvariables.each do |obj, name|
          if obj.is_a?(CType::OclArray)
            @printer << "  #{name} = clCreateBuffer(context, CL_MEM_READ_WRITE,"\
                        " sizeof(float) * #{obj.size}, NULL, NULL);" << :nl
            @printer << "  if (!#{name}) {" << :nl
            @printer << '    fprintf(stderr, "error: clCreateBuffer\n");'
            @printer << ' return 1; }' << :nl
          end
        end
      end

      def print_callers
        @typechecker.blocks.each do |blk, name_and_vars|
          name = name_and_vars[0]
          @printer << 'static void ' << name << '_call(size_t p0'
          name_and_vars[1].each_with_index do |name_type, i|
            type = name_type[1]
            tname = if type <= RubyClass[CType::OclArray]
                      'cl_mem'
                    else
                      c_type(type)
                    end
            @printer << ', ' << tname << " p#{i + 1}"
          end
          @printer << ') {'
          @printer.down
          @printer << 'size_t global;' << :nl
          @printer << 'int err = 0;' << :nl

          i = name_and_vars[1].size
          name_and_vars[2].each do |obj|
            i += 1
            @printer << "cl_mem p#{i} = #{@gvariables[obj]};" << :nl
          end
          i.times do |j|
            @printer << "err  |= clSetKernelArg(#{name}, #{j}, sizeof(p#{j + 1}), &p#{j + 1});" << :nl
          end

          @printer << 'ocl_err_check(err, "clSetKernelArg");' << :nl
          @printer << 'global = p0;' << :nl
          @printer << 'ocl_err_check(clEnqueueNDRangeKernel(commands, '
          @printer << name << ', 1, NULL, &global, NULL, 0, NULL, NULL), "clEnqueueNDRangeKernel");' << :nl
          @printer << 'clFinish(commands);' << :nl
          @printer.up
          @printer << '}' << :nl
        end
      end

      HelperSource = <<'EOS'
static int ocl_initialized = 0;
static cl_device_id device_id;
static cl_context context;
static cl_command_queue commands;
static cl_program program;

static int ocl_err_check(int err, const char* msg) {
  if (err == CL_SUCCESS)
    return 0;
  else {
    fprintf(stderr, "OpenCL Error: %s, %d\n", msg, err);
    return 1;
  }
}

static int ocl_init0(int gpu) {
  cl_device_id devices[4];
  cl_uint num_devices;
  int err = clGetDeviceIDs(NULL,
                gpu > 0? CL_DEVICE_TYPE_GPU : CL_DEVICE_TYPE_CPU,
                sizeof(devices) / sizeof(devices[0]), devices, &num_devices);
  if (err != CL_SUCCESS) {
    fprintf(stderr, "error: clGetDeviceIDs\n");
    return 1;
  }

  int id = num_devices < gpu ? num_devices : gpu;
  device_id = devices[id < 1 ? 0 : id - 1];

  context = clCreateContext(0, 1, &device_id, NULL, NULL, &err);
  if (!context) {
    fprintf(stderr, "error: clCreateContext\n");
    return 1;
  }

  commands = clCreateCommandQueue(context, device_id, 0, &err);
  if (!commands) {
    fprintf(stderr, "error: clCreateCommandQueue\n");
    return 1;
  }

  program = clCreateProgramWithSource(context, 1,
                (const char **)&kernelSource, NULL, &err);
  if (!program) {
    fprintf(stderr, "error: clCreateProgramWithSource\n");
    return 1;
  }

  err = clBuildProgram(program, 0, NULL, NULL, NULL, NULL);
  if (err != CL_SUCCESS) {
    size_t len;
    char buffer[2048];
    fprintf(stderr, "error: clBuildProgram\n");
    clGetProgramBuildInfo(program, device_id, CL_PROGRAM_BUILD_LOG,
                          sizeof(buffer), buffer, &len);
    fprintf(stderr, "%s\n", buffer);
    return 1;
  }

  return 0;
}

EOS
    end
  end
end
