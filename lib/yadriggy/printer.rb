# Copyright (C) 2017- Shigeru Chiba.  All rights reserved.

module Yadriggy

  # A helper class for pretty printing.
  #
  class Printer
    # @param [Integer] indent  the indent size.  The default value is 2.
    def initialize(indent=2)
      @text = ''
      @level = 0
      @linebreak = false
      @indent = ' ' * indent
    end

    # Returns the output stream.
    #
    def output()
      add_newline if @linebreak
      @text
    end

    # Increase the indentation level.
    #
    def down
      @level += 1
      add_newline
    end

    # Decrease the indentation level.
    #
    def up
      @level -= 1
      add_newline
    end

    # Starts a new line.
    #
    def nl
      @linebreak = true
    end

    # Prints the text.  If `code` is `:nl`, a line break is printed.
    #
    # @param [String|:nil] code  the text.
    def << (code)
      add_newline if @linebreak
      if code == :nl
        @linebreak = true
      else
        @text << code.to_s
      end
      self
    end

    private

    def add_newline()
      @text << "\n"
      @level.times { @text << @indent }
      @linebreak = false
    end
  end

  # Pretty printer to a file.
  #
  class FilePrinter < Printer
    # @return [String] the file name.
    attr_reader :file_name

    # @param [String] file_name  the file name.
    def initialize(file_name)
      super()
      @text = File.open(file_name, 'w')
      @file_name = file_name
    end

    def close
      @text.close
    end
  end
end
