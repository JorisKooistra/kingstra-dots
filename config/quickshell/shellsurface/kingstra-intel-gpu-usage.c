#define _GNU_SOURCE

#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <linux/perf_event.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <time.h>
#include <unistd.h>

#ifndef PERF_FLAG_FD_CLOEXEC
#define PERF_FLAG_FD_CLOEXEC (1UL << 3)
#endif

#define MAX_EVENTS 32

struct pmu_counter {
    char name[128];
    int fd;
    uint64_t start;
    uint64_t end;
    uint64_t start_enabled;
    uint64_t end_enabled;
    uint64_t start_running;
    uint64_t end_running;
};

static int debug_enabled = 0;

static long perf_event_open(struct perf_event_attr *attr, pid_t pid, int cpu, int group_fd, unsigned long flags) {
    return syscall(__NR_perf_event_open, attr, pid, cpu, group_fd, flags);
}

static int read_u64_file(const char *path, uint64_t *value) {
    FILE *file = fopen(path, "r");
    if (!file) return -1;

    char buffer[128] = {0};
    if (!fgets(buffer, sizeof(buffer), file)) {
        fclose(file);
        return -1;
    }
    fclose(file);

    char *cursor = strchr(buffer, '=');
    cursor = cursor ? cursor + 1 : buffer;
    while (*cursor && isspace((unsigned char)*cursor)) cursor++;

    errno = 0;
    char *end = NULL;
    uint64_t parsed = strtoull(cursor, &end, 0);
    if (errno != 0 || end == cursor) return -1;

    *value = parsed;
    return 0;
}

static int event_is_busy_counter(const char *name) {
    size_t len = strlen(name);
    return len > 5 && strcmp(name + len - 5, "-busy") == 0;
}

static int open_pmu_counter(uint64_t pmu_type, const char *event_name, struct pmu_counter *counter) {
    char event_path[512];
    snprintf(event_path, sizeof(event_path), "/sys/bus/event_source/devices/i915/events/%s", event_name);

    uint64_t config = 0;
    if (read_u64_file(event_path, &config) != 0) return -1;

    struct perf_event_attr attr;
    memset(&attr, 0, sizeof(attr));
    attr.type = (uint32_t)pmu_type;
    attr.size = sizeof(attr);
    attr.config = config;
    attr.disabled = 0;
    attr.exclude_guest = 1;
    attr.read_format = PERF_FORMAT_TOTAL_TIME_ENABLED | PERF_FORMAT_TOTAL_TIME_RUNNING;

    long fd = perf_event_open(&attr, -1, 0, -1, PERF_FLAG_FD_CLOEXEC);
    if (fd < 0) {
        if (debug_enabled) {
            fprintf(stderr, "open failed: %s config=0x%llx errno=%d (%s)\n",
                    event_name, (unsigned long long)config, errno, strerror(errno));
        }
        return -1;
    }

    memset(counter, 0, sizeof(*counter));
    snprintf(counter->name, sizeof(counter->name), "%s", event_name);
    counter->fd = (int)fd;
    return 0;
}

static int read_counter(struct pmu_counter *counter, int end_sample) {
    struct {
        uint64_t value;
        uint64_t time_enabled;
        uint64_t time_running;
    } data = {0, 0, 0};

    ssize_t bytes = read(counter->fd, &data, sizeof(data));
    if (bytes != (ssize_t)sizeof(data)) {
        if (debug_enabled) {
            fprintf(stderr, "read failed: %s bytes=%zd errno=%d (%s)\n",
                    counter->name, bytes, errno, strerror(errno));
        }
        return -1;
    }

    if (end_sample) {
        counter->end = data.value;
        counter->end_enabled = data.time_enabled;
        counter->end_running = data.time_running;
    } else {
        counter->start = data.value;
        counter->start_enabled = data.time_enabled;
        counter->start_running = data.time_running;
    }
    return 0;
}

static uint64_t monotonic_ns(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) return 0;
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

static void sleep_ms(long ms) {
    struct timespec ts;
    ts.tv_sec = ms / 1000;
    ts.tv_nsec = (ms % 1000) * 1000000L;
    while (nanosleep(&ts, &ts) != 0 && errno == EINTR) {}
}

