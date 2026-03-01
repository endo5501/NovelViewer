#ifndef CONFIGMAC_H_INCLUDED
#define CONFIGMAC_H_INCLUDED

/* macOS / Unix configuration for LAME */

/* The number of bytes in basic types (LP64 model on macOS) */
#define SIZEOF_DOUBLE 8
#define SIZEOF_FLOAT 4
#define SIZEOF_INT 4
#define SIZEOF_LONG 8
#define SIZEOF_LONG_LONG 8
#define SIZEOF_LONG_DOUBLE 16
#define SIZEOF_SHORT 2
#define SIZEOF_UNSIGNED_INT 4
#define SIZEOF_UNSIGNED_LONG 8
#define SIZEOF_UNSIGNED_LONG_LONG 8
#define SIZEOF_UNSIGNED_SHORT 2

/* Define if you have the ANSI C header files. */
#define STDC_HEADERS 1

/* Standard headers available on macOS */
#define HAVE_ERRNO_H 1
#define HAVE_FCNTL_H 1
#define HAVE_LIMITS_H 1
#define HAVE_STDINT_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_STRINGS_H 1
#define HAVE_UNISTD_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_MEMORY_H 1
#define HAVE_DLFCN_H 1

/* Functions available on macOS */
#define HAVE_STRTOL 1
#define HAVE_GETTIMEOFDAY 1
#define HAVE_STRCHR 1
#define HAVE_MEMCPY 1

/* Standard integer types from <stdint.h> */
#define HAVE_INT8_T 1
#define HAVE_INT16_T 1
#define HAVE_INT32_T 1
#define HAVE_INT64_T 1
#define HAVE_UINT8_T 1
#define HAVE_UINT16_T 1
#define HAVE_UINT32_T 1
#define HAVE_UINT64_T 1

/* IEEE 754/854 float types */
typedef float ieee754_float32_t;
typedef double ieee754_float64_t;
typedef long double ieee854_float80_t;

/* Name of package */
#define PACKAGE "lame"

/* Define if compiler has function prototypes */
#define PROTOTYPES 1

/* faster log implementation with less but enough precision */
#define USE_FAST_LOG 1

#ifdef HAVE_MPGLIB
# define DECODE_ON_THE_FLY 1
#endif

#define LAME_LIBRARY_BUILD

#endif /* CONFIGMAC_H_INCLUDED */
