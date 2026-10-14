#ifdef _WIN32
// The matcher is implemented in Swift; Windows only needs the option bits.
#define FNM_PATHNAME (1 << 0)
#define FNM_NOESCAPE (1 << 1)
#define FNM_PERIOD (1 << 2)
#else
#include <fnmatch.h>
#endif

// for platforms that don't include various flags, define them for use with `Pattern.Options.fnmatch(flags: flags)`

#ifndef FNM_LEADING_DIR
#define	FNM_LEADING_DIR	1 << 29
#endif

#ifndef FNM_EXTMATCH
#define	FNM_EXTMATCH	1 << 30
#endif