# Copyright (C) 2018- Shigeru Chiba.  All rights reserved.

require 'yadriggy'

module Yadriggy
  module Py
    # The import statement in Python.
    class Import
      @@src = ''
      @@state = 0

      # @api private
      def self.source
        src = @@src
        @@src = ''
        @@state = 0
        src
      end

      # `import` keyword.
      # @param [String|Symbol] name  a module name etc.
      def import(name)
        if @@state == 1 || @@state == 2
          @@src << ', ' << name.to_s
          @@state = 1
        elsif @@state == 3
          @@src << ' import ' << name.to_s
          @@state = 1
        else
          Import.error('import')
        end
        self
      end

      # `as` keyword.
      # @param [String|Symbol] name  an alias.
      def as(name)
        if @@state == 1
          @@src << ' as ' << name.to_s
          @@state = 2
        else
          Import.error('as')
        end
        self
      end

      # `import` keyword.
      # @param [String|Symbol] name  a module name.
      def self.import(name)
        error('import') if @@state == 3
        @@src << "\nimport " << name.to_s
        @@state = 1
        Import.new
      end

      # `from` keyword.
      # @param [String|Symbol] name  a module name.
      def self.from(name)
        error('from') if @@state == 3
        @@src << "\nfrom " << name.to_s
        @@state = 3
        Import.new
      end

      # @api private
      def self.error(name)
        self.source
        raise RuntimeError.new("bad call to Import\##{name}")
      end
    end

    # Convenience module.
    # Use this module by including it.
    module PyImport
      # `import` statement.
      # @param [String|Symbol] name  a module name.
      # @return [Import]
      def pyimport(name)
        Import.import(name)
      end

      # `from ... import` statement.
      # @param [String|Symbol] name  a module name.
      # @return [Import]
      def pyfrom(name)
        Import.from(name)
      end
    end
  end
end
