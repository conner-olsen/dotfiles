#include "memory.h"
#include "../sketchybar.h"

int main (int argc, char** argv) {
  float update_freq;
  if (argc < 3 || (sscanf(argv[2], "%f", &update_freq) != 1)) {
    printf("Usage: %s \"<event-name>\" \"<event_freq>\"\n", argv[0]);
    exit(1);
  }

  alarm(0);
  struct memory memory;
  memory_init(&memory);

  // Setup the event in sketchybar
  char event_message[512];
  snprintf(event_message, 512, "--add event '%s'", argv[1]);
  sketchybar(event_message);

  char trigger_message[512];
  for (;;) {
    // Acquire new info
    memory_update(&memory);

    // Prepare the event message
    snprintf(trigger_message,
             512,
             "--trigger '%s' used_percent='%02d' used_gb='%.1f' total_gb='%.0f'",
             argv[1],
             memory.used_percent,
             memory.used_gb,
             memory.total_gb              );

    // Trigger the event
    sketchybar(trigger_message);

    // Wait
    usleep(update_freq * 1000000);
  }
  return 0;
}
