require 'test_helper'
require 'yadriggy'

module Yadriggy
  class PrinterTester < Test::Unit::TestCase
    test 'empty printer' do
      pr = Printer.new
      assert_equal('', pr.output)
    end

    test 'printer << a' do
      pr = Printer.new
      pr << 'a'
      assert_equal('a', pr.output)
    end

    test 'printer a nl' do
      pr = Printer.new
      pr << 'a' << :nl
      assert_equal("a\n", pr.output)
    end

    test 'printer a nl nl' do
      pr = Printer.new
      pr << 'a' << :nl << :nl
      assert_equal("a\n\n", pr.output)
    end

    test 'printer a :nl b' do
      pr = Printer.new
      pr << 'a' << :nl << 'b'
      assert_equal("a\nb", pr.output)
    end

    test 'printer a nl b' do
      pr = Printer.new
      pr << 'a'
      pr.nl
      pr << 'b'
      assert_equal("a\nb", pr.output)
    end

    test 'printer a nl down b up nl c' do
      pr = Printer.new(4)
      pr << 'a' << :nl
      pr.down
      pr << 'b' << :nl
      pr.up
      pr << 'c'
      assert_equal("a\n    b\nc", pr.output)
    end

    test 'printer a down nl b up nl c' do
      pr = Printer.new(4)
      pr << 'a'
      pr.down
      pr.nl
      pr << 'b'
      pr.up
      pr.nl
      pr << 'c'
      assert_equal("a\n    \n    b\n\nc", pr.output)
    end

    test 'printer a nl b nl down c nl d nl up e nl f nl' do
      pr = Printer.new(4)
      pr << 'a' << :nl
      pr << 'b' << :nl
      pr.down
      pr << 'c' << :nl
      pr << 'd' << :nl
      pr.up
      pr << 'e' << :nl
      pr << 'f' << :nl
      assert_equal("a\nb\n    c\n    d\ne\nf\n", pr.output)
    end

  end
end
