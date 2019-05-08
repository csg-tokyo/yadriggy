// Copyright (C) 2019- Shigeru Chiba.  All rights reserved.

#include <cstdint>
#include <cmath>
#include <vector>

namespace yadriggy {
/*
         11 bits     52 bits
   S EEE EEEE EEEE FFFF .. FF
   x xxx xxxx xxxx xxxx .. xx    : 64 bit float (E != 11 .. 11)
   x 111 1111 1111 0000 .. 00    : +-Infinity
   x 111 1111 1111 0100 .. 00    : sNaN
   x 111 1111 1111 1000 .. 00    : qNaN
   1 111 1111 1111 1110 .. xx    : 48 bits of integer
   1 111 1111 1111 1111 .. xx    : 48 bits of address

   before storing, 1 is added to the most significant 16 bits.
*/

using uint64_t = std::uint64_t;
using int64_t = std::int64_t;
using size_t = std::size_t;
using boxed_t = std::uint64_t;   // 64bit word

class Box {
public:
    constexpr static uint64_t double_offset = 1ULL << 48;
    constexpr static boxed_t null_value = 0;

    static boxed_t to_boxed(void* ptr) {
        return boxed_t(ptr) & (uint64_t(-1) >> 16);
    }

    template <typename T>
    inline static T* to_ptr(boxed_t v) { return (T*)v; }

    inline static bool is_ptr(boxed_t v) {
        return (v >> 48) == 0;
    }

    inline static boxed_t to_boxed(uint64_t v) {
        // the body is equivalent to:
        // return (v & (uint64_t(-1) >> 16)) | ((0xfffeULL + 1) << 48);
        return v | ((0xfffeULL + 1) << 48);
    }

    inline static uint64_t to_uint64(boxed_t v) {
        return v & (uint64_t(-1) >> 16);
    }

    inline static bool is_uint64(boxed_t v) {
        return (v >> 48) == 0xffff;
    }

    inline static boxed_t to_boxed(int64_t v) {
        return to_boxed(uint64_t(v));
    }

    inline static int64_t to_int64(boxed_t v) {
        return int64_t(v << 16) >> 16;
    }

    inline static bool is_int64(boxed_t v) { return is_uint64(v); }

    inline static boxed_t to_boxed(double d) {
        if (std::isnan(d))
            return (0x7ff8ULL + 1) << 48;
        else
            return *(uint64_t*)&d + double_offset;
    }

    inline static double to_double(boxed_t v) {
        boxed_t v2 = v - double_offset;
        return *(double*)&v2;
    }

    inline static bool is_double(boxed_t v) {
        return (((v >> 48) - 1) & 0xfffe) != 0xfffe;
    }
};

// An exception thrown when the memory is exhausted.
class GC_MemoryExhausted {};

// the root class for all objects.
// all the fields must be 64 bits.
class YHeader {
    /* Header1
     *  object type:   2 bits, 62-63
     *  unbox size:    3 bits, 59-61
     *  gc generation: 2 bits, 57-58
     *  remember:      1 bit,  56
     *  gc mark:       2 bit,  54 (initial value is 0)
     *  unused:        6 bits
     *  next object pointer or
     *  forward pointer: 48 bits, 0-47
     *
     *  (In the nursery space,
     *   the forward pointer of a live object is nullptr
     *   and the gc generation is > 0.)
     *
     * Header2
     *  hash value:   32 bits
     *  size:         32 bits
     */
    uint64_t header1;
    uint64_t header2;

public:
    virtual uint64_t y_hash();
    virtual uint64_t y_eql$(boxed_t obj);   // eql?

    /**
     * object:      a normal object.
     * unbox_array: all fields are not pointers.
     * box_array:   all fields are boxed values.
     */
    enum otype { object = 0, unbox_array = 1, box_array = 2 };

    // true if the object contains a boxed value.
    bool has_boxed_value() {
        otype t = object_type();
        return (t & 1) == 0;
    }

    YHeader(std::uint32_t size, int unbox_size) : YHeader(size, otype::object, unbox_size) {}

