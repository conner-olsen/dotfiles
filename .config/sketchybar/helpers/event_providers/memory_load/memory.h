#include <mach/mach.h>
#include <sys/sysctl.h>
#include <stdbool.h>
#include <unistd.h>
#include <stdio.h>

struct memory {
  host_t host;
  mach_msg_type_number_t count;
  vm_statistics64_data_t stats;
  uint64_t page_size;
  uint64_t total;

  int used_percent;
  double used_gb;
  double total_gb;
};

static inline void memory_init(struct memory* memory) {
  memory->host = mach_host_self();

  vm_size_t page_size;
  host_page_size(memory->host, &page_size);
  memory->page_size = (uint64_t)page_size;

  size_t size = sizeof(memory->total);
  sysctlbyname("hw.memsize", &memory->total, &size, NULL, 0);
  memory->total_gb = (double)memory->total / (1024.0 * 1024.0 * 1024.0);
}

static inline void memory_update(struct memory* memory) {
  memory->count = HOST_VM_INFO64_COUNT;
  kern_return_t error = host_statistics64(memory->host,
                                          HOST_VM_INFO64,
                                          (host_info64_t)&memory->stats,
                                          &memory->count                 );

  if (error != KERN_SUCCESS) {
    printf("Error: Could not read memory host statistics.\n");
    return;
  }

  // Used memory as Activity Monitor reports it:
  // app memory (internal - purgeable) + wired + compressed
  uint64_t used = ((uint64_t)memory->stats.internal_page_count
                   - (uint64_t)memory->stats.purgeable_count
                   + (uint64_t)memory->stats.wire_count
                   + (uint64_t)memory->stats.compressor_page_count)
                  * memory->page_size;

  memory->used_percent = (double)used / (double)memory->total * 100.0;
  memory->used_gb = (double)used / (1024.0 * 1024.0 * 1024.0);
}
