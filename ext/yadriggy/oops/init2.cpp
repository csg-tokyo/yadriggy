// Copyright (C) 2019- Shigeru Chiba.  All rights reserved.

#include "gc_impl.hpp"

extern "C" {
    void yadriggy_oops_gc_initialize(int young_size, int stack_size);
    void yadriggy_oops_gc_finalize();
    int yadriggy_oops_gc_get_debug();
    void yadriggy_oops_gc_set_debug(int level);
    unsigned int yadriggy_oops_gc_tenure_size();
    unsigned int yadriggy_oops_gc_minor();
    unsigned int yadriggy_oops_gc_major();
}

void yadriggy_oops_gc_initialize(int young_size, int stack_size) {
    yadriggy::GC::initialize(young_size * 1024 * 1024 / sizeof(uint64_t),
                             stack_size * 1024 * 1024 / sizeof(uint64_t));
}

void yadriggy_oops_gc_finalize() {
    yadriggy::GC::finalize();
}

int yadriggy_oops_gc_get_debug() {
    return yadriggy::GC::debug_level;
}

void yadriggy_oops_gc_set_debug(int level) {
    yadriggy::GC::debug_level = level;
}

unsigned int yadriggy_oops_gc_tenure_size() {
    return (unsigned int)(yadriggy::GC::get_tenure_size() * sizeof(uint64_t)
                          / (1024 * 1024));
}

unsigned int yadriggy_oops_gc_minor() {
    return (unsigned int)yadriggy::GC::do_copy_gc();
}

unsigned int yadriggy_oops_gc_major() {
    return (unsigned int)yadriggy::GC::do_mark_sweep_gc();
}