    /*
     * size:       the number of the fields.  size >= 0.
     *             It is an unsigned 32bit integer.  Each field contains a 64bit value.
     * unbox_size: the number of the fields that do not contain pointers.
     *             the first several fields can contain non-pointer values
     *             without boxing.  0 <= unbox_size < 8.
     *
     * the boxed fields are initialized to be nullptr.
     * the gc generation is set to 1 (or 0 if the object is in the tenure space).
     * the remember bit and the mark bit are set to 0.
     */
    YHeader(std::uint32_t size, otype type, int unbox_size) {
        header1 = ((uint64_t(type) & 3) << 62) | ((uint64_t(unbox_size) & 7) << 59) | (1ULL << 57);
        header2 = (uint64_t(std::uint32_t(uint64_t(this)) >> 3) << 32) | std::uint32_t(size);
        if (has_boxed_value()) {
            uint64_t* ptr = &header2 + 1;
            for (std::uint32_t i = unbox_size; i < size; i++)
                ptr[i] = Box::null_value;
        }
    }

    // the object type.
    otype object_type() { return (otype)((header1 >> 62) & 3); }

    // the number of the first several fields holding unboxed values.
    // unboxed values are never pointers.  0..7
    int unbox_size() { return (header1 >> 59) & 7; }

    // gc generation. 0..3
    int gc_generation() { return (header1 >> 57) & 3; }

    void set_gc_generation(int g) {
        header1 = (header1 & (uint64_t(-1) - (3ULL << 57))) | (uint64_t(g & 3) << 57);
    }

    // increments gc generation by one.
    // It returns true if the generation bits are 00 after the increment.
    bool inc_gc_generation() {
        uint64_t gen = (header1 + (1ULL << 57)) & (3ULL << 57);
        header1 = gen | (header1 & (uint64_t(-1) - (3ULL << 57)));
        return gen == 0;
    }

    // remember bit.  0 or 1.
    int gc_remember() { return (header1 >> 56) & 1; }

    // set the remember bit.
    void set_gc_remember() { header1 |= 1ULL << 56; }

    // clear the remember bit.
    void reset_gc_remember() { header1 &= ~(1ULL << 56); }

    // flip the gc remember bit, from 0 to 1 or 1 to 0.
    void flip_gc_remember() {
        header1 ^= (1ULL << 56);
    }

    // gc mark bit.  0 to 3.
    int gc_mark() { return (header1 >> 54) & 3; }

    // sets the gc mark bits to the given value and returns the old value.
    int set_gc_mark(int value) {
        uint64_t mask = 3ULL << 54;
        uint64_t old = (header1 & mask) >> 54;
        header1 = ((uint64_t(value) << 54) & mask) | (header1 & ~mask);
        return int(old);
    }

    YHeader* next_object() { return (YHeader*)(header1 & (uint64_t(-1) >> 16)); }

    void set_next_object(YHeader* obj) {
        header1 = (header1 & (0xffffULL << 48)) | (uint64_t(obj) & (uint64_t(-1) >> 16));
    }

    uint64_t* forward_pointer() { return (uint64_t*)(header1 & (uint64_t(-1) >> 16)); }

    void set_forward_pointer(uint64_t* obj) { header1 = uint64_t(obj); }

    // the number of 64bit words allocated for object fields.
    std::uint32_t field_size() { return std::uint32_t(header2); }

    // the hash value of this object.
    uint64_t hash_value() { return header2 >> 32; }

    // gets the value of the field at the index.
    boxed_t get_field(std::uint32_t index) { return (&header2)[index + 1]; }

    // changes the value of the field at the index.
    void set_field(std::uint32_t index, boxed_t value) { (&header2)[index + 1] = value; }

    void* operator new(size_t count) { return allocate_in_semi(count); }
    void* operator new(size_t count, size_t real_count) { return allocate_in_semi(real_count); }
    void* operator new(size_t count, void* p) { return ::operator new(count); }
    void* operator new(size_t count, size_t real_count, void* p) { return ::operator new(real_count); }

protected:
    // write barrier
    boxed_t w_barrier(boxed_t value) {
        if (value != Box::null_value && Box::is_ptr(value) && this->can_remember()
            && Box::to_ptr<YHeader>(value)->gc_generation() > 0) {
            set_gc_remember();
            add_remember_set();
        }
        return value;
    }

