/* bigstack.c — LD_PRELOAD 包装 pthread_create，强制新线程使用大栈
 *
 * 背景：Flutter 引擎是 glibc 编译的，内部线程假设 8MB 栈；
 * 但 postmarketOS (Alpine) 用 musl libc，默认线程栈只有 128KB。
 * Dart VM / 引擎在 musl 下创建的线程拿到过小的栈，
 * 导致随机 "Stack Overflow"（时好时坏，ulimit 无效——那只影响主线程）。
 *
 * 用法：
 *   编译:  musl-gcc -shared -fPIC -o libbigstack.so bigstack.c
 *   运行:  LD_PRELOAD=$PWD/libbigstack.so ./bambu_lab_app
 *
 * 效果：所有新创建的线程强制 8MB 栈。
 */
#define _GNU_SOURCE
#include <pthread.h>
#include <dlfcn.h>
#include <stddef.h>

#define BIG_STACK (8 * 1024 * 1024)

int pthread_create(pthread_t *restrict thread,
                   const pthread_attr_t *restrict attr,
                   void *(*start_routine)(void *),
                   void *restrict arg) {
    static int (*real_pthread_create)(pthread_t *,
                                      const pthread_attr_t *,
                                      void *(*)(void *),
                                      void *) = NULL;
    if (!real_pthread_create) {
        real_pthread_create = dlsym(RTLD_NEXT, "pthread_create");
    }

    pthread_attr_t local_attr;
    int own_attr = 0;
    if (attr == NULL) {
        pthread_attr_init(&local_attr);
        own_attr = 1;
        attr = &local_attr;
    }

    size_t stacksize = 0;
    pthread_attr_getstacksize((pthread_attr_t *)attr, &stacksize);
    if (stacksize < BIG_STACK) {
        pthread_attr_setstacksize((pthread_attr_t *)attr, BIG_STACK);
    }

    int rc = real_pthread_create(thread, attr, start_routine, arg);

    if (own_attr) {
        pthread_attr_destroy(&local_attr);
    }
    return rc;
}
