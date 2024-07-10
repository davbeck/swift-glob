#include <fnmatch.h>

// for platforms that don't include various flags, define them for use with `Pattern.Options.fnmatch(flags: flags)`

#ifndef FNM_LEADING_DIR
#define	FNM_LEADING_DIR	1 << 29
#endif