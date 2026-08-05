/* stackcheck.c — 打印主线程 + 新线程的栈大小
 *
 * 用于诊断 Flutter 在 postmarketOS (musl) 上随机 Stack Overflow：
 * musl 默认线程栈 128KB（glibc 是 8MB），Dart VM/引擎线程因此爆栈。
 *
 * 用法:
 *   编译:  musl-gcc -o stackcheck stackcheck.c
 *   运行:  ./stackcheck
 */
#define _GNU_SOURCE
#include <pthread.h>
#include <stdio.h>

static void print_stack(const char *label) {
    pthread_attr_t attr;
    size_t size = 0;
    if (pthread_getattr_np(pthread_self(), &attr) == 0) {
        pthread_attr_getstacksize(&attr, &size);
        pthread_attr_destroy(&attr);
        printf("%s: stack = %zu bytes (%zu KB)\n", label, size, size / 1024);
    } else {
        printf("%s: pthread_getattr_np failed\n", label);
    }
}

static void *worker(void *arg) {
    (void)arg;
    print_stack("worker thread");
    return NULL;
}

int main(void) {
    print_stack("main thread");
    pthread_t t;
    pthread_create(&t, NULL, worker, NULL);
    pthread_join(t, NULL);
    return 0;
}