static long sample_ms_from_env(void) {
    const char *raw = getenv("KINGSTRA_GPU_SAMPLE_MS");
    if (!raw || raw[0] == '\0') return 1000;

    char *end = NULL;
    long value = strtol(raw, &end, 10);
    if (end == raw || value < 100) return 1000;
    if (value > 2500) return 2500;
    return value;
}

static int collect_counters(uint64_t pmu_type, struct pmu_counter *busy, int *busy_count) {
    const char *events_dir = "/sys/bus/event_source/devices/i915/events";
    DIR *dir = opendir(events_dir);
    if (!dir) return -1;

    struct dirent *entry = NULL;
    while ((entry = readdir(dir)) != NULL && *busy_count < MAX_EVENTS) {
        if (!event_is_busy_counter(entry->d_name)) continue;
        if (open_pmu_counter(pmu_type, entry->d_name, &busy[*busy_count]) == 0) {
            (*busy_count)++;
        }
    }
    closedir(dir);
    return 0;
}

static double counter_delta_percent(const struct pmu_counter *counter, double elapsed_ns) {
    uint64_t delta = counter->end >= counter->start ? counter->end - counter->start : 0;
    uint64_t enabled_delta = counter->end_enabled >= counter->start_enabled
        ? counter->end_enabled - counter->start_enabled : 0;
    uint64_t running_delta = counter->end_running >= counter->start_running
        ? counter->end_running - counter->start_running : 0;

    double scaled_delta = (double)delta;
    if (running_delta > 0 && enabled_delta > running_delta) {
        scaled_delta *= (double)enabled_delta / (double)running_delta;
    }

    double percent = (scaled_delta / elapsed_ns) * 100.0;
    if (debug_enabled) {
        fprintf(stderr,
                "delta: %s start=%llu end=%llu delta=%llu enabled_delta=%llu running_delta=%llu percent=%.2f\n",
                counter->name,
                (unsigned long long)counter->start,
                (unsigned long long)counter->end,
                (unsigned long long)delta,
                (unsigned long long)enabled_delta,
                (unsigned long long)running_delta,
                percent);
    }
    return percent;
}

int main(int argc, char **argv) {
    if (argc > 1 && strcmp(argv[1], "--debug") == 0) debug_enabled = 1;

    uint64_t pmu_type = 0;
    if (read_u64_file("/sys/bus/event_source/devices/i915/type", &pmu_type) != 0) {
        if (debug_enabled) fprintf(stderr, "failed to read i915 PMU type\n");
        return 1;
    }

    struct pmu_counter busy[MAX_EVENTS];
    int busy_count = 0;

    if (collect_counters(pmu_type, busy, &busy_count) != 0 || busy_count == 0) {
        return 1;
    }

    for (int i = 0; i < busy_count; i++) read_counter(&busy[i], 0);
    uint64_t start_ns = monotonic_ns();

    sleep_ms(sample_ms_from_env());

    uint64_t end_ns = monotonic_ns();
    for (int i = 0; i < busy_count; i++) read_counter(&busy[i], 1);

    for (int i = 0; i < busy_count; i++) close(busy[i].fd);

    if (end_ns <= start_ns) return 1;
    double elapsed = (double)(end_ns - start_ns);

    double max_busy_percent = 0.0;
    double sum_busy_percent = 0.0;
    for (int i = 0; i < busy_count; i++) {
        double percent = counter_delta_percent(&busy[i], elapsed);
        sum_busy_percent += percent;
        if (percent > max_busy_percent) max_busy_percent = percent;
    }

    double selected_percent = max_busy_percent;

    int percent = (int)(selected_percent + 0.5);
    if (percent < 0) percent = 0;
    if (percent > 100) percent = 100;

    if (debug_enabled) {
        fprintf(stderr,
                "pmu_type=%llu busy_events=%d sample_ms=%ld max_busy_percent=%.2f sum_busy_percent=%.2f selected=%.2f\n",
                (unsigned long long)pmu_type, busy_count, sample_ms_from_env(),
                max_busy_percent, sum_busy_percent, selected_percent);
    }

    printf("%d\n", percent);
    return 0;
}
