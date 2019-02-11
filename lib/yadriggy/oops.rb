# Copyright (C) 2019- Shigeru Chiba.  All rights reserved.

require 'yadriggy'
require 'yadriggy/oops/yadriggy_oops'

module Yadriggy
  module Oops
    # Allocates the heap memory.
    # @param [Integer] nursery_size     the size of the nursery space in MB.
    # @param [Integer] stack_size       the size of the shadow stack space in MB.
    def self.allocate(nursery_size=32, stack_size=8)
        allocate2(nursery_size, stack_size);
    end
  end
end
