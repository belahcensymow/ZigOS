#ifndef GENERATED_TABLE_H
#define GENERATED_TABLE_H

#include <stdint.h>
#include <stddef.h>

// Stub structures to satisfy the compiler
struct drm_format_modifier_pair {
    uint64_t modifier;
    const char *modifier_name;
};

struct drm_format_modifier_vendor_pair {
    uint8_t vendor;
    const char *vendor_name;
};

// Define them as empty arrays so the loops have 0 size
static const struct drm_format_modifier_pair drm_format_modifier_table[] = {};
static const struct drm_format_modifier_vendor_pair drm_format_modifier_vendor_table[] = {};

#endif
