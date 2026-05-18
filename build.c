#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define CLR_RESET   "\x1b[0m"
#define CLR_RED     "\x1b[31m"
#define CLR_GREEN   "\x1b[32m"
#define CLR_YELLOW  "\x1b[33m"
#define CLR_BLUE    "\x1b[34m"
#define CLR_CYAN    "\x1b[36m"

int check_file(const char *filename) {
    FILE *f = fopen(filename, "r");
    if (f) {
        fclose(f);
        return 1;
    }
    return 0;
}

int execute_pipeline(const char *command, const char *step_name, const char *required_source) {
    printf("%s[COMPILE]%s Executing: %s...\n", CLR_BLUE, CLR_RESET, step_name);
    
    if (required_source != NULL && !check_file(required_source)) {
        printf("%s[FATAL]%s Required file '%s' is missing!\n", CLR_RED, CLR_RESET, required_source);
        return 0;
    }

    int status = system(command);
    if (status != 0) {
        printf("%s[FAILED]%s %s failed with exit code: %d\n", CLR_RED, CLR_RESET, step_name, status);
        return 0;
    }
    
    printf("%s[SUCCESS]%s %s completed.\n\n", CLR_GREEN, CLR_RESET, step_name);
    return 1;
}

int main() {
    clock_t start_time = clock();

    printf("%s==================================================%s\n", CLR_CYAN, CLR_RESET);
    printf("%s       W KERNEL HYBRID COMPILER BUILD SYSTEM      %s\n", CLR_CYAN, CLR_RESET);
    printf("%s==================================================%s\n\n", CLR_CYAN, CLR_RESET);

    // ADIM 1: Python derleyicini calistirip kernel.w kodunu Assembly'ye (.asm) ceviriyoruz
    // NOT: Eger Python betiginin adi w_compiler.py degilse, asagidaki ismi ona gore degistir.
    if (!execute_pipeline("python w_compiler.py kernel.w -o kernel.asm", "W Python Compiler (W -> ASM)", "kernel.w")) {
        return EXIT_FAILURE;
    }

    // ADIM 2: Python'un ürettigi kernel.asm dosyasini NASM ile nesne koduna (.o) ceviriyoruz
    if (!execute_pipeline("nasm -f elf64 kernel.asm -o kernel.o", "NASM Architecture Assembler (ASM -> Object)", "kernel.asm")) {
        return EXIT_FAILURE;
    }

    // ADIM 3: Objeleri Linker vasitasiyla nihai kernel binary'sine bagliyoruz
    if (!execute_pipeline("x86_64-elf-ld -n -T linker.ld -o kernel.bin kernel.o", "Static Core Linking Stage", "linker.ld")) {
        return EXIT_FAILURE;
    }

    clock_t end_time = clock();
    double total_time = ((double)(end_time - start_time)) / CLOCKS_PER_SEC;

    printf("%s==================================================%s\n", CLR_GREEN, CLR_RESET);
    printf("%s[BUILD COMPLETE]%s W Kernel successfully generated -> kernel.bin\n", CLR_GREEN, CLR_RESET);
    printf("%s[TIME TAKEN]%s Build pipeline finished in %.4f seconds.\n", CLR_YELLOW, CLR_RESET, total_time);
    printf("%s==================================================%s\n", CLR_GREEN, CLR_RESET);

    return EXIT_SUCCESS;
}