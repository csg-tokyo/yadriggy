# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

require 'yadriggy/version'

require 'yadriggy/source_code'
require 'yadriggy/ast'
require 'yadriggy/ast_value'
require 'yadriggy/ast_location'
require 'yadriggy/eval'
require 'yadriggy/eval_all'
require 'yadriggy/algebra'
require 'yadriggy/syntax'
require 'yadriggy/checker'
require 'yadriggy/typecheck'
require 'yadriggy/ruby_typecheck'
require 'yadriggy/ruby_typeinfer'
require 'yadriggy/printer'
require 'yadriggy/pretty_print'

module Yadriggy
  @@debug = 0

  # Current debug level (0, 1, or 2).
  # @return [Integer] the current level.
  def self.debug() @@debug end

  # Sets the current debug level.
  # @param [Integer] level.
  def self.debug=(level)
    @@debug = level
  end
end
