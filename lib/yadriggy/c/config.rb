# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

module Yadriggy
  module C

    # Compiler options etc.
    #
    module Config
      # Host OS
      # @return [Symbol] `:linux`, `:macos`, `:unknown`.
      HostOS = case RbConfig::CONFIG['host_os']
               when /linux/
                 :linux
               when /darwin/
                 :macos
               else
                 :unknown
               end

      # Working directory.
      WorkDir = './yadriggy_tmp'

      # Compiler command.
      # @return [String]
      Compiler = 'gcc -shared -fPIC -Ofast '

      # Compiler option specifying the output file.
      # @return [String]
      CoptOutput = '-o '

      # The suffix to the name of a shared library such as `.so`.
      # It has to start with a dot.
      LibExtension = HostOS == :macos ? '.dylib' : '.so'

      # Lines inserted in the generated C source file.
      Headers = [
        '#include <stdint.h>',
        '#include <time.h>',
        '#include <math.h>',
        '#include <stdio.h>'
      ]

      # Compiler option for OpenCL
      # @return [String]
      OpenCLoptions = '-framework opencl '

      # Lines inserted in the generated OpenCL source file.
      OpenCLHeaders = [ '#include <OpenCL/opencl.h>' ]
    end
  end
end
