// LD_PRELOAD shim: counts and times GL shader compiles/links (tools/perf/shader_compiles.sh).
// Godot (glad) dlopens libGL and dlsyms glXGetProcAddressARB, so dlsym itself is wrapped to hand
// back our resolver. Prints "GLC src <hash> <bytes>", "GLC compile <ms>", "GLC link <ms>" to stderr;
// with GLSHIM_DUMP=<dir> each distinct shader source is saved as <dir>/<hash>.glsl, so a program
// compiled late can be diffed against the ones the warm-up compiled (its #defines name the variant).
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <stdlib.h>
typedef void (*fn_t)(void);
typedef fn_t (*gpa_t)(const unsigned char *);
static void *(*real_dlsym)(void *, const char *) = 0;
static gpa_t real_gpa = 0;
static void (*real_link)(unsigned int) = 0;
static void (*real_compile)(unsigned int) = 0;
typedef void (*src_t)(unsigned int, int, const char *const *, const int *);
static src_t real_src = 0;
static void my_src(unsigned int sh, int count, const char *const *str, const int *len) {
  unsigned long long h = 1469598103934665603ULL; size_t total = 0;
  for (int i = 0; i < count; i++) { size_t n = len && len[i] >= 0 ? (size_t)len[i] : strlen(str[i]); total += n; for (size_t j = 0; j < n; j++) { h ^= (unsigned char)str[i][j]; h *= 1099511628211ULL; } }
  const char *dir = getenv("GLSHIM_DUMP");
  if (dir) { char path[512]; snprintf(path, sizeof path, "%s/%016llx.glsl", dir, h); FILE *f = fopen(path, "wx"); if (f) { for (int i = 0; i < count; i++) { size_t n = len && len[i] >= 0 ? (size_t)len[i] : strlen(str[i]); fwrite(str[i], 1, n, f); } fclose(f); } }
  fprintf(stderr, "GLC src %016llx %zu\n", h, total);
  real_src(sh, count, str, len);
}
static double now_ms(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1e3 + t.tv_nsec / 1e6; }
static void my_compile(unsigned int s) { double a = now_ms(); real_compile(s); fprintf(stderr, "GLC compile %.1f\n", now_ms() - a); }
static void my_link(unsigned int p) { double a = now_ms(); real_link(p); fprintf(stderr, "GLC link %.1f\n", now_ms() - a); }
static fn_t my_gpa(const unsigned char *name) {
  fn_t f = real_gpa(name);
  if (getenv("GLSHIM_DEBUG") && strstr((const char *)name, "Shader")) fprintf(stderr, "GLSHIM gpa %s -> %p\n", name, (void *)f);
  if (!f) return f;
  if (!strcmp((const char *)name, "glLinkProgram")) { real_link = (void (*)(unsigned int))f; return (fn_t)my_link; }
  if (!strcmp((const char *)name, "glShaderSource")) { real_src = (src_t)f; return (fn_t)my_src; }
  if (!strcmp((const char *)name, "glCompileShader")) { real_compile = (void (*)(unsigned int))f; return (fn_t)my_compile; }
  return f;
}
static void init(void) {
  if (!real_dlsym) real_dlsym = (void *(*)(void *, const char *))dlvsym(RTLD_NEXT, "dlsym", "GLIBC_2.34");
  if (!real_dlsym) real_dlsym = (void *(*)(void *, const char *))dlvsym(RTLD_NEXT, "dlsym", "GLIBC_2.2.5");
}
void *dlsym(void *h, const char *name) {
  init();
  void *r = real_dlsym(h, name);
  if (getenv("GLSHIM_DEBUG") && name && (strstr(name, "glX") || strstr(name, "Shader") || strstr(name, "Program"))) fprintf(stderr, "GLSHIM dlsym %s -> %p\n", name, r);
  if (r && (!strcmp(name, "glXGetProcAddressARB") || !strcmp(name, "glXGetProcAddress"))) {
    real_gpa = (gpa_t)r;
    return (void *)my_gpa;
  }
  if (r && !strcmp(name, "glLinkProgram")) { real_link = (void (*)(unsigned int))r; return (void *)my_link; }
  if (r && !strcmp(name, "glShaderSource")) { real_src = (src_t)r; return (void *)my_src; }
  if (r && !strcmp(name, "glCompileShader")) { real_compile = (void (*)(unsigned int))r; return (void *)my_compile; }
  return r;
}
