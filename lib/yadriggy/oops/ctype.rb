# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'yadriggy'
require 'yadriggy/oops/ffi'

module Yadriggy
  module Oops
    # Types availalbe in C code.
    module CType
      def typedecl(arg) end
      def arrayof(t) t end

      # Single-precision floating point numbers.
      # This is used only as a type name.
      # Note that `Float` represents double-precision floating point numbers.
      # Do not make an instance.
      class Float32
      end

      # @api private
      # An alias `RubyClass[Float32]`.
      Float32Type = RubyClass[Float32]

      Void = Yadriggy::Void           # void
      Int = Integer                   # int32_t

      IntArray = Yadriggy::Oops::IntArray
      FloatArray = Yadriggy::Oops::FloatArray
      Float32Array = Yadriggy::Oops::Float32Array

      # Types available only as a value of instance variable.
      class IvarObj
        include Yadriggy::Oops::CType
      end

      # @api private
      # Array type available only in C code.
      # See also {IntArray} and {FloatArray} in `ffi.rb`.
      class CArray < IvarObj
        # @api private
        def typedecl(arg) end

        # debug mode.
        attr_accessor :debug

        # @return [Array<Integer>] sizes  array size.
        attr_reader :sizes

        # @param [Array<Integer>] sizes  size of each dimension.
        def initialize(*sizes)
          raise 'unknown array size' unless sizes.size > 0
          @sizes = sizes
          @debug = false
        end

        # @api private
        # @abstract
        # @return [Type] the element type.
        def type()
          Undef
        end

        # @api private
        def check_range(indexes)
          raise 'wrong number of indexes' unless indexes.size == @sizes.size
          indexes.each_index do |i|
            if indexes[i] >= @sizes[i]
              raise "out of range: #{self.to_s}[#{indexes[i]}]"
            end
          end
        end
      end

      # Array of 32bit integers available only in C.
      #
      # @see IntArray
      class IntCArray < CArray
        def type()
          RubyClass::Integer
        end

        def [](*indexes)
          typedecl foreign: Int
          check_range(indexes)
          raise 'IntCArray is not available in Ruby' unless @debug
        end

        def []=(*indexes)
          typedecl foreign: Void
          check_range(indexes[0, indexes.size - 1])
          raise 'IntCArray is not available in Ruby' unless @debug
        end
      end

      # Array of floating point numbers available only in C.
      #
      # @see FloatArray
      class FloatCArray < CArray
        def type()
          RubyClass::Float
        end

        def [](*indexes)
          typedecl foreign: Float
          check_range(indexes)
          raise 'FloatCArray is not available in Ruby' unless @debug
        end

        def []=(*indexes)
          typedecl foreign: Void
          check_range(indexes[0, indexes.size - 1])
          raise 'FloatCArray is not available in Ruby' unless @debug
        end
      end

    end
  end
end
