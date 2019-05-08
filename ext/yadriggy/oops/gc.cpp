// Copyright (C) 2019- Shigeru Chiba.  All rights reserved.

#include <iostream>
#include "gc_impl.hpp"

namespace yadriggy {

YHeader* GC::tenure_space;
uint64_t GC::tenure_space_size; // the number of 64bit words

uint64_t* GC::nursery_space = nullptr;
uint64_t* GC::nursery_space_end;
size_t GC::semi_space_size;
uint64_t* GC::semi_space0;
uint64_t* GC::semi_space1;

uint64_t* YHeader::current_top;
uint64_t* YHeader::current_end;

std::vector<YHeader*> Shadow::shadow_stack;
int64_t Shadow::stack_top;

std::vector<YHeader*> GC::remember_set;
std::vector<YHeader*> GC::promoted_objects;
int GC::current_mark_bit;

uint64_t GC::tenure_space_limit;
int GC::debug_level = 0;
int GC::copy_gc_count;
int GC::mark_sweep_gc_count;

YHeader::~YHeader() {}

boxed_t YHeader::y_hash() {
    return Box::to_boxed(hash_value());
}

boxed_t YHeader::y_eql$(boxed_t obj) {
    return Box::to_boxed(this) == obj ? Box::to_boxed(1) : Box::to_boxed(0);
}

uint64_t* YHeader::allocate_in_semi2(size_t wcount) {
    GC::mark_sweep_gc_if_needed();
    for (int i = 0; i < 3; i++) {
        GC::do_copy_gc();
        uint64_t* new_top = current_top + wcount;
        if (new_top <= current_end)
            return new_top;
    }
    std::cerr << "** GC: memory exhausted" << std::endl;
    throw new GC_MemoryExhausted();
}

void YHeader::add_remember_set() {
    GC::remember_set.push_back(this);
}

void YHeader::add_to_tenure_space() {
    set_gc_generation(0);
    GC::add_to_tenure_space(this);
}

void GC::initialize(size_t young_size, size_t stack_size) {
    semi_space_size = young_size;
    nursery_space = new uint64_t[young_size * 2];
    semi_space0 = &nursery_space[0];
    semi_space1 = &nursery_space[young_size];
    nursery_space_end = &nursery_space[young_size * 2];

    YHeader::current_top = semi_space0;
    YHeader::current_end = semi_space0 + semi_space_size;

    tenure_space = nullptr;
    tenure_space_size = 0;

    Shadow::shadow_stack.reserve(stack_size);
    Shadow::stack_top = -1;

    remember_set.reserve(young_size / 64);
    promoted_objects.reserve(young_size / 1024);
    current_mark_bit = 1;

    tenure_space_limit = young_size * 2;
    copy_gc_count = 0;
    mark_sweep_gc_count = 0;
}

void GC::finalize() {
    if (debug_level > 0)
        std::cerr << "Yadriggy: minor GC " << copy_gc_count << " times, major GC "
                 << mark_sweep_gc_count << " times." << std::endl;

    delete nursery_space;
    nursery_space = nullptr;
    Shadow::shadow_stack.clear();
    Shadow::shadow_stack.shrink_to_fit();
    remember_set.clear();
    remember_set.shrink_to_fit();
    promoted_objects.clear();
    promoted_objects.shrink_to_fit();
}

uint64_t GC::mark_sweep_gc_if_needed() {
    if (tenure_space_limit > tenure_space_size) 
        return 0;
    else {
        uint64_t lives = do_mark_sweep_gc();
        if (tenure_space_limit * 7 / 10 < tenure_space_size)
            tenure_space_limit = tenure_space_size * 3 / 2;
        return lives;
    }
}

// returns the number of the objects in the nursery space.
uint64_t GC::do_copy_gc() {
    ++copy_gc_count;
    if (debug_level > 1)
        std::cerr << "Yadriggy: minor GC" << std::endl;

    uint64_t live_objects = 0;
    uint64_t* alloc_ptr = semi_space1;
    uint64_t* scan_ptr = semi_space1;

    for (int64_t i = Shadow::stack_top; i >= 0; --i) {
        YHeader* p = Shadow::shadow_stack[i];
        if (GC::in_nursery(p)) {
            uint64_t* newobj = copy_and_forward(p, alloc_ptr, live_objects);
            Shadow::shadow_stack[i] = (YHeader*)newobj;
        }
    }

    for (int64_t i = remember_set.size() - 1; i >= 0; --i) {
        YHeader* obj = remember_set[i];
        if (obj != nullptr) {
            std::uint32_t fsize = obj->field_size();
            if (!scan_object<true>(obj, fsize, alloc_ptr, live_objects)) {
                obj->reset_gc_remember();
                remember_set[i] = nullptr;
            }
        }
    }

    scan_promoted_objects(alloc_ptr, live_objects);
    while (scan_ptr < alloc_ptr) {
        YHeader* obj = (YHeader*)scan_ptr;
        std::uint32_t fsize = obj->field_size();
        scan_object<false>(obj, fsize, alloc_ptr, live_objects);
        scan_ptr += fsize + sizeof(YHeader) / sizeof(uint64_t);
        scan_promoted_objects(alloc_ptr, live_objects);
    }

    uint64_t* tmp = semi_space1;
    semi_space1 = semi_space0;
    semi_space0 = tmp;
    YHeader::current_top = alloc_ptr;
    YHeader::current_end = tmp + semi_space_size;

    return live_objects;
}

void GC::scan_promoted_objects(uint64_t*& alloc_ptr, uint64_t& live_objects) {
    while (!promoted_objects.empty()) {
        YHeader* p = promoted_objects.back();
        promoted_objects.pop_back();
        if (scan_object<true>(p, p->field_size(), alloc_ptr, live_objects)) {
            p->set_gc_remember();
            remember_set.push_back(p);
        }
        add_to_tenure_space(p);
    }
}

// returns true if obj has to be remembered after this GC.
template<bool REMEMBER>
bool GC::scan_object(YHeader* obj, std::uint32_t fsize, uint64_t*& alloc_ptr, uint64_t& live_objects) {
    bool remember = false;
    if (obj->has_boxed_value()) {
        for (std::uint32_t i = obj->unbox_size(); i < fsize; ++i) {
            boxed_t v = obj->get_field(i);
            if (Box::is_ptr(v)) {
                YHeader* p = Box::to_ptr<YHeader>(v);
                if (GC::in_nursery(p)) {
                    uint64_t* newobj = copy_and_forward(p, alloc_ptr, live_objects);
                    obj->set_field(i, Box::to_boxed(newobj));
                    remember = has_to_remember<REMEMBER>(newobj, remember);
                }
            }
        }
    }
    return remember;
}

template<bool REMEMBER>
bool GC::has_to_remember(uint64_t* obj, bool remember) {
    return remember | GC::in_nursery(obj);
}

template<>
bool GC::has_to_remember<false>(uint64_t* obj, bool remember) {
    return false;
}

uint64_t* GC::copy_and_forward(YHeader* p, uint64_t*& alloc_ptr, uint64_t& live_objects) {
    uint64_t* newobj = p->forward_pointer();
    if (newobj == nullptr) {
        live_objects++;
        size_t size = p->field_size() + sizeof(YHeader) / sizeof(uint64_t);
        if (p->inc_gc_generation()) {
            tenure_space_size += size;
            newobj = new uint64_t[size];
            copy_object(p, newobj, size);
            promoted_objects.push_back((YHeader*)newobj);
        }
        else {
            newobj = alloc_ptr;
            copy_object(p, newobj, size);
            alloc_ptr = newobj + size;
        }
        p->set_forward_pointer(newobj);
    }
    return newobj;
}

// returns the number of all live objects.
uint64_t GC::do_mark_sweep_gc() {
    ++mark_sweep_gc_count;
    if (debug_level > 1)
        std::cerr << "Yadriggy: major GC (" << tenure_space_size * sizeof(uint64_t) << " bytes)" << std::endl;

    for (int64_t i = remember_set.size() - 1; i >= 0; --i) {
        YHeader* obj = remember_set[i];
        if (obj != nullptr)
            obj->reset_gc_remember();
    }
    remember_set.clear();

    uint64_t live_objects = 0;
    int mark_bit = current_mark_bit;

    std::vector<std::uint32_t> stack_i;
    std::vector<YHeader*> visited;
    visited.reserve(1000);

    for (int64_t i = Shadow::stack_top; i >= 0; --i) {
        YHeader* p = Shadow::shadow_stack[i];
        if (p != nullptr && p->set_gc_mark(mark_bit) != mark_bit) {
            ++live_objects;
            visited.push_back(p);
        }
    }
 
    while (!visited.empty()) {
        YHeader* obj = visited.back();
        visited.pop_back();
        if (obj->has_boxed_value()) {
            std::uint32_t fsize = obj->field_size();
            for (std::uint32_t i = obj->unbox_size(); i < fsize; ++i) {
                boxed_t v = obj->get_field(i);
                if (Box::is_ptr(v)) {
                    YHeader* p = Box::to_ptr<YHeader>(v);
                    if (p != nullptr) {
                        obj->w_barrier(Box::to_boxed(p));
                        if (p->set_gc_mark(mark_bit) != mark_bit) {
                            visited.push_back(p);
                            ++live_objects;
                        }
                    }
                }
            }
        }
    }

    // sweep
    YHeader root(0, 0);
    root.set_next_object(tenure_space);
    YHeader* ptr = &root;
    while (ptr != nullptr) {
        YHeader* next0 = ptr->next_object();
        YHeader* next = next0;
        while (next != nullptr && next->gc_mark() != mark_bit) {
            tenure_space_size -= next->field_size() + sizeof(YHeader) / sizeof(uint64_t);
            YHeader* next2 = next->next_object();
            delete next;
            next = next2;
        }
        if (next != next0)
            ptr->set_next_object(next);
        ptr = next;
    }
    tenure_space = root.next_object();

    current_mark_bit ^= 2;
    return live_objects;
}

}
