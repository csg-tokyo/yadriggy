require 'test_helper'
require 'yadriggy/ast'
require 'yadriggy/eval'
require 'yadriggy/eval_all'

module Yadriggy
  def self.check_implementations(evaluator)
    evaluator.nil_value(nil)
    evaluator.identifier(Identifier.new([:@ident, "a", [1, 1]]))
    evaluator.const(Const.new([:@const, "P", [6, 4]]))
    evaluator.reserved(Reserved.new([:@kw, "self", [1, 1]]))
    evaluator.super_method(Super.new([:zsuper]))
    evaluator.label(Label.new([:@label, "key:", [1, 1]]))
    evaluator.global_variable(GlobalVariable.new([:@gvar, "$!", [1, 1]]))

    evaluator.instance_variable(InstanceVariable.new([:@ivar, "@x", [1, 1]]))
    evaluator.instance_variable(InstanceVariable.new([:@cvar, "@@x", [1, 1]]))

    evaluator.instance_variable(ASTree.to_node([:var_ref,
                                                 [:@ivar, "@x", [1, 4]]]))
    evaluator.identifier(ASTree.to_node([:var_ref, [:@ident, "a", [1, 19]]]))
    evaluator.identifier(ASTree.to_node([:var_field, [:@ident, "a", [1, 19]]]))

    evaluator.variable_call(VariableCall.new([:vcall,
                                              [:@ident, "b", [1, 1]]]))
    evaluator.number(Number.new([:@int, "3", [1, 1]]))

    paren_expr = [:paren,
                  [[:binary,
                    [:vcall, [:@ident, "a", [1, 1]]],
                    :+,
                    [:vcall, [:@ident, "b", [1, 5]]]]]]
    evaluator.paren(Paren.new(paren_expr))

    array_lit = [:array, [[:@int, "1", [1, 1]], [:@int, "2", [1, 4]]]]
    evaluator.array(ArrayLiteral.new(array_lit))

    evaluator.symbol(SymbolLiteral.new([:symbol, [:@ident, "foo", [1, 1]]]))
    sym = [:symbol_literal, [:symbol, [:@ident, "x", [1, 13]]]]
    evaluator.symbol(SymbolLiteral.new(sym))
    sym2 = [:dyna_symbol, [[:@tstring_content, "=", [161, 49]]]]
    evaluator.symbol(SymbolLiteral.new(sym2))

    str = [:@tstring_content, "str", [1, 1]]
    evaluator.string_literal(StringLiteral.new(str))

    str1 = [:@CHAR, "?\\C-a", [1, 4]]
    evaluator.string_literal(StringLiteral.new(str1))

    str2 = [:string_literal, [:string_content,
            [:@tstring_content, "foo ", [1, 1]],
            [:string_embexpr,
             [[:binary,
               [:vcall, [:@ident, "a", [1, 7]]],
                :+,
                [:vcall, [:@ident, "b", [1, 9]]]]]],
            [:@tstring_content, " bar", [1, 11]]]]
    evaluator.string_interpolation(StringInterpolation.new(str2))

    const_path = [:const_path_ref,
                  [:const_path_ref,
                   [:var_ref, [:@const, "Foo", [1, 4]]],
                   [:@const, "Bar", [1, 9]]],
                  [:@const, "Val", [1, 14]]]
    evaluator.const_path_ref(ConstPathRef.new(const_path))

    const_path2 =  [:const_path_field,
                    [:const_path_ref,
                     [:const_path_ref,
                      [:var_ref, [:@const, "Foo", [1, 0]]],
                      [:@const, "Bar", [1, 5]]],
                     [:@const, "Baz", [1, 10]]],
                    [:@const, "Val", [1, 15]]]
    evaluator.const_path_field(ConstPathField.new(const_path2))

    evaluator.unary(Unary.new([:unary, :-@, [:@int, "3", [1, 1]]]))
    evaluator.unary(Unary.new([:unary, :+@, [:@int, "3", [1, 1]]]))
    evaluator.unary(Unary.new([:unary, :!, [:var_ref,
                                            [:@kw, "false", [5, 24]]]]))
    evaluator.binary(Binary.new([:binary, [:@int, "3", [1, 1]],
                                 :+, [:@int, "4", [1, 1]]]))

    bin2 = [:binary,
            [:vcall, [:@ident, "x", [1, 0]]],
            :*,
            [:paren,
             [[:binary,
               [:vcall, [:@ident, "y", [1, 5]]],
               :+,
               [:vcall, [:@ident, "z", [1, 9]]]]]]]
    evaluator.binary(Binary.new(bin2))

    evaluator.binary(Dots.new([:dot2, [:@int, "1", [1, 1]],
                               [:@int, "2", [1, 4]]]))

    evaluator.binary(Dots.new([:dot3, [:@int, "1", [1, 1]],
                               [:@int, "2", [1, 4]]]))

    evaluator.assign(Assign.new([:assign,
                                 [:var_field, [:@ident, "k", [1, 1]]],
                                 [:@int, "1", [1, 1]]]))
    aref = [:aref,
            [:vcall, [:@ident, "k", [1, 1]]],
            [:args_add_block, [[:@int, "1", [1, 5]]], false]]
    evaluator.array_ref(ArrayRef.new(aref))
    areff = [:aref_field,
            [:vcall, [:@ident, "k", [1, 1]]],
            [:args_add_block, [[:@int, "1", [1, 5]]], false]]
    evaluator.array_ref_field(ArrayRefField.new(areff))

    hash = [:hash,
            [:assoclist_from_args,
             [[:assoc_new, [:@label, "a:", [1, 1]], [:@int, "1", [1, 3]]],
              [:assoc_new, [:@label, "b:", [1, 6]], [:@int, "3", [1, 8]]]]]]
    evaluator.hash(HashLiteral.new(hash))

    call01 = [:method_add_arg,
              [:fcall, [:@ident, "foo", [4, 4]]],
              [:arg_paren, [:args_add_block, [[:@int, "1", [4, 8]]], false]]]
    evaluator.call(Call.new(call01))
    call02 = [:method_add_arg,
              [:fcall, [:@ident, "foo", [5, 4]]],
              [:arg_paren,
               [:args_add_block,
                [[:@int, "1", [5, 8]], [:@int, "2", [5, 11]]],
                [:vcall, [:@ident, "p", [5, 15]]]]]]
    evaluator.call(Call.new(call02))
    call03 = [:method_add_arg, [:fcall, [:@ident, "foo", [6, 4]]],
                                [:arg_paren, nil]]
    evaluator.call(Call.new(call03))
    call04 =  [:call, [:var_ref, [:@const, "P", [6, 4]]], :"::",
               [:@ident, "foo", [6, 7]]]
    evaluator.call(Call.new(call04))

    cmd01 = [:command, [:@ident, "foo", [1, 0]],
             [[:command, [:@ident, "bar", [1, 4]],
              [:args_add_block,
               [[:vcall, [:@ident, "baz", [1, 8]]]], false]]]]
    evaluator.call(Command.new(cmd01))

    cmd02 = [:command, [:@ident, "foo", [1, 0]],
            [:args_add_block, [[:vcall, [:@ident, "bar", [1, 4]]]], false]]
    evaluator.call(Command.new(cmd02))

    cmd03 = [:command_call,
             [:vcall, [:@ident, "foo", [1, 0]]],
              :".",
              [:@ident, "baz", [1, 4]],
             [[:command,
              [:@ident, "bar", [1, 8]],
              [:args_add_block,
               [[:vcall, [:@ident, "poi", [1, 12]]]], false]]]]
    evaluator.call(Command.new(cmd03))

    ifexpr = [:if, [:vcall, [:@ident, "b", [1, 3]]],
              [[:@int, "1", [1, 10]]], nil]
    evaluator.conditional(Conditional.new(ifexpr))

    elsifexpr = [:if,
      [:binary, [:vcall, [:@ident, "i", [1, 3]]], :>, [:@int, "0", [1, 7]]],
      [[:@int, "1", [2, 2]]],
      [:elsif,
        [:binary, [:vcall, [:@ident, "i", [3, 6]]], :==,
          [:@int, "3", [3, 11]]],
        [[:@int, "2", [4, 2]]],
        [:elsif,
          [:binary, [:vcall, [:@ident, "i", [5, 6]]], :==,
            [:@int, "4", [5, 11]]],
          [[:@int, "3", [6, 2]]],
          [:else, [[:@int, "4", [8, 2]]]]]]]
    evaluator.conditional(Conditional.new(elsifexpr))

    unlessexpr = [:unless,
                  [:vcall, [:@ident, "b", [1, 7]]],
                  [[:@int, "1", [1, 14]]],
                  [:else, [[:@int, "2", [1, 21]]]]]
    evaluator.conditional(Conditional.new(unlessexpr))

    if3 = [:ifop, [:vcall, [:@ident, "b", [1, 4]]],
           [:@int, "1", [1, 8]],
           [:@int, "3", [1, 12]]]
    evaluator.conditional(Conditional.new(if3))

    if4 = [:if_mod,
           [:vcall, [:@ident, "b", [1, 9]]],
           [:assign, [:var_field, [:@ident, "x", [1, 0]]],
                     [:@int, "3", [1, 4]]]]
    evaluator.conditional(Conditional.new(if4))

    if5 = [:unless_mod,
           [:vcall, [:@ident, "b", [1, 9]]],
           [:assign, [:var_field, [:@ident, "x", [1, 0]]],
                     [:@int, "3", [1, 4]]]]
    evaluator.conditional(Conditional.new(if5))

    loop1 = [:while,
      [:binary,
       [:var_ref, [:@ident, "j", [3, 10]]],
       :<,
       [:var_ref, [:@ident, "i", [3, 14]]]],
      [[:opassign,
        [:var_field, [:@ident, "j", [4, 6]]],
        [:@op, "+=", [4, 8]],
        [:@int, "1", [4, 11]]]]]
    evaluator.loop(Loop.new(loop1))

    loop2 =  [:until,
      [:binary,
       [:var_ref, [:@ident, "j", [6, 10]]],
       :>,
       [:var_ref, [:@ident, "i", [6, 14]]]],
      [[:opassign,
        [:var_field, [:@ident, "j", [7, 6]]],
        [:@op, "+=", [7, 8]],
        [:@int, "1", [7, 11]]]]]
    evaluator.loop(Loop.new(loop2))

    loop3 = [:while_mod,
      [:binary,
       [:var_ref, [:@ident, "j", [9, 17]]],
       :<,
       [:var_ref, [:@ident, "i", [9, 21]]]],
      [:opassign,
       [:var_field, [:@ident, "j", [9, 4]]],
       [:@op, "+=", [9, 6]],
       [:@int, "1", [9, 9]]]]
    evaluator.loop(Loop.new(loop3))

    loop4 = [:until_mod,
      [:binary,
       [:var_ref, [:@ident, "j", [10, 17]]],
       :>,
       [:var_ref, [:@ident, "i", [10, 21]]]],
      [:opassign,
       [:var_field, [:@ident, "j", [10, 4]]],
       [:@op, "+=", [10, 6]],
       [:@int, "1", [10, 9]]]]
    evaluator.loop(Loop.new(loop4))

    for_loop = [:for,
      [:var_field, [:@ident, "k", [11, 8]]],
      [:paren,
       [[:dot2,
         [:@int, "0", [11, 14]],
         [:var_ref, [:@ident, "i", [11, 17]]]]]],
      [[:opassign,
        [:var_field, [:@ident, "j", [12, 6]]],
        [:@op, "+=", [12, 8]],
        [:var_ref, [:@ident, "k", [12, 11]]]]]]
    evaluator.for_loop(ForLoop.new(for_loop))

    for_loop2 = [:for,
      [[:@ident, "i", [1, 4]], [:@ident, "j", [1, 7]]],
      [:array,
        [[:@int, "1", [1, 13]], [:@int, "2", [1, 16]], [:@int, "3", [1, 19]]]],
      [[:binary,
          [:var_ref, [:@ident, "i", [2, 2]]],
          :+,
          [:var_ref, [:@ident, "j", [2, 6]]]]]]
    evaluator.for_loop(ForLoop.new(for_loop2))

    break_jump = [:break, []]
    evaluator.break_out(Break.new(break_jump))

    break_jump2 = [:break, [:args_add_block, [[:@int, "3", [1, 6]]], false]]
    evaluator.break_out(Break.new(break_jump2))

    next_jump = [:next,
      [:args_add_block, [[:@int, "3", [1, 5]], [:@int, "4", [1, 8]]], false]]
    evaluator.break_out(Break.new(next_jump))

    redo_jump = [:redo]
    evaluator.break_out(Break.new(redo_jump))

    retry_jump = [:retry]
    evaluator.break_out(Break.new(retry_jump))

    ret = [:return, [:args_add_block,
                     [[:@int, "1", [1, 7]], [:@int, "2", [1, 10]]], false]]
    evaluator.return_values(Return.new(ret))

    ret2 = [:return0]
    evaluator.return_values(Return.new(ret2))

    blk = [:brace_block,
           [:block_var, [:params, nil, nil, nil, nil, nil, nil, nil], nil],
           [[:@int, "0", [1, 11]]]]
    evaluator.block(Block.new(blk))

    # lambda {}
    lambda_expr = [:method_add_block,
                   [:method_add_arg, [:fcall, [:@ident, "lambda", [1, 0]]],
                    []], [:brace_block, nil, [[:void_stmt]]]]
    evaluator.call(Call.new(lambda_expr))

    field_access =  [:field, [:var_ref, [:@const, "Foo", [1, 0]]],
                     :".",
                     [:@ident, "x", [1, 4]]]
    evaluator.call(Call.new(field_access))

    lambda2 = [:lambda,[:params, nil, nil, nil, nil, nil, nil, nil],
               [[:vcall, [:@ident, "x", [1, 4]]]]]
    evaluator.lambda_expr(Lambda.new(lambda2))

    lambda3 = [:lambda,
               [:paren, [:params, [[:@ident, "x", [1, 3]]],
                         nil, nil, nil, nil, nil, nil]],
               [[:var_ref, [:@ident, "x", [1, 8]]]]]
    evaluator.lambda_expr(Lambda.new(lambda3))

    begin_end = [:begin,
                 [:bodystmt,
                  [[:@int, "1", [3, 4]]],
                  [:rescue,
                   nil,
                   [:var_field, [:@ident, "e", [4, 12]]],
                   [[:@int, "2", [5, 4]]],
                   [:rescue,
                    nil,
                    [:var_field, [:@ident, "e2", [6, 12]]],
                    [[:@int, "3", [7, 4]]],
                    nil]],
                  nil,
                  nil]]
    evaluator.begin_end(BeginEnd.new(begin_end))

    def_src =[:def, [:@ident, "foo", [1, 6]],
              [:paren,
               [:params, [[:@ident, "i", [1, 10]]], nil, nil, nil, nil,
                          nil, nil]],
              [:bodystmt,
               [[:@int, "1", [2, 4]]],
               [:rescue,
                [[:var_ref, [:@const, "Error", [3, 9]]]],
                [:var_field, [:@ident, "evar", [3, 18]]],
                [[:var_ref, [:@ident, "evar", [4, 4]]]],
                nil],
               [:else, [[:@int, "1", [6, 4]]]],
               [:ensure, [[:@int, "2", [8, 4]]]]]]
    evaluator.define(Def.new(def_src))

    def_src2 = [:def, [:@ident, "foo", [1, 6]],
                [:params, [[:@ident, "i", [1, 10]]], nil, nil, nil,
                           nil, nil, nil],
                [:bodystmt, [[:var_ref, [:@ident, "i", [2, 4]]]],
                 nil, nil, nil]]
    evaluator.define(Def.new(def_src2))

    defs_src3 = [:defs,
                 [:var_ref, [:@kw, "self", [1, 4]]],
                 [:@period, ".", [1, 8]],
                 [:@ident, "foo", [1, 9]],
                 [:paren, [:params, nil, nil, nil, nil, nil, nil, nil]],
                 [:bodystmt, [[:void_stmt]], nil, nil, nil]]
    evaluator.define(Def.new(defs_src3))

    moduledef = [:module, [:const_ref, [:@const, "A", [1, 7]]],
                          [:bodystmt, [[:void_stmt]], nil, nil, nil]]

    evaluator.module_def(ModuleDef.new(moduledef))

    classdef = [:class, [:const_path_ref,
                         [:var_ref, [:@const, "A", [1, 6]]],
                         [:@const, "B", [1, 9]]],
                        [:const_path_ref,
                         [:var_ref, [:@const, "A", [1, 13]]],
                         [:@const, "C", [1, 16]]],
                        [:bodystmt, [[:void_stmt]], nil, nil, nil]]
    evaluator.class_def(ClassDef.new(classdef))

    sclassdef = [:sclass,
                 [:var_ref, [:@kw, "self", [1, 9]]],
                 [:bodystmt, [[:void_stmt]], nil, nil, nil]]
    evaluator.singular_class_def(SingularClassDef.new(sclassdef))

    prog = [:program,
            [[:binary,
              [:vcall, [:@ident, "x", [1, 0]]],
              :+,
              [:vcall, [:@ident, "y", [1, 2]]]],
             [:binary, [:vcall, [:@ident, "z", [2, 0]]], :==,
              [:@int, "0", [2, 5]]]]]

    evaluator.program(Program.new(prog))
  end

  class EvalTester < Test::Unit::TestCase
    test 'check all the methods are implemented' do
      e = EvalAll.new
      assert_nothing_raised(NotImplementedError,
                            'some methods are not implemented ') do
        Yadriggy.check_implementations(e)
      end
    end
  end
end