    // true if the generation is 0 and the remembered bit is 0.
    bool can_remember() {
        return (header1 & (7ULL << 56)) == 0;
    }

    // adds this object to the remember set.
    void add_remember_set();

    // insert this into the list of tenure objects.
    void add_to_tenure_space();

    static uint64_t* current_top;
    static uint64_t* current_end;

    // count: the size in byte.
    static void* allocate_in_semi(size_t count) {
        // wcount: the size in 64bit word.
        size_t wcount = (count + sizeof(uint64_t) - 1) / sizeof(uint64_t);
        uint64_t* new_top = current_top + wcount;
        if (new_top > current_end)
            new_top = allocate_in_semi2(wcount);

        void* ptr = current_top;
        current_top = new_top;

        // all pointers must be initialized.
        for (size_t i = 0; i < wcount; ++i)
            ((uint64_t*)ptr)[i] = Box::null_value;

        return ptr;
    }

    static uint64_t* allocate_in_semi2(size_t count);

    // the destructor is called only when the object is in the
    // tenure space.  If the destructor is not empty, the object
    // has to be allocated in the tenure space.  For example,
    //
    //   YHeader* obj = new(nullptr) YHeader(0, 0);  /* new(nullptr) allcates in tenure */
    //   obj->add_to_tenure_space();
    virtual ~YHeader();

    friend class GC;
};

// Shadow stack.
class Shadow {
public:
    // gets an element of the shadow stack.
    template <typename T>
    static T* get(int64_t index) { return (T*)shadow_stack[stack_top - index]; }

    // assigns the value to the specified element of the shadow stack.
    static void set(int64_t index, YHeader* value) { shadow_stack[stack_top - index] = value; }

    // increments the stack top by size.
    // The added stack elements are set to nullptr.
    static void expand(int size) {
        shadow_stack.resize((stack_top += size) + 1);
    }

    // decrements the stack top by size.
    static void shrink(size_t size) {
        shadow_stack.resize((stack_top -= size) + 1);
    }

protected:
   // the shadow stack is a root set.  It only contains pointers.
    static std::vector<YHeader*> shadow_stack;
    static int64_t stack_top;    // indicates the top used element.  The initial value is -1.

    friend class GC;
};

/**
 * Array containing no pointers.
 */
class YUnboxArray : public YHeader {
    uint64_t body0;
    YUnboxArray(std::uint32_t size) : YHeader(size, otype::unbox_array, 0) {}
public:
    uint64_t* body() { return &body0; }

    // makes a new YUnboxArray object.
    // size: the number of the fields (array elements).
    static YUnboxArray* make(std::uint32_t size) {
        return new(sizeof(YHeader) + size * sizeof(uint64_t)) YUnboxArray(size);
    }

    // make a new YUnboxArray object in the tenure space.
    // size: the number of the fields (array elements).
    static YUnboxArray* make_in_tenure(std::uint32_t size) {
        YUnboxArray* obj = new(sizeof(YHeader) + size * sizeof(uint64_t), nullptr) YUnboxArray(size);
        obj->add_to_tenure_space();
        return obj;
    }
};

/**
 * Array containing boxed values.  It may contain a pointer.
 */
class YArray : public YHeader {
    boxed_t body0;
    YArray(std::uint32_t size) : YHeader(size, otype::box_array, 0) {}
public:
    boxed_t* body() { return &body0; }

    // makes a new YArray object.
    // size: the number of the fields (array elements).
    static YArray* make(std::uint32_t size) {
        return new(sizeof(YHeader) + size * sizeof(boxed_t)) YArray(size);
    }

    // make a new YArray object in the tenure space.
    // size: the number of the fields (array elements).
    static YArray* make_in_tenure(std::uint32_t size) {
        YArray* obj = new(sizeof(YHeader) + size * sizeof(boxed_t), nullptr) YArray(size);
        obj->add_to_tenure_space();
        // all pointers must be initialized.
        for (std::uint32_t i = 0; i < size; ++i)
            (&obj->body0)[i] = Box::null_value;
        return obj;
    }
};

} // end of namespace

