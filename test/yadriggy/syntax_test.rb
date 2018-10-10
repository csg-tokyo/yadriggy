require 'test_helper'
require 'yadriggy/syntax.rb'
require 'yadriggy/ast_test2.rb'

module Yadriggy
  class SyntaxTester < Test::Unit::TestCase
    test 'syntax empty' do
      syn = Yadriggy::define_syntax do
        # any code causes a syntax error.
      end

      assert_false(syn.check(Yadriggy::reify {}.tree.body))
    end

    test 'syntax nil' do
      syn = Yadriggy::define_syntax do
        Reserved <= { name: 'nil' }
      end
      assert(syn.check(Yadriggy::reify { nil }.tree.body))
      assert_false(syn.check(Yadriggy::reify { self }.tree.body))
      assert_false(syn.check(Yadriggy::reify { foo }.tree.body))
    end

    test 'syntax string' do
      syn = Yadriggy::define_syntax do
        Name <= {name: String }
      end
      assert(syn.check(Yadriggy::reify { foo }.tree.body))
    end

    test 'syntax user type' do
      syn = Yadriggy::define_syntax do
        foo_var <= Name + {name: 'foo' }
        Block   <= { body: foo_var }
      end
      assert(syn.check(Yadriggy::reify { foo }.tree))
      assert_false(syn.check(Yadriggy::reify { bar }.tree))
    end

    test 'check usertype' do
      syn = Yadriggy::define_syntax do
        foo_var <= Name + {name: 'foo' }
      end
      ast = Yadriggy::reify { foo }.tree.body
      assert(syn.check_usertype(:foo_var, ast))
      assert_false(syn.check(ast))   # since no rule for Name
    end

    test 'syntax Assign < Binary' do
      syn = Yadriggy::define_syntax do
        assign <= Assign + { right: Number }
        Block   <= { body: assign }
      end
      assert(syn.check(Yadriggy::reify { foo = 3 }.tree))        # Assign
      assert_false(syn.check(Yadriggy::reify { foo + 3 }.tree))  # Binary
    end

    test 'syntax hash or' do
      syn = Yadriggy::define_syntax do
        Name <= {name: 'foo' | 'bar' }
        Block   <= { body: Name }
      end
      assert(syn.check(Yadriggy::reify { foo }.tree))
      assert(syn.check(Yadriggy::reify { bar }.tree))
      assert_false(syn.check(Yadriggy::reify { baz }.tree))
      assert_false(syn.check(Yadriggy::reify { 3 }.tree))
    end

    test 'syntax hash symbol literal' do
      syn = Yadriggy::define_syntax do
        Binary <= { op: :'=' | :+ }
        Block  <= { body: Binary }
      end
      assert(syn.check(Yadriggy::reify { 3 + x }.tree))
      assert(syn.check(Yadriggy::reify { x = y + z }.tree))
      assert_false(syn.check(Yadriggy::reify { 3 - x }.tree))
      assert_false(syn.check(Yadriggy::reify { 3 - x * y }.tree))
    end

    test 'syntax hash nil' do
      syn = Yadriggy::define_syntax do
        Block  <= { block_param: nil }
      end
      assert(syn.check(Yadriggy::reify {|i| foo }.tree))
      assert_false(syn.check(Yadriggy::reify {|&blk| foo }.tree))
    end

    test 'syntax hash []' do
      syn = Yadriggy::define_syntax do
        Block  <= { params: [] }
      end
      assert(syn.check(Yadriggy::reify { foo }.tree))
      assert_false(syn.check(Yadriggy::reify {|i| foo }.tree))
    end

    test 'syntax hash [] or nil' do
      syn = Yadriggy::define_syntax do
        Block  <= { params: nil }  # params is an array.
      end
      assert(syn.check(Yadriggy::reify { foo }.tree))
      assert_false(syn.check(Yadriggy::reify {|i| foo }.tree))
    end

    test 'syntax hash [Name]' do
      syn = Yadriggy::define_syntax do
        Block  <= { params: [Name] }
      end
      assert(syn.check(Yadriggy::reify {|| foo }.tree))
      assert(syn.check(Yadriggy::reify {|i| foo }.tree))
      assert(syn.check(Yadriggy::reify {|i,j| foo }.tree))
      assert(syn.check(Yadriggy::reify { foo }.tree))
    end

    test 'syntax hash wrong name' do
      syn = Yadriggy::define_syntax do
        Block  <= { param: [Name] }
      end
      assert_raise do
        syn.check(Yadriggy::reify {|i| foo }.tree)
      end
    end

    test 'syntax hash paren' do
      syn = Yadriggy::define_syntax do
        Conditional <= { op: Symbol, cond: Binary, then: Number,
                         else: (Number) }
        Block  <= { body: Conditional }
      end
      assert(syn.check(Yadriggy::reify {
                         if i > 3
                            7
                         else
                            8
                         end
                       }.tree))
      assert(syn.check(Yadriggy::reify {
                         if i > 3
                            7
                         end
                       }.tree))
    end

    test 'syntax or nil ' do
      syn = Yadriggy::define_syntax do
        else_part <= Number | nil
        Conditional <= { op: Symbol, cond: Binary, then: Number,
                         else: else_part }
        Block  <= { body: Conditional }
      end
      assert(syn.check(Yadriggy::reify {
                         if i > 3
                            7
                         else
                            8
                         end
                       }.tree))
      assert(syn.check(Yadriggy::reify {
                         if i > 3
                            7
                         end
                       }.tree))
    end

    test 'syntax or' do
      syn = Yadriggy::define_syntax do
        foo_var <= Number | Name
        Block   <= { body: foo_var }
      end
      assert(syn.check(Yadriggy::reify { foo }.tree))
      assert(syn.check(Yadriggy::reify { 3 }.tree))
      assert_false(syn.check(Yadriggy::reify { :foo }.tree))
    end

    # The given AST matches a rule X <= Y if the type of the AST root
    # is X or a subtype of X.  If it matches multiple rules, it selects
    # a rule Z <= ... such that Z is the most specific type.
    test 'syntax subtype' do
      syn = Yadriggy::define_syntax do
        expr    <= Name | Number
        Reserved <= { name: 'self' }
        Block   <= { body: expr }
      end
      assert(syn.check(Yadriggy::reify { 3 }.tree))
      assert(syn.check(Yadriggy::reify { foo }.tree))
      assert(syn.check(Yadriggy::reify { self }.tree))
      assert_false(syn.check(Yadriggy::reify { true }.tree))
    end

    # If a rule is X <= ..., where X is a user type,
    # it specifies an alias.  All the occurrences of X in the right
    # hand side of other rules are expanded to the right hand side
    # of that rule X <= ...
    #
    # If a rule is X <= Y or X <= Y + ..., where both X and Y are
    # non-user types, an AST satisfying this rule also has to
    # satisfy a rule Y <= ... if it exits.
    #
    # If an AST satisfies a rule X <= ... { f: Y, ... }, the value of
    # its f has to have a type Y and satisfy a rule Z <= ...,
    # where Z is f's type or its supertype.
    #
    test 'syntax subtype 2' do
      syn = Yadriggy::define_syntax do
        Block   <= { body: expr }
        expr    <= Reserved
        Reserved <= Name
        Name <= {name: 'true' }
      end
      assert(syn.check(Yadriggy::reify { true }.tree))
      assert_false(syn.check(Yadriggy::reify { false }.tree))
    end

    test 'syntax subtype 3' do
      syn = Yadriggy::define_syntax do
        Block   <= { body: expr }
        expr    <= Reserved
        Name <= {name: 'true' }
      end
      assert(syn.check(Yadriggy::reify { true }.tree))
      assert_false(syn.check(Yadriggy::reify { false }.tree))
    end

    test 'syntax subtype 4' do
      syn = Yadriggy::define_syntax do
        Block   <= { body: expr }
        expr    <= Name
        Reserved <= { name: 'true' }
      end
      assert(syn.check(Yadriggy::reify { foo }.tree))
      assert(syn.check(Yadriggy::reify { true }.tree))
      assert_false(syn.check(Yadriggy::reify { false }.tree))
    end

    test 'syntax subtype 5' do
      syn = Yadriggy::define_syntax do
        Block   <= { body: expr }
        expr    <= Name
        Reserved <= nil		# not available
      end
      assert(syn.check(Yadriggy::reify { foo }.tree))
      assert_false(syn.check(Yadriggy::reify { true }.tree))
    end

    test 'syntax subtype 6' do
      syn = Yadriggy::define_syntax do
        Block   <= { body: expr }
        expr    <= Name
      end
      assert(syn.check(Yadriggy::reify { foo }.tree))
      assert(syn.check(Yadriggy::reify { true }.tree))
    end

    test 'syntax subtype 7' do
      syn = Yadriggy::define_syntax do
        Block   <= { body: expr }
        expr    <= Reserved
      end
      assert_false(syn.check(Yadriggy::reify { foo }.tree))
      assert(syn.check(Yadriggy::reify { true }.tree))
    end

    test 'an alias of array' do
      assert_raise do
        syn = Yadriggy::define_syntax do
          Block    <= { body: Return }
          Return   <= { values: ret_expr }
          ret_expr <= [ expr ]      # an array literal is not available here.
        end
      end
    end

    test 'a single-element array' do
      syn = Yadriggy::define_syntax do
        Block    <= { body: Return }
        Return   <= { values: Number }    # not { values: [ Number ] }
      end
      assert(syn.check(Yadriggy::reify { return 1 }.tree))
      assert_false(syn.check(Yadriggy::reify { return 1, 2 }.tree))
    end

    test 'pair array and empty pair-array' do
      syn = Yadriggy::define_syntax do
        Block    <= { optionals: [ Identifier * Number ] }
      end
      assert(syn.check(Yadriggy::reify {|i=3| i }.tree))
      assert(syn.check(Yadriggy::reify {|| 3 }.tree))
      assert(syn.check(Yadriggy::reify { 3 }.tree))
    end

    test 'single-value return or void return' do
      syn = Yadriggy::define_syntax do
        Block    <= { body: Return }
        Return    <= { values: Number | nil }
      end
      assert(syn.check(Yadriggy::reify { return }.tree))
      assert(syn.check(Yadriggy::reify { return 3 }.tree))
      assert_false(syn.check(Yadriggy::reify { return 3, 4 }.tree))

      syn2 = Yadriggy::define_syntax do
        Block    <= { body: Return }
        Return    <= { values: [Number] }
      end

      assert(syn2.check(Yadriggy::reify { return }.tree))
      assert(syn2.check(Yadriggy::reify { return 3 }.tree))
      assert(syn2.check(Yadriggy::reify { return 3, 4 }.tree))  # pass
    end

    test 'array elements' do
      # 1st is Number and the rest are Name.
      syn = Yadriggy::define_syntax do
        ArrayLiteral   <= { elements: [Number, Name] }
      end
      assert(syn.check(Yadriggy::reify { [0, var] }.tree.body))
      assert(syn.check(Yadriggy::reify { [0, var, var] }.tree.body))
      assert_false(syn.check(Yadriggy::reify { [var, var, var] }.tree.body))
      assert_false(syn.check(Yadriggy::reify { [0, var, 1] }.tree.body))
    end

    test 'array elements 2' do
      # 1st is Number, 2nd is Number, and the rest are Name.
      syn = Yadriggy::define_syntax do
        ArrayLiteral   <= { elements: [Number, Number, Name] }
      end
      assert(syn.check(Yadriggy::reify { [0, 1, var] }.tree.body))
      assert(syn.check(Yadriggy::reify { [0, 1, var, var] }.tree.body))
      assert_false(syn.check(Yadriggy::reify { [var, 1, var, var] }.tree.body))
      assert_false(syn.check(Yadriggy::reify { [0, var, var, var] }.tree.body))
      assert_false(syn.check(Yadriggy::reify { [0, 1, 2, var] }.tree.body))
    end

    test 'array elements 3' do
      # 1st is Number, 2nd is Number, and the rest are Name.
      syn = Yadriggy::define_syntax do
        ArrayLiteral   <= { elements: [(Number), Name] }
      end
      assert(syn.check(Yadriggy::reify { [0, var] }.tree.body))
      assert(syn.check(Yadriggy::reify { [0, var, var] }.tree.body))
      assert(syn.check(Yadriggy::reify { [var, var, var] }.tree.body))
      assert(syn.check(Yadriggy::reify { [var] }.tree.body))
      assert_false(syn.check(Yadriggy::reify { [0, 1] }.tree.body))
    end

    test 'children are not checked' do
      syn = Yadriggy::define_syntax do
        Binary <= { op: :+ }
        Unary = { op: :! }
      end

      # Since the rule is 'Binary <= {op: :+}',
      # Binary#right is not checked.
      assert(syn.check(Yadriggy::reify { a + !b }.tree.body))  # !b
      assert(syn.check(Yadriggy::reify { !b }.tree.body))

      assert(syn.check(Yadriggy::reify { a + -b }.tree.body))  # -b
      assert_false(syn.check(Yadriggy::reify { -b }.tree.body))

      syn2 = Yadriggy::define_syntax do
        Binary <= { op: :+, right: Unary }
        Unary = { op: :! }
      end

      assert(syn2.check(Yadriggy::reify { a + !b }.tree.body))
      assert_false(syn2.check(Yadriggy::reify { a + -b }.tree.body)) # fail
    end

    test 'missing code fragment (else-expr must be given)' do
      syn = Yadriggy::define_syntax do
        Block       <= { body: Conditional }
        expr    <= Name | Binary
        Conditional <= { cond: expr, then: expr,
                         all_elsif: nil, else: expr }
      end
      ast = Yadriggy::reify do |i|
        if i
          i = 3
        end
      end

      assert_false(syn.check(ast.tree))
    end

    test 'user type' do
      syn = Yadriggy::define_syntax do
        Block   <= { body: expr }
        expr    <= name | VariableCall | Number
        name    <= VariableCall + { name: "foo" }
      end

      tree0 = Yadriggy::reify { bar }.tree
      assert(syn.check(tree0))
      assert_equal(:expr, tree0.body.usertype)

      tree1 = Yadriggy::reify { foo }.tree
      assert(syn.check(tree1))
      assert_equal(:name, tree1.body.usertype)

      tree2 = Yadriggy::reify { 3 }.tree
      assert(syn.check(tree2))
      assert_equal(:expr, tree2.body.usertype)
    end

    test 'user type 2' do
      syn = Yadriggy::define_syntax do
        Block   <= { body: expr }
        expr    <= name | VariableCall | Number
        HashLiteral = { pairs: [ Label * Number ] }
        foo_name <= Identifier + { name: "foo" }
        name    <= Call + { name: foo_name, args: [ HashLiteral ] }
      end

      tree0 = Yadriggy::reify { foo a: 3 }.tree
      assert(syn.check(tree0))
      assert_not_equal(:expr, tree0.body.usertype)
      assert_equal(:name, tree0.body.usertype) # since 'expr <= name'
      assert_equal(nil, tree0.body.args[0].usertype)
    end

    test 'check check_usertype' do
      syn = Yadriggy::define_syntax do
        Binary <= { op: :'=' | :+ }
        user_bin <= Binary + { op: :'=' }
      end
      tree0 = Yadriggy::reify { a = 3 }
      tree1 = Yadriggy::reify { a + 3 }

      assert(syn.check_usertype(:user_bin, tree0.tree.body))
      assert_false(syn.check_usertype(:user_bin, tree1.tree.body))
    end

    test 'add rules' do
      syn = Yadriggy::define_syntax do
        Binary <= { op: :+, right: Number | Unary }
      end
      tree0 = Yadriggy::reify { a - 3 }
      tree1 = Yadriggy::reify { a + -3 }
      tree2 = Yadriggy::reify { -3 }
      tree3 = Yadriggy::reify { a + 3 }

      assert_false(syn.check(tree0.tree.body))
      assert(syn.check(tree1.tree.body))
      assert(syn.check(tree3.tree.body))

      syn.add_rules do
        Unary <= { op: :! }
      end
      assert_false(syn.check(tree0.tree.body))
      assert_false(syn.check(tree1.tree.body))
      assert_false(syn.check(tree2.tree.body))

      syn2 = Yadriggy::define_syntax do
        Binary <= { op: :'=' | :+ | :- }
      end
      assert(syn2.check(tree0.tree.body))
      assert(syn2.check(tree1.tree.body))
      assert(syn2.check(tree3.tree.body))
      syn2.add_rules(syn)
      assert_false(syn.check(tree0.tree.body))

      syn3 = Yadriggy::define_syntax do
        Unary <= { op: :! }
      end
      syn2.add_rules(syn3)
      assert_false(syn2.check(tree1.tree.body))
    end

    test 'sample code' do
      syn = Yadriggy::define_syntax do
        Binary <= { op: :+ | :-, left: expr, right: expr }
        expr   <= Binary | Number
        Block  <= { body: expr }
      end

      assert syn.check(Yadriggy::reify { 1 }.tree)
      assert syn.check(Yadriggy::reify { 1 + 2 }.tree)
      assert syn.check(Yadriggy::reify { 1 + 2 - 3 }.tree)
      assert_false syn.check(Yadriggy::reify { 1 * 2 - 3 }.tree)
      assert_false syn.check(Yadriggy::reify { 1 + a }.tree)
    end

    test 'various ruby code syntax' do
      syn = Yadriggy::Syntax.ruby_syntax
      Yadriggy::check_all_asts do |a|
        unless syn.check(a.tree)
          puts syn.error
          pp a.tree
          assert(false, "syntax error #{a.tree.source_location_string}")
        end
      end
    end

  end
end
