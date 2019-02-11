// Copyright (C) 2019- Shigeru Chiba.  All rights reserved.

#include "ruby.h"

extern void yadriggy_oops_gc_initialize(int, int);
extern void yadriggy_oops_gc_finalize(void);
extern int yadriggy_oops_gc_get_debug(void);
extern void yadriggy_oops_gc_set_debug(int);
extern unsigned int yadriggy_oops_gc_tenure_size(void);
extern unsigned int yadriggy_oops_gc_minor(void);
extern unsigned int yadriggy_oops_gc_major(void);

static VALUE gc_allocate(VALUE klass, VALUE young_size, VALUE stack_size) {
    yadriggy_oops_gc_initialize(FIX2UINT(young_size), FIX2UINT(stack_size));
    return Qnil;
}

static VALUE gc_release(VALUE klass) {
    yadriggy_oops_gc_finalize();
    return Qnil;
}

static VALUE gc_get_debug(VALUE klass) {
    int v = yadriggy_oops_gc_get_debug();
    return INT2FIX(v);
}

static VALUE gc_set_debug(VALUE klass, VALUE level) {
    yadriggy_oops_gc_set_debug(FIX2INT(level));
    return level;
}

static VALUE gc_tenure_size(VALUE klass) {
    unsigned int v = yadriggy_oops_gc_tenure_size();
    return UINT2NUM(v);
}

static VALUE gc_minor_gc(VALUE klass) {
    unsigned int v = yadriggy_oops_gc_minor();
    return UINT2NUM(v);
}

static VALUE gc_major_gc(VALUE klass) {
    unsigned int v = yadriggy_oops_gc_major();
    return UINT2NUM(v);
}

void Init_yadriggy_oops() {
    VALUE yadriggy_module = rb_define_module("Yadriggy");
	VALUE oops_module = rb_define_module_under(yadriggy_module, "Oops");
    rb_define_singleton_method(oops_module, "allocate2", gc_allocate, 2);
    rb_define_singleton_method(oops_module, "release", gc_release, 0);
    rb_define_singleton_method(oops_module, "debug", gc_get_debug, 0);
    rb_define_singleton_method(oops_module, "debug=", gc_set_debug, 1);
    rb_define_singleton_method(oops_module, "tenure_size", gc_tenure_size, 0);
    rb_define_singleton_method(oops_module, "minor_gc", gc_minor_gc, 0);
    rb_define_singleton_method(oops_module, "major_gc", gc_major_gc, 0);
}
