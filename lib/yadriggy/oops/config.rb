# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

module Yadriggy
  module Oops

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

      # Compiler options for generating a MacOS dynamic library working
      # with yadriggy_oops.bundle.
      mac_opt = if HostOS == :macos
        '-flat_namespace -undefined suppress '
      else 
        ''
      end

      # Compiler command.
      # @return [String]
      Compiler = "c++ -std=c++11 -g -shared -fPIC -Ofast #{mac_opt}"

      # Compiler option specifying the output file.
      # @return [String]
      CoptOutput = '-o '

      # The suffix to the name of a shared library such as `.so`.
      # It has to start with a dot.
      LibExtension = HostOS == :macos ? '.dylib' : '.so'

      # Lines inserted in the generated C++ source file.
      Headers = [
        "#include \"#{File.expand_path('gc.hpp', __dir__)}\"",
        '#include <cmath>'
      ]

    end
  end
end
