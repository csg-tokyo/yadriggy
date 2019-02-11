// Copyright (C) 2019- Shigeru Chiba.  All rights reserved.

#include "gc.hpp"

namespace yadriggy {

class GC {
protected:
    static YHeader* tenure_space;
    static uint64_t tenure_space_size; // the number of 64bit words

    static uint64_t* nursery_space;
    static uint64_t* nursery_space_end;
    static size_t semi_space_size;     // the number of 64bit words
    static uint64_t* semi_space0;
    static uint64_t* semi_space1;
 
    static std::vector<YHeader*> promoted_objects;
    static int current_mark_bit;

    static uint64_t tenure_space_limit;     // threshold to start major gc.
    static int copy_gc_count;
    static int mark_sweep_gc_count;

public:
    static int debug_level;
    static std::vector<YHeader*> remember_set;

    /*
     * young_size: the size of the nursery space.
     * stack_size: the size of the shadow stack.
     */
    static void initialize(size_t young_size, size_t stack_size);

    // deallocate heap spaces.
    static void finalize();

    // True if ptr is within the nursery space.
    static bool in_nursery(void* ptr) {
        return nursery_space <= ptr && ptr < nursery_space_end;
    }

    static uint64_t get_tenure_size() { return tenure_space_size; }

    static void add_to_tenure_space(YHeader* obj) {
        obj->set_next_object(tenure_space);
        tenure_space = obj;
    }

    static uint64_t mark_sweep_gc_if_needed();
    static uint64_t do_copy_gc();
    static uint64_t do_mark_sweep_gc();

protected:
    static void scan_promoted_objects(uint64_t*& alloc_ptr, uint64_t& live_objects);

    template<bool REMEMBER>
    static bool scan_object(YHeader* obj, std::uint32_t fsize, uint64_t*& alloc_ptr, uint64_t& live_objects);

    template<bool REMEMBER>
    static bool has_to_remember(uint64_t* obj, bool remember);

    static uint64_t* copy_and_forward(YHeader* p, uint64_t*& alloc_ptr, uint64_t& live_objects);

    static void copy_object(YHeader* obj, uint64_t* dest, size_t size) {
        uint64_t* src = (uint64_t*)obj;
        for (size_t i = 0; i < size; i++)
            dest[i] = src[i];
    }
};

} // end of namespace

