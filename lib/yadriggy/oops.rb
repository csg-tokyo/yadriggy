# Copyright (C) 2019- Shigeru Chiba.  All rights reserved.

require 'yadriggy'
require 'yadriggy/oops/cxx'
require 'yadriggy/oops/yadriggy_oops'

module Yadriggy
  module Oops
    # Allocates the heap memory.
    # @param [Integer] nursery_size     the size of the nursery space in MB.
    # @param [Integer] stack_size       the size of the shadow stack space in MB.
    def self.allocate(nursery_size=32, stack_size=8)
      release
      allocate2(nursery_size, stack_size);
    end

    allocate()

    # Releases the heap memory.
    # def self.release() end

    # Gets the size of the tenure space.
    # def self.tenure_size() end
  
    # Performs the minor GC.
    # def self.minor_gc() end
  
    # Performs the major GC.
    # def self.major_gc() end

    # Debug level.  The initial value is 0.
    # attr_accessor :debug
  end
end
