# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'yadriggy/c/c'
require 'yadriggy/c/config'

module Yadriggy
  module C
    class Program
      include Yadriggy::C::CType

      # Compiles this class and makes a module including the
      # compiled methods.
      #
      # @param [String] module_name  the name of the module where
      #  methods are attached.  If it is not nil, a Ruby script
      #  is generated.  When it is executed later, the methods are
      #  attached to the module with `module_name`.
      #  The name of the generated Ruby script is `#{lib_name}.rb`.
      # @param [String] lib_name  the name of the generated library.
      # @param [String] dir  the directory name where generated files
      #   are stored.
      # @return [Module] the module where methods are attached.
      #   Note that the name of this module is nil.
      #   It is not `method_name`.
      def self.compile(module_name=nil, lib_name=nil, dir: Config::WorkDir)
        obj = self.new
        Yadriggy::C.compile(obj, lib_name, dir, module_name)
      end

      # Prints arguments.  This method is available from C code.
      # It takes arguments as `printf` in C.  For example,
      # `printf('value %d', 7)` is a valid call.
      # Note that the argument types are not checked.
      def printf(s) ! Void
        typedecl s: String, foreign: Void
        puts s
      end

      # Gets the current time in micro sec.
      # @return [Time] the current time.  In C, an integer is returned.
      def current_time() ! Int
        typedecl native: "struct timespec time;\n\
clock_gettime(CLOCK_MONOTONIC, &time);\n\
return time.tv_sec * 1000000 + time.tv_nsec / 1000;"
        Time.now * 1000000
      end

      # Square root function with single precision.
      def sqrtf(f)
        typedecl f: Float, foreign: Float
        Math.sqrt(f)
      end

      # Square root function.
      def sqrt(f)
        typedecl f: Float, foreign: Float
        Math.sqrt(f)
      end

      # Exponential function with single precision.
      def expf(f)
        typedecl f: Float, foreign: Float
        Math.exp(f)
      end

      # Exponential function.
      def exp(f)
        typedecl f: Float, foreign: Float
        Math.exp(f)
      end

      # Logarithm function with single precision.
      def logf(f)
        typedecl f: Float, foreign: Float
        Math.log(f)
      end

      # Logarithm function.
      def log(f)
        typedecl f: Float, foreign: Float
        Math.log(f)
      end

    end
  end
end
