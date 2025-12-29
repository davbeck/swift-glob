#include <glob.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef struct {
    const char *name;
    const char *pattern;
} BenchmarkCase;

static BenchmarkCase cases[] = {
    {"basic", "stdlib/public/*/*.swift"},
    {"intermediate", "lib/SILOptimizer/*/*.cpp"},
    {"advanced", "lib/*/[A-Z]*.cpp"},
    {NULL, NULL}
};

static void run_benchmark(const char *base_path, const BenchmarkCase *bc) {
    char full_pattern[4096];
    snprintf(full_pattern, sizeof(full_pattern), "%s/%s", base_path, bc->pattern);

    glob_t globbuf;
    struct timespec start, end;

    clock_gettime(CLOCK_MONOTONIC, &start);

    int result = glob(full_pattern, GLOB_NOSORT, NULL, &globbuf);

    clock_gettime(CLOCK_MONOTONIC, &end);

    double elapsed_ms = (end.tv_sec - start.tv_sec) * 1000.0
                      + (end.tv_nsec - start.tv_nsec) / 1000000.0;

    size_t count = (result == 0) ? globbuf.gl_pathc : 0;

    if (result == 0) {
        globfree(&globbuf);
    }

    printf("c,%s,%s,%zu,%.3f\n", bc->name, bc->pattern, count, elapsed_ms);
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <search_path>\n", argv[0]);
        return 1;
    }

    const char *base_path = argv[1];

    for (int i = 0; cases[i].name != NULL; i++) {
        run_benchmark(base_path, &cases[i]);
    }

    return 0;
}
