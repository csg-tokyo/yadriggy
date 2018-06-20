# Yadriggy

## Examples

In the following instructions, if you have already installed _yadriggy_,
you don't need `-I../lib`.

### Fibonacci number

`fib.rb` and `fib_class.rb` are source code.  It offloads the computation
of Fibonacci numbers to the C language.  To run them,

```
$ cd ./examples
$ ruby -I../lib fib.rb
$ ruby -I../lib fib_class.rb
$ rm -r yadriggy_tmp/          # delete the working directory.
```

### Array

`array.rb` is the source code.  It offloads the computation using arrays, which are also accessed in Ruby.  To run this,

```
$ ruby -I../lib array.rb
$ rm -r yadriggy_tmp/
```

### OpenCL

`opencl.rb` is the source code.  It offloads the computation to the GPU.
To run this,

```
$ ruby -I../lib opencl.rb
$ rm -r yadriggy_tmp/
```

### Image filter

`image_filters/laplacian_demo.rb` is source code.
It applies the laplacian filter to `photo.png`.
It performs three versions of the filter: Ruby, C, and OpenCL (macOS only).

```
$ cd ./examples
$ ruby -I../lib -I. image_filters/laplacian_demo.rb
$ rm -r yadriggy_tmp/
```

The filter is applicable to other png images as:

```
$ ruby -I../lib -I. image_filters/laplacian_demo.rb photo-large.png 
```

This applies the filter to `photo-large.png`.
