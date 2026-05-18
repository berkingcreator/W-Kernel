// Copyright (C) 2026 Yusuf Berk Genç (YBG13™)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.

const OS_NAME: ptr<u8> = "W Kernel" as ptr<u8>;
const SEC_CORE: ptr<u8> = "Kernel version 0.0.1 beta" as ptr<u8>;

const MB2_MAGIC: u32 = 0xE85250D6;
const ARCH_X86_64: u32 = 0;
struct MB2Header {
    magic: u32,
    arch: u32,
    length: u32,
    checksum: u32,
}
const HEADER: MB2Header = MB2Header {
    magic: MB2_MAGIC,
    arch: ARCH_X86_64,
    length: 16,
    checksum: -(MB2_MAGIC + ARCH_X86_64 + 16),
};

fn outb(port: u16, data: u8) {
    asm { "out dx, al" in dx = port; in al = data; }
}

fn outw(port: u16, data: u16) {
    asm { "out dx, ax" in dx = port; in ax = data; }
}

fn outl(port: u16, data: u32) {
    asm { "out dx, eax" in dx = port; in eax = data; }
}

fn inb(port: u16) -> u8 {
    let mut data: u8;
    asm { "in al, dx" in dx = port; out al = data; }
    return data;
}

fn inw(port: u16) -> u16 {
    let mut data: u16;
    asm { "in ax, dx" in dx = port; out ax = data; }
    return data;
}

fn inl(port: u16) -> u32 {
    let mut data: u32;
    asm { "in eax, dx" in dx = port; out eax = data; }
    return data;
}

fn cpu_hlt() {
    asm { "hlt" }
}

fn cpu_cli() {
    asm { "cli" }
}

fn cpu_sti() {
    asm { "sti" }
}

fn cpu_pause() {
    asm { "pause" }
}

fn invlpg(addr: u64) {
    asm { "invlpg [rax]" in rax = addr; }
}

fn wbinvd() {
    asm { "wbinvd" }
}

fn cpuid(leaf: u32, subleaf: u32, eax: ptr<u32>, ebx: ptr<u32>, ecx: ptr<u32>, edx: ptr<u32>) {
    let mut o_eax: u32;
    let mut o_ebx: u32;
    let mut o_ecx: u32;
    let mut o_edx: u32;
    asm {
        "cpuid"
        in eax = leaf;
        in ecx = subleaf;
        out eax = o_eax;
        out ebx = o_ebx;
        out ecx = o_ecx;
        out edx = o_edx;
    }
    *eax = o_eax;
    *ebx = o_ebx;
    *ecx = o_ecx;
    *edx = o_edx;
}

fn rdmsr(msr: u32) -> u64 {
    let mut lo: u32;
    let mut hi: u32;
    asm {
        "rdmsr"
        in ecx = msr;
        out eax = lo;
        out edx = hi;
    }
    return (hi as u64 << 32) | (lo as u64);
}

fn wrmsr(msr: u32, val: u64) {
    let lo = (val & 0xFFFFFFFF) as u32;
    let hi = (val >> 32) as u32;
    asm {
        "wrmsr"
        in ecx = msr;
        in eax = lo;
        in edx = hi;
    }
}

struct Spinlock {
    locked: u32,
}

fn spin_init(lock: ptr<Spinlock>) {
    (*lock).locked = 0;
}

fn spin_lock(lock: ptr<Spinlock>) {
    let mut a = 0;
    while a == 0 {
        asm {
            "lock bts dword [rax], 0\n setnc bl"
            in rax = lock;
            out bl = a;
        }
        if a == 0 {
            cpu_pause();
        }
    }
}

fn spin_trylock(lock: ptr<Spinlock>) -> u8 {
    let mut a = 0;
    asm {
        "lock bts dword [rax], 0\n setnc bl"
        in rax = lock;
        out bl = a;
    }
    return a;
}

fn spin_unlock(lock: ptr<Spinlock>) {
    asm {
        "lock btr dword [rax], 0"
        in rax = lock;
    }
}

struct Mutex {
    state: u32,
    owner: u64,
}

fn mutex_init(m: ptr<Mutex>) {
    (*m).state = 0;
    (*m).owner = 0;
}

fn memcpy(dest: ptr<u8>, src: ptr<u8>, n: u64) {
    let mut d = dest as ptr<u64>;
    let mut s = src as ptr<u64>;
    let mut len = n / 8;
    for i in 0..len {
        *(d + i) = *(s + i);
    }
    let mut rem = n % 8;
    let mut d8 = (dest as u64 + len * 8) as ptr<u8>;
    let mut s8 = (src as u64 + len * 8) as ptr<u8>;
    for i in 0..rem {
        *(d8 + i) = *(s8 + i);
    }
}

fn memset(dest: ptr<u8>, val: u8, n: u64) {
    let v64: u64 = (val as u64) | ((val as u64) << 8) | ((val as u64) << 16) | ((val as u64) << 24) | ((val as u64) << 32) | ((val as u64) << 40) | ((val as u64) << 48) | ((val as u64) << 56);
    let mut d = dest as ptr<u64>;
    let mut len = n / 8;
    for i in 0..len {
        *(d + i) = v64;
    }
    let mut rem = n % 8;
    let mut d8 = (dest as u64 + len * 8) as ptr<u8>;
    for i in 0..rem {
        *(d8 + i) = val;
    }
}

fn memcmp(p1: ptr<u8>, p2: ptr<u8>, n: u64) -> i32 {
    for i in 0..n {
        if *(p1 + i) != *(p2 + i) {
            return (*(p1 + i) - *(p2 + i)) as i32;
        }
    }
    return 0;
}

fn memmove(dest: ptr<u8>, src: ptr<u8>, n: u64) {
    if dest < src {
        memcpy(dest, src, n);
    } else {
        for i in (0..n).rev() {
            *(dest + i) = *(src + i);
        }
    }
}

fn strlen(s: ptr<u8>) -> u64 {
    let mut l: u64 = 0;
    while *(s + l) != 0 {
        l = l + 1;
    }
    return l;
}

fn strcpy(dest: ptr<u8>, src: ptr<u8>) {
    let mut i: u64 = 0;
    while *(src + i) != 0 {
        *(dest + i) = *(src + i);
        i = i + 1;
    }
    *(dest + i) = 0;
}

fn strcmp(s1: ptr<u8>, s2: ptr<u8>) -> i32 {
    let mut i: u64 = 0;
    while *(s1 + i) != 0 && *(s2 + i) != 0 {
        if *(s1 + i) != *(s2 + i) {
            return (*(s1 + i) - *(s2 + i)) as i32;
        }
        i = i + 1;
    }
    return (*(s1 + i) - *(s2 + i)) as i32;
}

struct GDTEntry {
    limit_low: u16,
    base_low: u16,
    base_mid: u8,
    access: u8,
    flags_limit: u8,
    base_hi: u8,
}

struct TSSEntry {
    rsv0: u32,
    rsp0: u64,
    rsp1: u64,
    rsp2: u64,
    rsv1: u64,
    ist1: u64,
    ist2: u64,
    ist3: u64,
    ist4: u64,
    ist5: u64,
    ist6: u64,
    ist7: u64,
    rsv2: u64,
    rsv3: u16,
    iomap_base: u16,
}

struct GDTDesc {
    limit: u16,
    base: u64,
}

let mut gdt: [GDTEntry; 11];
let mut tss: [TSSEntry; 4];
let mut gdt_d: GDTDesc;

fn set_gdt_entry(n: u64, base: u64, limit: u32, access: u8, flags: u8) {
    gdt[n].base_low = (base & 0xFFFF) as u16;
    gdt[n].base_mid = ((base >> 16) & 0xFF) as u8;
    gdt[n].base_hi = ((base >> 24) & 0xFF) as u8;
    gdt[n].limit_low = (limit & 0xFFFF) as u16;
    gdt[n].flags_limit = (((limit >> 16) & 0x0F) as u8) | (flags & 0xF0);
    gdt[n].access = access;
}

fn init_gdt_64() {
    gdt_d.limit = (sizeof(GDTEntry) * 11) - 1;
    gdt_d.base = gdt as u64;

    set_gdt_entry(0, 0, 0, 0, 0);
    set_gdt_entry(1, 0, 0xFFFFF, 0x9A, 0xA0);
    set_gdt_entry(2, 0, 0xFFFFF, 0x92, 0xA0);
    set_gdt_entry(3, 0, 0xFFFFF, 0xFA, 0xA0);
    set_gdt_entry(4, 0, 0xFFFFF, 0xF2, 0xA0);

    let tss_b0 = &tss[0] as u64;
    set_gdt_entry(5, tss_b0, sizeof(TSSEntry) as u32, 0x89, 0x40);
    set_gdt_entry(6, tss_b0 >> 32, 0, 0, 0);

    asm {
        "lgdt [rax]\n"
        "push 0x08\n"
        "lea rax, [rip + .next]\n"
        "push rax\n"
        "retfq\n"
        ".next:\n"
        "mov ax, 0x10\n"
        "mov ds, ax\n"
        "mov es, ax\n"
        "mov fs, ax\n"
        "mov gs, ax\n"
        "mov ss, ax\n"
        "mov ax, 0x28\n"
        "ltr ax"
        in rax = &gdt_d;
    }
}

struct IDTEntry {
    offset_low: u16,
    selector: u16,
    ist: u8,
    flags: u8,
    offset_mid: u16,
    offset_high: u32,
    reserved: u32,
}

struct IDTDesc {
    limit: u16,
    base: u64,
}

let mut idt: [IDTEntry; 256];
let mut idt_d: IDTDesc;

fn set_idt_entry(n: u8, base: u64, selector: u16, flags: u8, ist: u8) {
    idt[n].offset_low = (base & 0xFFFF) as u16;
    idt[n].offset_mid = ((base >> 16) & 0xFFFF) as u16;
    idt[n].offset_high = (base >> 32) as u32;
    idt[n].selector = selector;
    idt[n].ist = ist;
    idt[n].flags = flags;
    idt[n].reserved = 0;
}

fn isr_stub_common() {
    asm {
        "push rax\n push rcx\n push rdx\n push r8\n push r9\n push r10\n push r11\n"
        "mov al, 0x20\n out 0x20, al\n"
        "pop r11\n pop r10\n pop r9\n pop r8\n pop rdx\n pop rcx\n pop rax\n"
        "iretq"
    }
}

fn exc_div_zero() { asm { "cli\n hlt" } }
fn exc_debug() { asm { "cli\n hlt" } }
fn exc_nmi() { asm { "cli\n hlt" } }
fn exc_breakpoint() { asm { "cli\n hlt" } }
fn exc_overflow() { asm { "cli\n hlt" } }
fn exc_bound() { asm { "cli\n hlt" } }
fn exc_invalid_op() { asm { "cli\n hlt" } }
fn exc_device_not_avail() { asm { "cli\n hlt" } }
fn exc_double_fault() { asm { "cli\n hlt" } }
fn exc_coproc_seg() { asm { "cli\n hlt" } }
fn exc_invalid_tss() { asm { "cli\n hlt" } }
fn exc_segment_not_present() { asm { "cli\n hlt" } }
fn exc_stack_fault() { asm { "cli\n hlt" } }
fn exc_general_protect() { asm { "cli\n hlt" } }
fn exc_page_fault() { asm { "cli\n hlt" } }
fn exc_fpu_error() { asm { "cli\n hlt" } }
fn exc_alignment_check() { asm { "cli\n hlt" } }
fn exc_machine_check() { asm { "cli\n hlt" } }
fn exc_simd_fault() { asm { "cli\n hlt" } }

fn init_idt_64() {
    idt_d.limit = (sizeof(IDTEntry) * 256) - 1;
    idt_d.base = idt as u64;

    set_idt_entry(0, exc_div_zero as u64, 0x08, 0x8E, 0);
    set_idt_entry(1, exc_debug as u64, 0x08, 0x8E, 0);
    set_idt_entry(2, exc_nmi as u64, 0x08, 0x8E, 1);
    set_idt_entry(3, exc_breakpoint as u64, 0x08, 0x8E, 0);
    set_idt_entry(4, exc_overflow as u64, 0x08, 0x8E, 0);
    set_idt_entry(5, exc_bound as u64, 0x08, 0x8E, 0);
    set_idt_entry(6, exc_invalid_op as u64, 0x08, 0x8E, 0);
    set_idt_entry(7, exc_device_not_avail as u64, 0x08, 0x8E, 0);
    set_idt_entry(8, exc_double_fault as u64, 0x08, 0x8E, 2);
    set_idt_entry(9, exc_coproc_seg as u64, 0x08, 0x8E, 0);
    set_idt_entry(10, exc_invalid_tss as u64, 0x08, 0x8E, 0);
    set_idt_entry(11, exc_segment_not_present as u64, 0x08, 0x8E, 0);
    set_idt_entry(12, exc_stack_fault as u64, 0x08, 0x8E, 0);
    set_idt_entry(13, exc_general_protect as u64, 0x08, 0x8E, 0);
    set_idt_entry(14, exc_page_fault as u64, 0x08, 0x8E, 0);
    set_idt_entry(16, exc_fpu_error as u64, 0x08, 0x8E, 0);
    set_idt_entry(17, exc_alignment_check as u64, 0x08, 0x8E, 0);
    set_idt_entry(18, exc_machine_check as u64, 0x08, 0x8E, 0);
    set_idt_entry(19, exc_simd_fault as u64, 0x08, 0x8E, 0);

    for i in 32..256 {
        set_idt_entry(i as u8, isr_stub_common as u64, 0x08, 0x8E, 0);
    }

    asm { "lidt [rax]\n sti" in rax = &idt_d; }
}
const PAGE_SIZE: u64 = 4096;
const MAX_MEM_MB: u64 = 32768;
const PMM_BITMAP_SIZE: u64 = (MAX_MEM_MB * 1024 * 1024) / (PAGE_SIZE * 64);

let mut pmm_bitmap: [u64; PMM_BITMAP_SIZE as usize];
let mut pmm_lock: Spinlock;
let mut pmm_used_blocks: u64 = 0;
let mut pmm_max_blocks: u64 = 0;

fn pmm_bitmap_set(bit: u64) {
    pmm_bitmap[(bit / 64) as usize] |= 1 << (bit % 64);
}

fn pmm_bitmap_unset(bit: u64) {
    pmm_bitmap[(bit / 64) as usize] &= !(1 << (bit % 64));
}

fn pmm_bitmap_test(bit: u64) -> bool {
    return (pmm_bitmap[(bit / 64) as usize] & (1 << (bit % 64))) != 0;
}

fn pmm_init(mem_size_kb: u64) {
    spin_init(&pmm_lock);
    pmm_max_blocks = (mem_size_kb * 1024) / PAGE_SIZE;
    pmm_used_blocks = pmm_max_blocks;
    memset(pmm_bitmap as ptr<u8>, 0xFF, (PMM_BITMAP_SIZE * 8) as u64);
}

fn pmm_init_region(base: u64, size: u64) {
    spin_lock(&pmm_lock);
    let align_base = base / PAGE_SIZE;
    let blocks = size / PAGE_SIZE;
    for i in 0..blocks {
        pmm_bitmap_unset(align_base + i);
        pmm_used_blocks = pmm_used_blocks - 1;
    }
    spin_unlock(&pmm_lock);
    pmm_bitmap_set(0);
}

fn pmm_deinit_region(base: u64, size: u64) {
    spin_lock(&pmm_lock);
    let align_base = base / PAGE_SIZE;
    let blocks = size / PAGE_SIZE;
    for i in 0..blocks {
        pmm_bitmap_set(align_base + i);
        pmm_used_blocks = pmm_used_blocks + 1;
    }
    spin_unlock(&pmm_lock);
}

fn pmm_alloc_block() -> u64 {
    spin_lock(&pmm_lock);
    if pmm_used_blocks == pmm_max_blocks {
        spin_unlock(&pmm_lock);
        return 0;
    }
    for i in 0..(PMM_BITMAP_SIZE as u64) {
        if pmm_bitmap[i as usize] != 0xFFFFFFFFFFFFFFFF {
            for j in 0..64 {
                let bit = i * 64 + j;
                if !pmm_bitmap_test(bit) {
                    pmm_bitmap_set(bit);
                    pmm_used_blocks = pmm_used_blocks + 1;
                    spin_unlock(&pmm_lock);
                    return bit * PAGE_SIZE;
                }
            }
        }
    }
    spin_unlock(&pmm_lock);
    return 0;
}

fn pmm_free_block(addr: u64) {
    spin_lock(&pmm_lock);
    let bit = addr / PAGE_SIZE;
    if pmm_bitmap_test(bit) {
        pmm_bitmap_unset(bit);
        pmm_used_blocks = pmm_used_blocks - 1;
    }
    spin_unlock(&pmm_lock);
}

fn pmm_alloc_blocks(count: u64) -> u64 {
    spin_lock(&pmm_lock);
    if pmm_used_blocks + count > pmm_max_blocks {
        spin_unlock(&pmm_lock);
        return 0;
    }
    let mut free_count: u64 = 0;
    let mut start_bit: u64 = 0;
    for i in 0..(pmm_max_blocks) {
        if !pmm_bitmap_test(i) {
            if free_count == 0 {
                start_bit = i;
            }
            free_count = free_count + 1;
            if free_count == count {
                for j in 0..count {
                    pmm_bitmap_set(start_bit + j);
                }
                pmm_used_blocks = pmm_used_blocks + count;
                spin_unlock(&pmm_lock);
                return start_bit * PAGE_SIZE;
            }
        } else {
            free_count = 0;
        }
    }
    spin_unlock(&pmm_lock);
    return 0;
}

fn pmm_free_blocks(addr: u64, count: u64) {
    spin_lock(&pmm_lock);
    let start_bit = addr / PAGE_SIZE;
    for i in 0..count {
        if pmm_bitmap_test(start_bit + i) {
            pmm_bitmap_unset(start_bit + i);
            pmm_used_blocks = pmm_used_blocks - 1;
        }
    }
    spin_unlock(&pmm_lock);
}

struct PageTableEntry {
    entry: u64,
}

fn pte_set_flag(pte: ptr<PageTableEntry>, flag: u64) {
    (*pte).entry |= flag;
}

fn pte_clear_flag(pte: ptr<PageTableEntry>, flag: u64) {
    (*pte).entry &= !flag;
}

fn pte_set_frame(pte: ptr<PageTableEntry>, frame: u64) {
    (*pte).entry = ((*pte).entry & 0xFFF) | (frame & 0xFFFFFFFFFFFFF000);
}

fn pte_is_present(pte: ptr<PageTableEntry>) -> bool {
    return ((*pte).entry & 1) != 0;
}

fn pte_get_frame(pte: ptr<PageTableEntry>) -> u64 {
    return (*pte).entry & 0x000FFFFFFFFFF000;
}

struct PageTable {
    entries: [PageTableEntry; 512],
}

let mut vmm_pml4: ptr<PageTable>;
let mut vmm_lock: Spinlock;

fn vmm_init() {
    spin_init(&vmm_lock);
    let pml4_phys = pmm_alloc_block();
    vmm_pml4 = pml4_phys as ptr<PageTable>;
    memset(vmm_pml4 as ptr<u8>, 0, PAGE_SIZE);

    let mut phys: u64 = 0;
    while phys < 0x200000000 {
        vmm_map_page(phys, phys, 3);
        phys = phys + PAGE_SIZE;
    }
    asm { "mov cr3, rax" in rax = pml4_phys; }
}

fn vmm_get_pt_index(virt: u64) -> (u64, u64, u64, u64) {
    let pml4_idx = (virt >> 39) & 0x1FF;
    let pdpt_idx = (virt >> 30) & 0x1FF;
    let pd_idx = (virt >> 21) & 0x1FF;
    let pt_idx = (virt >> 12) & 0x1FF;
    return (pml4_idx, pdpt_idx, pd_idx, pt_idx);
}

fn vmm_map_page(phys: u64, virt: u64, flags: u64) {
    spin_lock(&vmm_lock);
    let (pml4_i, pdpt_i, pd_i, pt_i) = vmm_get_pt_index(virt);

    let mut pml4e = &((*vmm_pml4).entries[pml4_i as usize]) as ptr<PageTableEntry>;
    if !pte_is_present(pml4e) {
        let new_pdpt = pmm_alloc_block();
        memset(new_pdpt as ptr<u8>, 0, PAGE_SIZE);
        pte_set_frame(pml4e, new_pdpt);
        pte_set_flag(pml4e, 3);
    }

    let pdpt = pte_get_frame(pml4e) as ptr<PageTable>;
    let mut pdpte = &((*pdpt).entries[pdpt_i as usize]) as ptr<PageTableEntry>;
    if !pte_is_present(pdpte) {
        let new_pd = pmm_alloc_block();
        memset(new_pd as ptr<u8>, 0, PAGE_SIZE);
        pte_set_frame(pdpte, new_pd);
        pte_set_flag(pdpte, 3);
    }

    let pd = pte_get_frame(pdpte) as ptr<PageTable>;
    let mut pde = &((*pd).entries[pd_i as usize]) as ptr<PageTableEntry>;
    if !pte_is_present(pde) {
        let new_pt = pmm_alloc_block();
        memset(new_pt as ptr<u8>, 0, PAGE_SIZE);
        pte_set_frame(pde, new_pt);
        pte_set_flag(pde, 3);
    }

    let pt = pte_get_frame(pde) as ptr<PageTable>;
    let mut pte = &((*pt).entries[pt_i as usize]) as ptr<PageTableEntry>;
    pte_set_frame(pte, phys);
    pte_set_flag(pte, flags | 1);
    
    invlpg(virt);
    spin_unlock(&vmm_lock);
}

fn vmm_unmap_page(virt: u64) {
    spin_lock(&vmm_lock);
    let (pml4_i, pdpt_i, pd_i, pt_i) = vmm_get_pt_index(virt);

    let pml4e = &((*vmm_pml4).entries[pml4_i as usize]) as ptr<PageTableEntry>;
    if !pte_is_present(pml4e) { spin_unlock(&vmm_lock); return; }

    let pdpt = pte_get_frame(pml4e) as ptr<PageTable>;
    let pdpte = &((*pdpt).entries[pdpt_i as usize]) as ptr<PageTableEntry>;
    if !pte_is_present(pdpte) { spin_unlock(&vmm_lock); return; }

    let pd = pte_get_frame(pdpte) as ptr<PageTable>;
    let pde = &((*pd).entries[pd_i as usize]) as ptr<PageTableEntry>;
    if !pte_is_present(pde) { spin_unlock(&vmm_lock); return; }

    let pt = pte_get_frame(pde) as ptr<PageTable>;
    let pte = &((*pt).entries[pt_i as usize]) as ptr<PageTableEntry>;
    
    pte_clear_flag(pte, 1);
    (*pte).entry = 0;
    
    invlpg(virt);
    spin_unlock(&vmm_lock);
}

fn vmm_get_phys(virt: u64) -> u64 {
    let (pml4_i, pdpt_i, pd_i, pt_i) = vmm_get_pt_index(virt);

    let pml4e = &((*vmm_pml4).entries[pml4_i as usize]) as ptr<PageTableEntry>;
    if !pte_is_present(pml4e) { return 0; }

    let pdpt = pte_get_frame(pml4e) as ptr<PageTable>;
    let pdpte = &((*pdpt).entries[pdpt_i as usize]) as ptr<PageTableEntry>;
    if !pte_is_present(pdpte) { return 0; }

    let pd = pte_get_frame(pdpte) as ptr<PageTable>;
    let pde = &((*pd).entries[pd_i as usize]) as ptr<PageTableEntry>;
    if !pte_is_present(pde) { return 0; }

    let pt = pte_get_frame(pde) as ptr<PageTable>;
    let pte = &((*pt).entries[pt_i as usize]) as ptr<PageTableEntry>;
    if !pte_is_present(pte) { return 0; }

    return pte_get_frame(pte) | (virt & 0xFFF);
}

struct RSDPDescriptor {
    signature: [u8; 8],
    checksum: u8,
    oem_id: [u8; 6],
    revision: u8,
    rsdt_address: u32,
}

struct RSDPDescriptor20 {
    first_part: RSDPDescriptor,
    length: u32,
    xsdt_address: u64,
    extended_checksum: u8,
    reserved: [u8; 3],
}

struct ACPISDTHeader {
    signature: [u8; 4],
    length: u32,
    revision: u8,
    checksum: u8,
    oem_id: [u8; 6],
    oem_table_id: [u8; 8],
    oem_revision: u32,
    creator_id: u32,
    creator_revision: u32,
}

struct MADTHeader {
    header: ACPISDTHeader,
    local_apic_addr: u32,
    flags: u32,
}

struct MCFGHeader {
    header: ACPISDTHeader,
    reserved: u64,
}

struct FADTHeader {
    header: ACPISDTHeader,
    firmware_ctrl: u32,
    dsdt: u32,
    reserved: u8,
    preferred_pm_profile: u8,
    sci_interrupt: u16,
    smi_cmd_port: u32,
    acpi_enable: u8,
    acpi_disable: u8,
    s4bios_req: u8,
    pstate_cnt: u8,
    pm1a_event_block: u32,
    pm1b_event_block: u32,
    pm1a_control_block: u32,
    pm1b_control_block: u32,
    pm2_control_block: u32,
    pm_timer_block: u32,
    gpe0_block: u32,
    gpe1_block: u32,
}

let mut acpi_rsdp: ptr<RSDPDescriptor20>;
let mut acpi_madt: ptr<MADTHeader>;
let mut acpi_mcfg: ptr<MCFGHeader>;
let mut acpi_fadt: ptr<FADTHeader>;
let mut global_lapic_base: u64 = 0xFEE00000;
let mut global_ioapic_base: u64 = 0xFEC00000;

fn acpi_checksum(ptr: ptr<u8>, length: u32) -> bool {
    let mut sum: u8 = 0;
    for i in 0..length {
        sum = sum + *(ptr + i as u64);
    }
    return sum == 0;
}

fn acpi_find_rsdp() -> ptr<RSDPDescriptor20> {
    let mut current: u64 = 0x000E0000;
    while current < 0x000FFFFF {
        if memcmp(current as ptr<u8>, "RSD PTR " as ptr<u8>, 8) == 0 {
            if acpi_checksum(current as ptr<u8>, 20) {
                return current as ptr<RSDPDescriptor20>;
            }
        }
        current = current + 16;
    }
    return 0 as ptr<RSDPDescriptor20>;
}

fn acpi_parse_madt(madt: ptr<MADTHeader>) {
    global_lapic_base = (*madt).local_apic_addr as u64;
    let mut current_ptr = (madt as u64 + sizeof(MADTHeader) as u64) as ptr<u8>;
    let end_ptr = (madt as u64 + (*madt).header.length as u64) as ptr<u8>;
    
    while current_ptr < end_ptr {
        let rec_type = *current_ptr;
        let rec_len = *(current_ptr + 1);
        if rec_type == 0 {
        } else if rec_type == 1 {
            let ioapic_addr = *((current_ptr + 4) as ptr<u32>);
            global_ioapic_base = ioapic_addr as u64;
        } else if rec_type == 2 {
        }
        current_ptr = current_ptr + rec_len as u64;
    }
}

fn acpi_init() {
    acpi_rsdp = acpi_find_rsdp();
    if acpi_rsdp == 0 as ptr<RSDPDescriptor20> { return; }
    
    let xsdt = (*acpi_rsdp).xsdt_address as ptr<ACPISDTHeader>;
    if xsdt as u64 != 0 && acpi_checksum(xsdt as ptr<u8>, (*xsdt).length) {
        let entries = ((*xsdt).length - sizeof(ACPISDTHeader) as u32) / 8;
        let table_ptrs = (xsdt as u64 + sizeof(ACPISDTHeader) as u64) as ptr<u64>;
        
        for i in 0..entries {
            let header = *(table_ptrs + i as u64) as ptr<ACPISDTHeader>;
            if memcmp((*header).signature as ptr<u8>, "APIC" as ptr<u8>, 4) == 0 {
                acpi_madt = header as ptr<MADTHeader>;
                acpi_parse_madt(acpi_madt);
            } else if memcmp((*header).signature as ptr<u8>, "MCFG" as ptr<u8>, 4) == 0 {
                acpi_mcfg = header as ptr<MCFGHeader>;
            } else if memcmp((*header).signature as ptr<u8>, "FACP" as ptr<u8>, 4) == 0 {
                acpi_fadt = header as ptr<FADTHeader>;
            }
        }
    }
}

const LAPIC_ID: u32 = 0x0020;
const LAPIC_VER: u32 = 0x0030;
const LAPIC_TPR: u32 = 0x0080;
const LAPIC_APR: u32 = 0x0090;
const LAPIC_PPR: u32 = 0x00A0;
const LAPIC_EOI: u32 = 0x00B0;
const LAPIC_RRD: u32 = 0x00C0;
const LAPIC_LDR: u32 = 0x00D0;
const LAPIC_DFR: u32 = 0x00E0;
const LAPIC_SVR: u32 = 0x00F0;
const LAPIC_ISR: u32 = 0x0100;
const LAPIC_TMR: u32 = 0x0180;
const LAPIC_IRR: u32 = 0x0200;
const LAPIC_ESR: u32 = 0x0280;
const LAPIC_ICRLO: u32 = 0x0300;
const LAPIC_ICRHI: u32 = 0x0310;
const LAPIC_TIMER: u32 = 0x0320;
const LAPIC_THERMAL: u32 = 0x0330;
const LAPIC_PERF: u32 = 0x0340;
const LAPIC_LINT0: u32 = 0x0350;
const LAPIC_LINT1: u32 = 0x0360;
const LAPIC_ERROR: u32 = 0x0370;
const LAPIC_TICR: u32 = 0x0380;
const LAPIC_TCCR: u32 = 0x0390;
const LAPIC_TDCR: u32 = 0x03E0;

fn lapic_write(reg: u32, val: u32) {
    let ptr = (global_lapic_base + reg as u64) as ptr<u32>;
    *ptr = val;
}

fn lapic_read(reg: u32) -> u32 {
    let ptr = (global_lapic_base + reg as u64) as ptr<u32>;
    return *ptr;
}

fn lapic_eoi() {
    lapic_write(LAPIC_EOI, 0);
}

fn lapic_init_cpu() {
    lapic_write(LAPIC_DFR, 0xFFFFFFFF);
    lapic_write(LAPIC_LDR, (lapic_read(LAPIC_LDR) & 0x00FFFFFF) | 1);
    lapic_write(LAPIC_LINT0, 0x10000);
    lapic_write(LAPIC_LINT1, 0x10000);
    lapic_write(LAPIC_TPR, 0);
    lapic_write(LAPIC_SVR, 0x1FF);
}

fn ioapic_write(reg: u8, val: u32) {
    let sel = global_ioapic_base as ptr<u32>;
    let win = (global_ioapic_base + 0x10) as ptr<u32>;
    *sel = reg as u32;
    *win = val;
}

fn ioapic_read(reg: u8) -> u32 {
    let sel = global_ioapic_base as ptr<u32>;
    let win = (global_ioapic_base + 0x10) as ptr<u32>;
    *sel = reg as u32;
    return *win;
}

fn ioapic_set_entry(irq: u8, vector: u8, apic_id: u8) {
    let low_idx = 0x10 + irq * 2;
    let high_idx = 0x10 + irq * 2 + 1;
    let low_val = vector as u32;
    let high_val = (apic_id as u32) << 24;
    ioapic_write(low_idx, low_val);
    ioapic_write(high_idx, high_val);
}

struct MCFGAllocation {
    base_address: u64,
    pci_segment_group: u16,
    start_bus_number: u8,
    end_bus_number: u8,
    reserved: u32,
}

struct PCIDeviceExt {
    base: u64,
    seg: u16,
    bus: u8,
    dev: u8,
    func: u8,
    vendor_id: u16,
    device_id: u16,
    class_code: u8,
    subclass: u8,
    prog_if: u8,
    bar0: u64,
    bar1: u64,
    bar2: u64,
    bar3: u64,
    bar4: u64,
    bar5: u64,
    irq: u8,
}

let mut pcie_devices: [PCIDeviceExt; 2048];
let mut pcie_device_count: u64 = 0;

fn pcie_read_16(base: u64, bus: u8, dev: u8, func: u8, offset: u16) -> u16 {
    let addr = base | ((bus as u64) << 20) | ((dev as u64) << 15) | ((func as u64) << 12) | (offset as u64);
    return *(addr as ptr<u16>);
}

fn pcie_read_32(base: u64, bus: u8, dev: u8, func: u8, offset: u16) -> u32 {
    let addr = base | ((bus as u64) << 20) | ((dev as u64) << 15) | ((func as u64) << 12) | (offset as u64);
    return *(addr as ptr<u32>);
}

fn pcie_write_32(base: u64, bus: u8, dev: u8, func: u8, offset: u16, val: u32) {
    let addr = base | ((bus as u64) << 20) | ((dev as u64) << 15) | ((func as u64) << 12) | (offset as u64);
    *(addr as ptr<u32>) = val;
}

fn pcie_scan_bus(base: u64, seg: u16, bus: u8) {
    for dev in 0..32 {
        let vendor = pcie_read_16(base, bus, dev as u8, 0, 0x00);
        if vendor != 0xFFFF {
            pcie_scan_func(base, seg, bus, dev as u8, 0);
            let header_type = (pcie_read_32(base, bus, dev as u8, 0, 0x0C) >> 16) & 0xFF;
            if (header_type & 0x80) != 0 {
                for func in 1..8 {
                    if pcie_read_16(base, bus, dev as u8, func as u8, 0x00) != 0xFFFF {
                        pcie_scan_func(base, seg, bus, dev as u8, func as u8);
                    }
                }
            }
        }
    }
}

fn pcie_scan_func(base: u64, seg: u16, bus: u8, dev: u8, func: u8) {
    let vendor = pcie_read_16(base, bus, dev, func, 0x00);
    let device = pcie_read_16(base, bus, dev, func, 0x02);
    let class_info = pcie_read_32(base, bus, dev, func, 0x08);
    let irq_info = pcie_read_32(base, bus, dev, func, 0x3C);
    
    let mut ext: PCIDeviceExt;
    ext.base = base;
    ext.seg = seg;
    ext.bus = bus;
    ext.dev = dev;
    ext.func = func;
    ext.vendor_id = vendor;
    ext.device_id = device;
    ext.class_code = (class_info >> 24) as u8;
    ext.subclass = (class_info >> 16) as u8;
    ext.prog_if = (class_info >> 8) as u8;
    ext.irq = (irq_info & 0xFF) as u8;
    
    let b0 = pcie_read_32(base, bus, dev, func, 0x10);
    if (b0 & 4) != 0 {
        ext.bar0 = (b0 & 0xFFFFFFF0) as u64 | ((pcie_read_32(base, bus, dev, func, 0x14) as u64) << 32);
    } else {
        ext.bar0 = (b0 & 0xFFFFFFF0) as u64;
    }
    
    let b5 = pcie_read_32(base, bus, dev, func, 0x24);
    if (b5 & 4) != 0 {
        ext.bar5 = (b5 & 0xFFFFFFF0) as u64 | ((pcie_read_32(base, bus, dev, func, 0x28) as u64) << 32);
    } else {
        ext.bar5 = (b5 & 0xFFFFFFF0) as u64;
    }

    pcie_devices[pcie_device_count as usize] = ext;
    pcie_device_count = pcie_device_count + 1;
}

fn pcie_init() {
    if acpi_mcfg == 0 as ptr<MCFGHeader> { return; }
    let entries = ((*acpi_mcfg).header.length - sizeof(MCFGHeader) as u32) / sizeof(MCFGAllocation) as u32;
    let allocs = (acpi_mcfg as u64 + sizeof(MCFGHeader) as u64) as ptr<MCFGAllocation>;
    
    for i in 0..entries {
        let alloc = &(*allocs.offset(i as isize));
        for bus in (*alloc).start_bus_number..=(*alloc).end_bus_number {
            pcie_scan_bus((*alloc).base_address, (*alloc).pci_segment_group, bus);
        }
    }
}

struct AHCIPortRegs {
    clb: u64,
    fb: u64,
    is: u32,
    ie: u32,
    cmd: u32,
    rsv0: u32,
    tfd: u32,
    sig: u32,
    ssts: u32,
    sctl: u32,
    serr: u32,
    sact: u32,
    ci: u32,
    sntf: u32,
    fbs: u32,
    devslp: u32,
    rsv1: [u32; 10],
    vendor: [u32; 4],
}

struct AHCIHBARegs {
    cap: u32,
    ghc: u32,
    is: u32,
    pi: u32,
    vs: u32,
    ccc_ctl: u32,
    ccc_pts: u32,
    em_loc: u32,
    em_ctl: u32,
    cap2: u32,
    bohc: u32,
    rsv: [u8; 116],
    ports: [AHCIPortRegs; 32],
}

struct AHCICmdHeader {
    cfl_p_r_c: u16,
    prdtl: u16,
    prdbc: u32,
    ctba: u64,
    rsv1: [u32; 4],
}

struct AHCIPRDTEntry {
    dba: u64,
    rsv0: u32,
    dbc_i: u32,
}

struct AHCICmdTable {
    cfis: [u8; 64],
    acmd: [u8; 16],
    rsv: [u8; 48],
    prdt_entry: [AHCIPRDTEntry; 65536 / 8],
}

let mut global_ahci_hba: ptr<AHCIHBARegs>;

fn ahci_port_start(port: ptr<AHCIPortRegs>) {
    while ((*port).cmd & 0x8000) != 0 {}
    (*port).cmd |= 0x0010;
    (*port).cmd |= 0x0001;
}

fn ahci_port_stop(port: ptr<AHCIPortRegs>) {
    (*port).cmd &= !0x0001;
    (*port).cmd &= !0x0010;
    while ((*port).cmd & 0x4000) != 0 || ((*port).cmd & 0x8000) != 0 {}
}

fn ahci_init_port(port: ptr<AHCIPortRegs>) {
    ahci_port_stop(port);
    let clb_phys = pmm_alloc_block();
    let fb_phys = pmm_alloc_block();
    let ctba_phys = pmm_alloc_block();
    
    (*port).clb = clb_phys;
    (*port).fb = fb_phys;
    
    let cmd_header = clb_phys as ptr<AHCICmdHeader>;
    memset(cmd_header as ptr<u8>, 0, 1024);
    memset(fb_phys as ptr<u8>, 0, 256);
    memset(ctba_phys as ptr<u8>, 0, PAGE_SIZE);
    
    (*cmd_header).prdtl = 1;
    (*cmd_header).ctba = ctba_phys;
    
    ahci_port_start(port);
}

fn ahci_init_controller(bar5: u64) {
    global_ahci_hba = bar5 as ptr<AHCIHBARegs>;
    (*global_ahci_hba).ghc |= 0x80000000;
    
    for i in 0..32 {
        let pi = (*global_ahci_hba).pi;
        if (pi & (1 << i)) != 0 {
            let port = &((*global_ahci_hba).ports[i as usize]) as ptr<AHCIPortRegs>;
            let ssts = (*port).ssts;
            let ipm = (ssts >> 8) & 0x0F;
            let det = ssts & 0x0F;
            let sig = (*port).sig;
            
            if det == 3 && ipm == 1 {
                if sig == 0x00000101 {
                    ahci_init_port(port);
                }
            }
        }
    }
}

struct NVMeBarRegs {
    cap: u64,
    vs: u32,
    intms: u32,
    intmc: u32,
    cc: u32,
    csts: u32,
    nssr: u32,
    aqa: u32,
    asq: u64,
    acq: u64,
    cmbloc: u32,
    cmbsz: u32,
    bpinfo: u32,
    bprsel: u32,
    bpmbl: u64,
    cmbmsc: u64,
    cmbsts: u32,
}

struct NVMeCmd {
    cdw0: u32,
    nsid: u32,
    rsv2: u64,
    mptr: u64,
    dptr1: u64,
    dptr2: u64,
    cdw10: u32,
    cdw11: u32,
    cdw12: u32,
    cdw13: u32,
    cdw14: u32,
    cdw15: u32,
}

struct NVMeCpl {
    cdw0: u32,
    rsv1: u32,
    sqhd: u16,
    sqid: u16,
    cid: u16,
    status: u16,
}

let mut global_nvme_bar: ptr<NVMeBarRegs>;
let mut nvme_admin_sq: ptr<NVMeCmd>;
let mut nvme_admin_cq: ptr<NVMeCpl>;
let mut nvme_sq_tail: u32 = 0;
let mut nvme_cq_head: u32 = 0;
let mut nvme_cq_phase: u16 = 1;

fn nvme_submit_cmd(cmd: ptr<NVMeCmd>) {
    let mut sq_ptr = nvme_admin_sq as u64 + (nvme_sq_tail as u64 * sizeof(NVMeCmd) as u64);
    memcpy(sq_ptr as ptr<u8>, cmd as ptr<u8>, sizeof(NVMeCmd) as u64);
    nvme_sq_tail = (nvme_sq_tail + 1) % 64;
    let doorbell = (global_nvme_bar as u64 + 0x1000) as ptr<u32>;
    *doorbell = nvme_sq_tail;
}

fn nvme_poll_cq() -> ptr<NVMeCpl> {
    let mut cq_ptr = (nvme_admin_cq as u64 + (nvme_cq_head as u64 * sizeof(NVMeCpl) as u64)) as ptr<NVMeCpl>;
    while ((*cq_ptr).status & 0x01) != nvme_cq_phase {
        cpu_pause();
    }
    nvme_cq_head = (nvme_cq_head + 1) % 64;
    if nvme_cq_head == 0 {
        nvme_cq_phase = nvme_cq_phase ^ 1;
    }
    let doorbell = (global_nvme_bar as u64 + 0x1004) as ptr<u32>;
    *doorbell = nvme_cq_head;
    return cq_ptr;
}

fn nvme_init_controller(bar0: u64) {
    global_nvme_bar = bar0 as ptr<NVMeBarRegs>;
    (*global_nvme_bar).cc &= 0xFFFFFFFE;
    while ((*global_nvme_bar).csts & 1) != 0 { }
    nvme_admin_sq = pmm_alloc_blocks(1) as ptr<NVMeCmd>;
    nvme_admin_cq = pmm_alloc_blocks(1) as ptr<NVMeCpl>;
    memset(nvme_admin_sq as ptr<u8>, 0, PAGE_SIZE);
    memset(nvme_admin_cq as ptr<u8>, 0, PAGE_SIZE);
    (*global_nvme_bar).aqa = 0x003F003F;
    (*global_nvme_bar).asq = nvme_admin_sq as u64;
    (*global_nvme_bar).acq = nvme_admin_cq as u64;
    let iocqes = 4;
    let iosqes = 6;
    (*global_nvme_bar).cc = (iocqes << 20) | (iosqes << 16) | 0x00460001;
    while ((*global_nvme_bar).csts & 1) == 0 { }
}

struct XHCICapRegs {
    caplength: u8,
    rsvd: u8,
    hciversion: u16,
    hcsparams1: u32,
    hcsparams2: u32,
    hcsparams3: u32,
    hccparams1: u32,
    dboff: u32,
    rtsoff: u32,
    hccparams2: u32,
}

struct XHCIOpRegs {
    usbcmd: u32,
    usbsts: u32,
    pagesize: u32,
    rsvd1: [u32; 2],
    dnctrl: u32,
    crcr: u64,
    rsvd2: [u32; 4],
    dcbaap: u64,
    config: u32,
}

struct XHCIPortRegs {
    portsc: u32,
    portpmsc: u32,
    portli: u32,
    porthlpmc: u32,
}

struct XHCITrb {
    param: u64,
    status: u32,
    control: u32,
}

let mut global_xhci_cap: ptr<XHCICapRegs>;
let mut global_xhci_op: ptr<XHCIOpRegs>;
let mut xhci_cmd_ring: ptr<XHCITrb>;
let mut xhci_dcbaa: ptr<u64>;

fn xhci_reset() {
    (*global_xhci_op).usbcmd &= 0xFFFFFFFE;
    while ((*global_xhci_op).usbsts & 1) == 0 { }
    (*global_xhci_op).usbcmd |= 2;
    while ((*global_xhci_op).usbcmd & 2) != 0 { }
    while ((*global_xhci_op).usbsts & (1 << 11)) != 0 { }
}

fn xhci_init_controller(bar0: u64) {
    global_xhci_cap = bar0 as ptr<XHCICapRegs>;
    global_xhci_op = (bar0 + (*global_xhci_cap).caplength as u64) as ptr<XHCIOpRegs>;
    xhci_reset();
    let max_slots = (*global_xhci_cap).hcsparams1 & 0xFF;
    (*global_xhci_op).config = max_slots;
    xhci_dcbaa = pmm_alloc_blocks(1) as ptr<u64>;
    memset(xhci_dcbaa as ptr<u8>, 0, PAGE_SIZE);
    (*global_xhci_op).dcbaap = xhci_dcbaa as u64;
    xhci_cmd_ring = pmm_alloc_blocks(1) as ptr<XHCITrb>;
    memset(xhci_cmd_ring as ptr<u8>, 0, PAGE_SIZE);
    (*global_xhci_op).crcr = (xhci_cmd_ring as u64) | 1;
    (*global_xhci_op).usbcmd |= 1;
    while ((*global_xhci_op).usbsts & 1) != 0 { }
}

let mut rtl_iobase: u64 = 0;
let mut rtl_rx_buffer: ptr<u8>;
let mut rtl_tx_buffers: [ptr<u8>; 4];
let mut rtl_tx_idx: u8 = 0;

fn rtl_outb(offset: u16, data: u8) { outb((rtl_iobase + offset as u64) as u16, data); }
fn rtl_outw(offset: u16, data: u16) { outw((rtl_iobase + offset as u64) as u16, data); }
fn rtl_outl(offset: u16, data: u32) { outl((rtl_iobase + offset as u64) as u16, data); }
fn rtl_inb(offset: u16) -> u8 { return inb((rtl_iobase + offset as u64) as u16); }
fn rtl_inw(offset: u16) -> u16 { return inw((rtl_iobase + offset as u64) as u16); }
fn rtl_inl(offset: u16) -> u32 { return inl((rtl_iobase + offset as u64) as u16); }

fn rtl8139_init(bar0: u64) {
    rtl_iobase = bar0 & 0xFFFFFFFFFFFFFFFC;
    rtl_outb(0x52, 0);
    rtl_outb(0x37, 0x10);
    while (rtl_inb(0x37) & 0x10) != 0 { }
    rtl_rx_buffer = pmm_alloc_blocks(3) as ptr<u8>;
    memset(rtl_rx_buffer, 0, 8192 + 16 + 1500);
    rtl_outl(0x30, rtl_rx_buffer as u64 as u32);
    for i in 0..4 {
        rtl_tx_buffers[i] = pmm_alloc_blocks(1) as ptr<u8>;
        memset(rtl_tx_buffers[i], 0, PAGE_SIZE);
    }
    rtl_outw(0x3C, 0x0005);
    let rx_config: u32 = 0x0000000F | 0x00000080;
    rtl_outl(0x44, rx_config);
    rtl_outb(0x37, 0x0C);
}

fn rtl8139_send(packet: ptr<u8>, length: u32) {
    let tx_addr = rtl_tx_buffers[rtl_tx_idx as usize];
    memcpy(tx_addr, packet, length as u64);
    let port = 0x20 + (rtl_tx_idx as u16 * 4);
    rtl_outl(port, tx_addr as u64 as u32);
    let status_port = 0x10 + (rtl_tx_idx as u16 * 4);
    rtl_outl(status_port, length);
    rtl_tx_idx = (rtl_tx_idx + 1) % 4;
}

struct MacAddr { addr: [u8; 6] }
struct Ipv4Addr { addr: [u8; 4] }

struct EthernetHeader {
    dest_mac: MacAddr,
    src_mac: MacAddr,
    ethertype: u16,
}

struct ArpHeader {
    hw_type: u16,
    proto_type: u16,
    hw_len: u8,
    proto_len: u8,
    opcode: u16,
    sender_mac: MacAddr,
    sender_ip: Ipv4Addr,
    target_mac: MacAddr,
    target_ip: Ipv4Addr,
}

struct Ipv4Header {
    ihl_version: u8,
    tos: u8,
    total_length: u16,
    id: u16,
    flags_frag: u16,
    ttl: u8,
    protocol: u8,
    checksum: u16,
    src_ip: Ipv4Addr,
    dest_ip: Ipv4Addr,
}

struct UdpHeader {
    src_port: u16,
    dest_port: u16,
    length: u16,
    checksum: u16,
}

struct TcpHeader {
    src_port: u16,
    dest_port: u16,
    seq_num: u32,
    ack_num: u32,
    data_offset_flags: u16,
    window_size: u16,
    checksum: u16,
    urgent_ptr: u16,
}

let mut system_mac: MacAddr;
let mut system_ip: Ipv4Addr;

fn htons(hostshort: u16) -> u16 {
    return (hostshort >> 8) | (hostshort << 8);
}

fn htonl(hostlong: u32) -> u32 {
    return ((hostlong & 0xFF) << 24) | ((hostlong & 0xFF00) << 8) | ((hostlong & 0xFF0000) >> 8) | ((hostlong >> 24) & 0xFF);
}

fn calculate_checksum(data: ptr<u8>, length: u32) -> u16 {
    let mut sum: u32 = 0;
    let mut ptr16 = data as ptr<u16>;
    let mut len = length;
    while len > 1 {
        sum = sum + *ptr16 as u32;
        ptr16 = (ptr16 as u64 + 2) as ptr<u16>;
        len = len - 2;
    }
    if len == 1 {
        let mut last_byte: u16 = 0;
        *(last_byte as u64 as ptr<u8>) = *(ptr16 as ptr<u8>);
        sum = sum + last_byte as u32;
    }
    while (sum >> 16) != 0 {
        sum = (sum & 0xFFFF) + (sum >> 16);
    }
    return (!sum) as u16;
}

fn arp_send_request(target_ip: Ipv4Addr) {
    let packet_size = sizeof(EthernetHeader) as u64 + sizeof(ArpHeader) as u64;
    let packet = pmm_alloc_blocks(1) as ptr<u8>;
    let eth = packet as ptr<EthernetHeader>;
    for i in 0..6 { (*eth).dest_mac.addr[i] = 0xFF; }
    for i in 0..6 { (*eth).src_mac.addr[i] = system_mac.addr[i]; }
    (*eth).ethertype = htons(0x0806);
    
    let arp = (packet as u64 + sizeof(EthernetHeader) as u64) as ptr<ArpHeader>;
    (*arp).hw_type = htons(0x0001);
    (*arp).proto_type = htons(0x0800);
    (*arp).hw_len = 6;
    (*arp).proto_len = 4;
    (*arp).opcode = htons(0x0001);
    for i in 0..6 { (*arp).sender_mac.addr[i] = system_mac.addr[i]; }
    for i in 0..4 { (*arp).sender_ip.addr[i] = system_ip.addr[i]; }
    for i in 0..6 { (*arp).target_mac.addr[i] = 0x00; }
    for i in 0..4 { (*arp).target_ip.addr[i] = target_ip.addr[i]; }
    
    rtl8139_send(packet, packet_size as u32);
    pmm_free_block(packet as u64);
}

struct CpuContext {
    r15: u64, r14: u64, r13: u64, r12: u64,
    r11: u64, r10: u64, r9: u64, r8: u64,
    rdi: u64, rsi: u64, rbp: u64, rbx: u64,
    rdx: u64, rcx: u64, rax: u64,
    rip: u64, cs: u64, rflags: u64, rsp: u64, ss: u64,
}

struct ProcessControlBlock {
    pid: u64,
    cr3_phys: u64,
    context: ptr<CpuContext>,
    state: u8,
    priority: u8,
    time_slice: u64,
    next: ptr<ProcessControlBlock>,
}

let mut current_process: ptr<ProcessControlBlock>;
let mut process_queue: ptr<ProcessControlBlock>;
let mut global_pid_counter: u64 = 1000;

fn create_process(entry_point: u64, is_kernel: bool) -> ptr<ProcessControlBlock> {
    let pcb = pmm_alloc_blocks(1) as ptr<ProcessControlBlock>;
    memset(pcb as ptr<u8>, 0, sizeof(ProcessControlBlock) as u64);
    (*pcb).pid = global_pid_counter;
    global_pid_counter = global_pid_counter + 1;
    let stack_phys = pmm_alloc_blocks(4);
    let stack_top = stack_phys + (PAGE_SIZE * 4);
    let ctx = (stack_top - sizeof(CpuContext) as u64) as ptr<CpuContext>;
    memset(ctx as ptr<u8>, 0, sizeof(CpuContext) as u64);
    (*ctx).rip = entry_point;
    (*ctx).rflags = 0x202;
    (*ctx).rsp = stack_top;
    if is_kernel {
        (*ctx).cs = 0x08;
        (*ctx).ss = 0x10;
        (*pcb).cr3_phys = vmm_pml4 as u64;
    } else {
        (*ctx).cs = 0x1B;
        (*ctx).ss = 0x23;
        (*pcb).cr3_phys = pmm_alloc_blocks(1);
        memset((*pcb).cr3_phys as ptr<u8>, 0, PAGE_SIZE);
    }
    (*pcb).context = ctx;
    (*pcb).state = 1;
    (*pcb).time_slice = 10;
    (*pcb).next = process_queue;
    process_queue = pcb;
    return pcb;
}

fn switch_context(next: ptr<ProcessControlBlock>) {
    let prev = current_process;
    current_process = next;
    asm {
        "mov rsp, %0\n"
        "mov cr3, %1\n"
        "pop r15\n pop r14\n pop r13\n pop r12\n"
        "pop r11\n pop r10\n pop r9\n pop r8\n"
        "pop rdi\n pop rsi\n pop rbp\n pop rbx\n"
        "pop rdx\n pop rcx\n pop rax\n"
        "iretq"
        in "%0" = (*next).context;
        in "%1" = (*next).cr3_phys;
    }
}

fn scheduler_tick() {
    if current_process == 0 as ptr<ProcessControlBlock> {
        if process_queue != 0 as ptr<ProcessControlBlock> {
            switch_context(process_queue);
        }
        return;
    }
    (*current_process).time_slice = (*current_process).time_slice - 1;
    if (*current_process).time_slice == 0 {
        (*current_process).time_slice = 10;
        let mut next = (*current_process).next;
        if next == 0 as ptr<ProcessControlBlock> {
            next = process_queue;
        }
        if next != current_process {
            switch_context(next);
        }
    }
}

struct VfsStat {
    size: u64,
    inode: u64,
    flags: u32,
    uid: u32,
    gid: u32,
}

struct VfsNode {
    name: [u8; 128],
    mask: u32,
    uid: u32,
    gid: u32,
    flags: u32,
    inode: u64,
    length: u64,
    read_fn: u64,
    write_fn: u64,
    open_fn: u64,
    close_fn: u64,
    readdir_fn: u64,
    finddir_fn: u64,
    ptr: u64,
    parent: ptr<VfsNode>,
    children: ptr<VfsNode>,
    next: ptr<VfsNode>,
}

struct FileDescriptor {
    node: ptr<VfsNode>,
    offset: u64,
    flags: u32,
}

let mut global_vfs_root: ptr<VfsNode>;
let mut next_inode: u64 = 1;

fn vfs_init_system() {
    global_vfs_root = pmm_alloc_blocks(1) as ptr<VfsNode>;
    memset(global_vfs_root as ptr<u8>, 0, sizeof(VfsNode) as u64);
    strcpy(&((*global_vfs_root).name[0]), "/" as ptr<u8>);
    (*global_vfs_root).flags = 0x07;
    (*global_vfs_root).inode = 0;
}

fn vfs_create_node(parent: ptr<VfsNode>, name: ptr<u8>, flags: u32) -> ptr<VfsNode> {
    let node = pmm_alloc_blocks(1) as ptr<VfsNode>;
    memset(node as ptr<u8>, 0, sizeof(VfsNode) as u64);
    strcpy(&((*node).name[0]), name);
    (*node).flags = flags;
    (*node).inode = next_inode;
    next_inode = next_inode + 1;
    (*node).parent = parent;
    if (*parent).children == 0 as ptr<VfsNode> {
        (*parent).children = node;
    } else {
        let mut curr = (*parent).children;
        while (*curr).next != 0 as ptr<VfsNode> {
            curr = (*curr).next;
        }
        (*curr).next = node;
    }
    return node;
}

fn vfs_find_child(parent: ptr<VfsNode>, name: ptr<u8>) -> ptr<VfsNode> {
    let mut curr = (*parent).children;
    while curr != 0 as ptr<VfsNode> {
        if strcmp(&((*curr).name[0]), name) == 0 {
            return curr;
        }
        curr = (*curr).next;
    }
    return 0 as ptr<VfsNode>;
}

fn vfs_read(fd: ptr<FileDescriptor>, buffer: ptr<u8>, size: u64) -> u64 {
    if (*fd).node == 0 as ptr<VfsNode> { return 0; }
    if ((*(*fd).node).flags & 0x07) != 0 { return 0; }
    let mut read_sz = size;
    if (*fd).offset + size > (*(*fd).node).length {
        read_sz = (*(*fd).node).length - (*fd).offset;
    }
    let data_ptr = (*(*fd).node).ptr as ptr<u8>;
    memcpy(buffer, (data_ptr as u64 + (*fd).offset) as ptr<u8>, read_sz);
    (*fd).offset = (*fd).offset + read_sz;
    return read_sz;
}

fn vfs_write(fd: ptr<FileDescriptor>, buffer: ptr<u8>, size: u64) -> u64 {
    if (*fd).node == 0 as ptr<VfsNode> { return 0; }
    if ((*(*fd).node).flags & 0x07) != 0 { return 0; }
    let data_ptr = (*(*fd).node).ptr as ptr<u8>;
    memcpy((data_ptr as u64 + (*fd).offset) as ptr<u8>, buffer, size);
    (*fd).offset = (*fd).offset + size;
    if (*fd).offset > (*(*fd).node).length {
        (*(*fd).node).length = (*fd).offset;
    }
    return size;
}

let mut sha256_k: [u32; 64] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
];

fn rotr32(x: u32, n: u32) -> u32 { return (x >> n) | (x << (32 - n)); }
fn ch(x: u32, y: u32, z: u32) -> u32 { return (x & y) ^ (!x & z); }
fn maj(x: u32, y: u32, z: u32) -> u32 { return (x & y) ^ (x & z) ^ (y & z); }
fn sig0(x: u32) -> u32 { return rotr32(x, 2) ^ rotr32(x, 13) ^ rotr32(x, 22); }
fn sig1(x: u32) -> u32 { return rotr32(x, 6) ^ rotr32(x, 11) ^ rotr32(x, 25); }
fn ep0(x: u32) -> u32 { return rotr32(x, 7) ^ rotr32(x, 18) ^ (x >> 3); }
fn ep1(x: u32) -> u32 { return rotr32(x, 17) ^ rotr32(x, 19) ^ (x >> 10); }

struct Sha256Ctx {
    state: [u32; 8],
    count: [u32; 2],
    buffer: [u8; 64],
}

fn sha256_transform(ctx: ptr<Sha256Ctx>, data: ptr<u8>) {
    let mut w: [u32; 64];
    for i in 0..16 {
        w[i] = ((*(data + i as u64 * 4) as u32) << 24) | ((*(data + i as u64 * 4 + 1) as u32) << 16) | ((*(data + i as u64 * 4 + 2) as u32) << 8) | (*(data + i as u64 * 4 + 3) as u32);
    }
    for i in 16..64 {
        w[i] = ep1(w[i - 2]) + w[i - 7] + ep0(w[i - 15]) + w[i - 16];
    }
    let mut a = (*ctx).state[0]; let mut b = (*ctx).state[1]; let mut c = (*ctx).state[2]; let mut d = (*ctx).state[3];
    let mut e = (*ctx).state[4]; let mut f = (*ctx).state[5]; let mut g = (*ctx).state[6]; let mut h = (*ctx).state[7];
    for i in 0..64 {
        let t1 = h + sig1(e) + ch(e, f, g) + sha256_k[i] + w[i];
        let t2 = sig0(a) + maj(a, b, c);
        h = g; g = f; f = e; e = d + t1;
        d = c; c = b; b = a; a = t1 + t2;
    }
    (*ctx).state[0] += a; (*ctx).state[1] += b; (*ctx).state[2] += c; (*ctx).state[3] += d;
    (*ctx).state[4] += e; (*ctx).state[5] += f; (*ctx).state[6] += g; (*ctx).state[7] += h;
}

fn sha256_init(ctx: ptr<Sha256Ctx>) {
    (*ctx).count[0] = 0; (*ctx).count[1] = 0;
    (*ctx).state[0] = 0x6a09e667; (*ctx).state[1] = 0xbb67ae85;
    (*ctx).state[2] = 0x3c6ef372; (*ctx).state[3] = 0xa54ff53a;
    (*ctx).state[4] = 0x510e527f; (*ctx).state[5] = 0x9b05688c;
    (*ctx).state[6] = 0x1f83d9ab; (*ctx).state[7] = 0x5be0cd19;
}

let mut aes_sbox: [u8; 256] = [
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16
];

fn sub_word(w: u32) -> u32 {
    let b0 = aes_sbox[(w & 0xFF) as usize] as u32;
    let b1 = aes_sbox[((w >> 8) & 0xFF) as usize] as u32;
    let b2 = aes_sbox[((w >> 16) & 0xFF) as usize] as u32;
    let b3 = aes_sbox[((w >> 24) & 0xFF) as usize] as u32;
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
}

struct CompositorWindow {
    id: u64,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    z_index: u32,
    flags: u32,
    title: [u8; 64],
    buffer_phys: u64,
    next: ptr<CompositorWindow>,
}

let mut comp_root_window: ptr<CompositorWindow>;
let mut comp_active_window: ptr<CompositorWindow>;
let mut comp_back_buffer: ptr<u32>;
let mut comp_width: u32 = 1920;
let mut comp_height: u32 = 1080;
let mut comp_next_id: u64 = 1;

fn comp_init(fb_base: u64, w: u32, h: u32) {
    comp_width = w;
    comp_height = h;
    comp_back_buffer = pmm_alloc_blocks((w * h * 4) / PAGE_SIZE + 1) as ptr<u32>;
    memset(comp_back_buffer as ptr<u8>, 0, (w * h * 4) as u64);
    fb_ptr = fb_base as ptr<u32>;
}

fn comp_create_window(x: u32, y: u32, w: u32, h: u32, title: ptr<u8>) -> ptr<CompositorWindow> {
    let win = pmm_alloc_blocks(1) as ptr<CompositorWindow>;
    memset(win as ptr<u8>, 0, sizeof(CompositorWindow) as u64);
    (*win).id = comp_next_id;
    comp_next_id = comp_next_id + 1;
    (*win).x = x;
    (*win).y = y;
    (*win).width = w;
    (*win).height = h;
    (*win).z_index = 100;
    strcpy(&((*win).title[0]), title);
    let buf_sz = w * h * 4;
    (*win).buffer_phys = pmm_alloc_blocks(buf_sz as u64 / PAGE_SIZE + 1);
    memset((*win).buffer_phys as ptr<u8>, 0xFF, buf_sz as u64);
    (*win).next = comp_root_window;
    comp_root_window = win;
    comp_active_window = win;
    return win;
}

fn comp_draw_rect(win: ptr<CompositorWindow>, x: u32, y: u32, w: u32, h: u32, color: u32) {
    let buf = (*win).buffer_phys as ptr<u32>;
    for i in 0..h {
        for j in 0..w {
            if (x + j) < (*win).width && (y + i) < (*win).height {
                *(buf + ((y + i) * (*win).width + (x + j)) as u64) = color;
            }
        }
    }
}

fn comp_render() {
    let bg_color = 0x2c3e50;
    for i in 0..(comp_width * comp_height) {
        *(comp_back_buffer + i as u64) = bg_color;
    }
    let mut curr = comp_root_window;
    while curr != 0 as ptr<CompositorWindow> {
        let buf = (*curr).buffer_phys as ptr<u32>;
        for i in 0..(*curr).height {
            for j in 0..(*curr).width {
                let screen_y = (*curr).y + i;
                let screen_x = (*curr).x + j;
                if screen_x < comp_width && screen_y < comp_height {
                    let pixel = *(buf + (i * (*curr).width + j) as u64);
                    *(comp_back_buffer + (screen_y * comp_width + screen_x) as u64) = pixel;
                }
            }
        }
        curr = (*curr).next;
    }
    memcpy(fb_ptr as ptr<u8>, comp_back_buffer as ptr<u8>, (comp_width * comp_height * 4) as u64);
}

const ELF_MAGIC: u32 = 0x464C457F;

struct Elf64_Ehdr {
    e_ident: [u8; 16],
    e_type: u16,
    e_machine: u16,
    e_version: u32,
    e_entry: u64,
    e_phoff: u64,
    e_shoff: u64,
    e_flags: u32,
    e_ehsize: u16,
    e_phentsize: u16,
    e_phnum: u16,
    e_shentsize: u16,
    e_shnum: u16,
    e_shstrndx: u16,
}

struct Elf64_Phdr {
    p_type: u32,
    p_flags: u32,
    p_offset: u64,
    p_vaddr: u64,
    p_paddr: u64,
    p_filesz: u64,
    p_memsz: u64,
    p_align: u64,
}

struct AegisPermissionMatrix {
    uid: u32,
    gid: u32,
    capabilities: u64,
    network_access: u8,
    fs_access: u8,
    hw_access: u8,
    max_memory: u64,
}

let mut global_aegis_matrix: [AegisPermissionMatrix; 1024];
let mut aegis_matrix_count: u32 = 0;

fn aegis_register_process(pid: u64, uid: u32, gid: u32, caps: u64) {
    let mut idx = aegis_matrix_count;
    global_aegis_matrix[idx as usize].uid = uid;
    global_aegis_matrix[idx as usize].gid = gid;
    global_aegis_matrix[idx as usize].capabilities = caps;
    global_aegis_matrix[idx as usize].network_access = 1;
    global_aegis_matrix[idx as usize].fs_access = 1;
    global_aegis_matrix[idx as usize].hw_access = 0;
    global_aegis_matrix[idx as usize].max_memory = 0x10000000;
    aegis_matrix_count = aegis_matrix_count + 1;
}

fn aegis_verify_execution(node: ptr<VfsNode>, uid: u32) -> bool {
    if (*node).uid != uid && uid != 0 {
        if ((*node).flags & 0x01) == 0 {
            return false;
        }
    }
    return true;
}

fn elf_check_header(hdr: ptr<Elf64_Ehdr>) -> bool {
    let magic = *(hdr as ptr<u32>);
    if magic != ELF_MAGIC { return false; }
    if (*hdr).e_ident[4] != 2 { return false; }
    if (*hdr).e_ident[5] != 1 { return false; }
    if (*hdr).e_machine != 62 { return false; }
    return true;
}

fn elf_load_segment(phdr: ptr<Elf64_Phdr>, fd: ptr<FileDescriptor>, cr3: u64) {
    let mut vaddr = (*phdr).p_vaddr;
    let memsz = (*phdr).p_memsz;
    let filesz = (*phdr).p_filesz;
    let offset = (*phdr).p_offset;
    
    let pages = (memsz + PAGE_SIZE - 1) / PAGE_SIZE;
    let mut current_vaddr = vaddr & !(PAGE_SIZE - 1);
    
    for i in 0..pages {
        let phys = pmm_alloc_blocks(1);
        memset(phys as ptr<u8>, 0, PAGE_SIZE);
        let flags = 0x07;
        vmm_map_page(phys, current_vaddr, flags);
        current_vaddr = current_vaddr + PAGE_SIZE;
    }
    
    (*fd).offset = offset;
    let mut buffer = vaddr as ptr<u8>;
    vfs_read(fd, buffer, filesz);
}

fn execve_ring3(path: ptr<u8>, uid: u32, gid: u32) -> u64 {
    let root = global_vfs_root;
    let mut curr = root;
    let mut node = vfs_find_child(curr, path);
    if node == 0 as ptr<VfsNode> { return 0; }
    
    if !aegis_verify_execution(node, uid) { return 0; }
    
    let mut fd: FileDescriptor;
    fd.node = node;
    fd.offset = 0;
    fd.flags = 0;
    
    let mut hdr_buf: [u8; 64];
    vfs_read(&fd, &hdr_buf[0] as ptr<u8>, 64);
    let ehdr = &hdr_buf[0] as ptr<Elf64_Ehdr>;
    
    if !elf_check_header(ehdr) { return 0; }
    
    let process = create_process((*ehdr).e_entry, false);
    aegis_register_process((*process).pid, uid, gid, 0xFFFFFFFF);
    
    let phdr_size = (*ehdr).e_phnum as u64 * (*ehdr).e_phentsize as u64;
    let phdr_buf = pmm_alloc_blocks((phdr_size / PAGE_SIZE) + 1) as ptr<u8>;
    
    fd.offset = (*ehdr).e_phoff;
    vfs_read(&fd, phdr_buf, phdr_size);
    
    for i in 0..(*ehdr).e_phnum {
        let phdr = (phdr_buf as u64 + (i as u64 * (*ehdr).e_phentsize as u64)) as ptr<Elf64_Phdr>;
        if (*phdr).p_type == 1 {
            elf_load_segment(phdr, &fd, (*process).cr3_phys);
        }
    }
    
    pmm_free_blocks(phdr_buf as u64, (phdr_size / PAGE_SIZE) + 1);
    return (*process).pid;
}

struct IpcMessage {
    sender_pid: u64,
    target_pid: u64,
    msg_type: u32,
    length: u32,
    data: [u8; 112],
    next: ptr<IpcMessage>,
}

struct IpcQueue {
    owner_pid: u64,
    head: ptr<IpcMessage>,
    tail: ptr<IpcMessage>,
    msg_count: u32,
    lock: Spinlock,
}

let mut global_ipc_queues: [IpcQueue; 1024];
let mut ipc_queue_count: u32 = 0;

fn ipc_create_queue(pid: u64) {
    let mut q = &global_ipc_queues[ipc_queue_count as usize];
    (*q).owner_pid = pid;
    (*q).head = 0 as ptr<IpcMessage>;
    (*q).tail = 0 as ptr<IpcMessage>;
    (*q).msg_count = 0;
    spin_init(&((*q).lock));
    ipc_queue_count = ipc_queue_count + 1;
}

fn ipc_send_message(target_pid: u64, sender_pid: u64, mtype: u32, data: ptr<u8>, len: u32) -> u32 {
    let mut target_q = 0 as ptr<IpcQueue>;
    for i in 0..ipc_queue_count {
        if global_ipc_queues[i as usize].owner_pid == target_pid {
            target_q = &global_ipc_queues[i as usize];
        }
    }
    if target_q == 0 as ptr<IpcQueue> { return 1; }
    
    let msg = pmm_alloc_blocks(1) as ptr<IpcMessage>;
    memset(msg as ptr<u8>, 0, sizeof(IpcMessage) as u64);
    (*msg).sender_pid = sender_pid;
    (*msg).target_pid = target_pid;
    (*msg).msg_type = mtype;
    let mut c_len = len;
    if c_len > 112 { c_len = 112; }
    (*msg).length = c_len;
    memcpy(&((*msg).data[0]) as ptr<u8>, data, c_len as u64);
    (*msg).next = 0 as ptr<IpcMessage>;
    
    spin_lock(&((*target_q).lock));
    if (*target_q).tail == 0 as ptr<IpcMessage> {
        (*target_q).head = msg;
        (*target_q).tail = msg;
    } else {
        (*((*target_q).tail)).next = msg;
        (*target_q).tail = msg;
    }
    (*target_q).msg_count = (*target_q).msg_count + 1;
    spin_unlock(&((*target_q).lock));
    return 0;
}

fn ipc_receive_message(pid: u64, out_msg: ptr<IpcMessage>) -> u32 {
    let mut my_q = 0 as ptr<IpcQueue>;
    for i in 0..ipc_queue_count {
        if global_ipc_queues[i as usize].owner_pid == pid {
            my_q = &global_ipc_queues[i as usize];
        }
    }
    if my_q == 0 as ptr<IpcQueue> { return 1; }
    
    spin_lock(&((*my_q).lock));
    if (*my_q).head == 0 as ptr<IpcMessage> {
        spin_unlock(&((*my_q).lock));
        return 2;
    }
    
    let msg = (*my_q).head;
    (*my_q).head = (*msg).next;
    if (*my_q).head == 0 as ptr<IpcMessage> {
        (*my_q).tail = 0 as ptr<IpcMessage>;
    }
    (*my_q).msg_count = (*my_q).msg_count - 1;
    spin_unlock(&((*my_q).lock));
    
    memcpy(out_msg as ptr<u8>, msg as ptr<u8>, sizeof(IpcMessage) as u64);
    pmm_free_blocks(msg as u64, 1);
    return 0;
}

fn sys_read_wrap(fd_ptr: u64, buf: u64, size: u64) -> u64 {
    let fd = fd_ptr as ptr<FileDescriptor>;
    return vfs_read(fd, buf as ptr<u8>, size);
}

fn sys_write_wrap(fd_ptr: u64, buf: u64, size: u64) -> u64 {
    let fd = fd_ptr as ptr<FileDescriptor>;
    return vfs_write(fd, buf as ptr<u8>, size);
}

fn sys_mmap(addr: u64, len: u64, prot: u64, flags: u64, fd_ptr: u64, offset: u64) -> u64 {
    let pages = (len + PAGE_SIZE - 1) / PAGE_SIZE;
    let mut vaddr = addr;
    if vaddr == 0 {
        vaddr = 0x4000000000;
    }
    let mut cur = vaddr;
    for i in 0..pages {
        let phys = pmm_alloc_blocks(1);
        memset(phys as ptr<u8>, 0, PAGE_SIZE);
        vmm_map_page(phys, cur, prot);
        cur = cur + PAGE_SIZE;
    }
    if fd_ptr != 0 {
        let fd = fd_ptr as ptr<FileDescriptor>;
        let old_off = (*fd).offset;
        (*fd).offset = offset;
        vfs_read(fd, vaddr as ptr<u8>, len);
        (*fd).offset = old_off;
    }
    return vaddr;
}

fn syscall_handler_64_adv() {
    let mut rax: u64; let mut rdi: u64; let mut rsi: u64;
    let mut rdx: u64; let mut r10: u64; let mut r8: u64; let mut r9: u64;
    
    asm { "mov %0, rax" out rax = rax; }
    asm { "mov %0, rdi" out rdi = rdi; }
    asm { "mov %0, rsi" out rsi = rsi; }
    asm { "mov %0, rdx" out rdx = rdx; }
    asm { "mov %0, r10" out r10 = r10; }
    asm { "mov %0, r8" out r8 = r8; }
    asm { "mov %0, r9" out r9 = r9; }

    if rax == 0 {
        asm { "mov rax, %0" in rax = sys_read_wrap(rdi, rsi, rdx); }
    } else if rax == 1 {
        asm { "mov rax, %0" in rax = sys_write_wrap(rdi, rsi, rdx); }
    } else if rax == 2 {
        let node = vfs_find_child(global_vfs_root, rdi as ptr<u8>);
        if node == 0 as ptr<VfsNode> {
            asm { "mov rax, 0" }
        } else {
            let fd = pmm_alloc_blocks(1) as ptr<FileDescriptor>;
            (*fd).node = node; (*fd).offset = 0; (*fd).flags = rsi as u32;
            asm { "mov rax, %0" in rax = fd as u64; }
        }
    } else if rax == 3 {
        pmm_free_blocks(rdi, 1);
        asm { "mov rax, 0" }
    } else if rax == 9 {
        asm { "mov rax, %0" in rax = sys_mmap(rdi, rsi, rdx, r10, r8, r9); }
    } else if rax == 59 {
        asm { "mov rax, %0" in rax = execve_ring3(rdi as ptr<u8>, rsi as u32, rdx as u32); }
    } else if rax == 60 {
        (*current_process).state = 0;
        scheduler_tick();
    } else if rax == 100 {
        comp_draw_rect(rdi as ptr<CompositorWindow>, rsi as u32, rdx as u32, r10 as u32, r8 as u32, r9 as u32);
        asm { "mov rax, 0" }
    } else if rax == 200 {
        let ctx = rdi as ptr<Sha256Ctx>;
        sha256_init(ctx);
        sha256_transform(ctx, rsi as ptr<u8>);
        asm { "mov rax, 0" }
    } else if rax == 300 {
        asm { "mov rax, %0" in rax = ipc_send_message(rdi, rsi, rdx as u32, r10 as ptr<u8>, r8 as u32) as u64; }
    } else if rax == 301 {
        asm { "mov rax, %0" in rax = ipc_receive_message(rdi, rsi as ptr<IpcMessage>) as u64; }
    } else {
        asm { "mov rax, -1" }
    }
}

struct CpuCoreInfo {
    apic_id: u8,
    acpi_id: u8,
    is_bsp: bool,
    is_active: bool,
    stack_base: u64,
    current_task: u64,
}

let mut smp_cores: [CpuCoreInfo; 256];
let mut smp_core_count: u32 = 0;
let mut smp_bsp_id: u8 = 0;
let mut smp_lock: Spinlock;

fn smp_register_core(apic_id: u8, acpi_id: u8, is_bsp: bool) {
    let idx = smp_core_count;
    smp_cores[idx as usize].apic_id = apic_id;
    smp_cores[idx as usize].acpi_id = acpi_id;
    smp_cores[idx as usize].is_bsp = is_bsp;
    smp_cores[idx as usize].is_active = is_bsp;
    smp_cores[idx as usize].stack_base = pmm_alloc_blocks(4) + (PAGE_SIZE * 4);
    smp_cores[idx as usize].current_task = 0;
    smp_core_count = smp_core_count + 1;
    if is_bsp { smp_bsp_id = apic_id; }
}

fn smp_send_ipi(target_apic_id: u8, vector: u8, delivery_mode: u32, level: u32, trigger: u32) {
    let icr_low = (vector as u32) | (delivery_mode << 8) | (level << 14) | (trigger << 15);
    let icr_high = (target_apic_id as u32) << 24;
    lapic_write(LAPIC_ICRHI, icr_high);
    lapic_write(LAPIC_ICRLO, icr_low);
    while (lapic_read(LAPIC_ICRLO) & (1 << 12)) != 0 { cpu_pause(); }
}

fn smp_send_init(target_apic_id: u8) {
    smp_send_ipi(target_apic_id, 0, 5, 1, 1);
    for i in 0..10000 { cpu_pause(); }
    smp_send_ipi(target_apic_id, 0, 5, 0, 1);
}

fn smp_send_sipi(target_apic_id: u8, trampoline_page: u32) {
    let vector = (trampoline_page >> 12) as u8;
    smp_send_ipi(target_apic_id, vector, 6, 1, 0);
}

fn smp_boot_ap(core_idx: u32) {
    let target_apic = smp_cores[core_idx as usize].apic_id;
    if target_apic == smp_bsp_id { return; }
    let trampoline = 0x8000;
    smp_send_init(target_apic);
    for i in 0..100000 { cpu_pause(); }
    smp_send_sipi(target_apic, trampoline);
    for i in 0..50000 { cpu_pause(); }
    smp_send_sipi(target_apic, trampoline);
}

fn smp_init_all() {
    spin_init(&smp_lock);
    for i in 0..smp_core_count {
        smp_boot_ap(i);
    }
}

struct HdaGcapRegs {
    gcap: u16,
    vmin: u8,
    vmaj: u8,
    outpay: u16,
    inpay: u16,
    gctl: u32,
    wakeen: u16,
    statests: u16,
    gsts: u16,
    outstrm: u16,
    instrm: u16,
    bidir: u16,
}

struct HdaCorbRegs {
    corblbase: u32,
    corbubase: u32,
    corbwp: u16,
    corbrp: u16,
    corbctl: u8,
    corbsts: u8,
    corbsize: u8,
    rsvd: u8,
}

struct HdaRirbRegs {
    rirblbase: u32,
    rirbubase: u32,
    rirbwp: u16,
    rintcnt: u16,
    rirbctl: u8,
    rirbsts: u8,
    rirbsize: u8,
    rsvd: u8,
}

struct HdaStreamRegs {
    ctl0: u8,
    ctl1: u8,
    ctl2: u8,
    sts: u8,
    lpib: u32,
    cbl: u32,
    lvi: u16,
    fifos: u16,
    fmt: u16,
    rsvd: u16,
    bdpl: u32,
    bdpu: u32,
}

let mut global_hda_base: u64 = 0;
let mut hda_corb_buf: ptr<u32>;
let mut hda_rirb_buf: ptr<u64>;
let mut hda_corb_wp: u16 = 0;
let mut hda_rirb_rp: u16 = 0;
let mut hda_codec_mask: u16 = 0;

fn hda_reset_controller() {
    let gctl_ptr = (global_hda_base + 0x08) as ptr<u32>;
    *gctl_ptr = 0;
    while (*gctl_ptr & 1) != 0 { cpu_pause(); }
    *gctl_ptr = 1;
    while (*gctl_ptr & 1) == 0 { cpu_pause(); }
    for i in 0..50000 { cpu_pause(); }
}

fn hda_init_corb_rirb() {
    let corb_regs = (global_hda_base + 0x40) as ptr<HdaCorbRegs>;
    let rirb_regs = (global_hda_base + 0x50) as ptr<HdaRirbRegs>;
    (*corb_regs).corbctl = 0;
    (*rirb_regs).rirbctl = 0;
    
    hda_corb_buf = pmm_alloc_blocks(1) as ptr<u32>;
    hda_rirb_buf = pmm_alloc_blocks(1) as ptr<u64>;
    memset(hda_corb_buf as ptr<u8>, 0, PAGE_SIZE);
    memset(hda_rirb_buf as ptr<u8>, 0, PAGE_SIZE);
    
    (*corb_regs).corblbase = hda_corb_buf as u64 as u32;
    (*corb_regs).corbubase = (hda_corb_buf as u64 >> 32) as u32;
    (*rirb_regs).rirblbase = hda_rirb_buf as u64 as u32;
    (*rirb_regs).rirbubase = (hda_rirb_buf as u64 >> 32) as u32;
    
    (*corb_regs).corbrp = 0x8000;
    (*rirb_regs).rirbwp = 0x8000;
    (*corb_regs).corbwp = 0;
    hda_corb_wp = 0;
    hda_rirb_rp = 0;
    
    (*corb_regs).corbctl = 2;
    (*rirb_regs).rirbctl = 2;
}

fn hda_send_verb(codec: u8, node: u8, payload: u32) {
    let verb = ((codec as u32) << 28) | ((node as u32) << 20) | payload;
    let corb_regs = (global_hda_base + 0x40) as ptr<HdaCorbRegs>;
    hda_corb_wp = hda_corb_wp + 1;
    if hda_corb_wp == 256 { hda_corb_wp = 0; }
    *(hda_corb_buf + hda_corb_wp as u64) = verb;
    (*corb_regs).corbwp = hda_corb_wp;
}

fn hda_read_response() -> u64 {
    let rirb_regs = (global_hda_base + 0x50) as ptr<HdaRirbRegs>;
    while (*rirb_regs).rirbwp == hda_rirb_rp { cpu_pause(); }
    hda_rirb_rp = hda_rirb_rp + 1;
    if hda_rirb_rp == 256 { hda_rirb_rp = 0; }
    return *(hda_rirb_buf + hda_rirb_rp as u64);
}

fn hda_init(bar0: u64) {
    global_hda_base = bar0;
    hda_reset_controller();
    let statests_ptr = (global_hda_base + 0x0E) as ptr<u16>;
    hda_codec_mask = *statests_ptr;
    hda_init_corb_rirb();
}

struct DhcpPacket {
    op: u8,
    htype: u8,
    hlen: u8,
    hops: u8,
    xid: u32,
    secs: u16,
    flags: u16,
    ciaddr: u32,
    yiaddr: u32,
    siaddr: u32,
    giaddr: u32,
    chaddr: [u8; 16],
    sname: [u8; 64],
    file: [u8; 128],
    magic: u32,
    options: [u8; 256],
}

struct DnsHeader {
    id: u16,
    flags: u16,
    qdcount: u16,
    ancount: u16,
    nscount: u16,
    arcount: u16,
}

let mut system_dns_ip: Ipv4Addr;
let mut system_gateway_ip: Ipv4Addr;
let mut system_subnet_mask: Ipv4Addr;
let mut dhcp_xid: u32 = 0x1337AABB;

fn dhcp_send_discover() {
    let pkt_size = sizeof(DhcpPacket) as u64;
    let pkt = pmm_alloc_blocks(1) as ptr<DhcpPacket>;
    memset(pkt as ptr<u8>, 0, pkt_size);
    (*pkt).op = 1;
    (*pkt).htype = 1;
    (*pkt).hlen = 6;
    (*pkt).hops = 0;
    (*pkt).xid = htonl(dhcp_xid);
    (*pkt).secs = 0;
    (*pkt).flags = htons(0x8000);
    (*pkt).ciaddr = 0;
    (*pkt).yiaddr = 0;
    (*pkt).siaddr = 0;
    (*pkt).giaddr = 0;
    for i in 0..6 { (*pkt).chaddr[i] = system_mac.addr[i]; }
    (*pkt).magic = htonl(0x63825363);
    (*pkt).options[0] = 53;
    (*pkt).options[1] = 1;
    (*pkt).options[2] = 1;
    (*pkt).options[3] = 255;
    
    let mut broadcast_ip: Ipv4Addr;
    for i in 0..4 { broadcast_ip.addr[i] = 255; }
    
    let udp_len = sizeof(UdpHeader) as u64 + pkt_size;
    let ip_len = sizeof(Ipv4Header) as u64 + udp_len;
    let eth_len = sizeof(EthernetHeader) as u64 + ip_len;
    let buffer = pmm_alloc_blocks(1) as ptr<u8>;
    memset(buffer, 0, eth_len);
    
    let eth = buffer as ptr<EthernetHeader>;
    for i in 0..6 { (*eth).dest_mac.addr[i] = 0xFF; }
    for i in 0..6 { (*eth).src_mac.addr[i] = system_mac.addr[i]; }
    (*eth).ethertype = htons(0x0800);
    
    let iph = (buffer as u64 + sizeof(EthernetHeader) as u64) as ptr<Ipv4Header>;
    (*iph).ihl_version = 0x45;
    (*iph).tos = 0;
    (*iph).total_length = htons(ip_len as u16);
    (*iph).id = htons(1);
    (*iph).flags_frag = 0;
    (*iph).ttl = 64;
    (*iph).protocol = 17;
    (*iph).src_ip.addr[0] = 0; (*iph).src_ip.addr[1] = 0; (*iph).src_ip.addr[2] = 0; (*iph).src_ip.addr[3] = 0;
    for i in 0..4 { (*iph).dest_ip.addr[i] = 255; }
    (*iph).checksum = calculate_checksum(iph as ptr<u8>, sizeof(Ipv4Header) as u32);
    
    let udph = (buffer as u64 + sizeof(EthernetHeader) as u64 + sizeof(Ipv4Header) as u64) as ptr<UdpHeader>;
    (*udph).src_port = htons(68);
    (*udph).dest_port = htons(67);
    (*udph).length = htons(udp_len as u16);
    (*udph).checksum = 0;
    
    let payload = (buffer as u64 + sizeof(EthernetHeader) as u64 + sizeof(Ipv4Header) as u64 + sizeof(UdpHeader) as u64) as ptr<u8>;
    memcpy(payload, pkt as ptr<u8>, pkt_size);
    
    rtl8139_send(buffer, eth_len as u32);
    pmm_free_blocks(pkt as u64, 1);
    pmm_free_blocks(buffer as u64, 1);
}

fn dns_format_name(dest: ptr<u8>, domain: ptr<u8>) {
    let mut i: u64 = 0;
    let mut j: u64 = 0;
    let mut len_pos: u64 = 0;
    let mut count: u8 = 0;
    dest[len_pos] = 0;
    i = i + 1;
    while domain[j] != 0 {
        if domain[j] == 46 {
            dest[len_pos] = count;
            len_pos = i;
            count = 0;
        } else {
            dest[i] = domain[j];
            count = count + 1;
        }
        i = i + 1;
        j = j + 1;
    }
    dest[len_pos] = count;
    dest[i] = 0;
}

fn dns_send_query(domain: ptr<u8>) {
    let mut query_buf: [u8; 256];
    memset(&query_buf[0] as ptr<u8>, 0, 256);
    let dh = &query_buf[0] as ptr<DnsHeader>;
    (*dh).id = htons(0xABCD);
    (*dh).flags = htons(0x0100);
    (*dh).qdcount = htons(1);
    (*dh).ancount = 0;
    (*dh).nscount = 0;
    (*dh).arcount = 0;
    
    let qname = (&query_buf[0] as u64 + sizeof(DnsHeader) as u64) as ptr<u8>;
    dns_format_name(qname, domain);
    let qname_len = strlen(qname) + 1;
    
    let qtype = (qname as u64 + qname_len) as ptr<u16>;
    *qtype = htons(1);
    let qclass = (qname as u64 + qname_len + 2) as ptr<u16>;
    *qclass = htons(1);
    
    let total_len = sizeof(DnsHeader) as u64 + qname_len + 4;
    
    let eth_len = sizeof(EthernetHeader) as u64 + sizeof(Ipv4Header) as u64 + sizeof(UdpHeader) as u64 + total_len;
    let buffer = pmm_alloc_blocks(1) as ptr<u8>;
    memset(buffer, 0, eth_len);
    
    let eth = buffer as ptr<EthernetHeader>;
    for i in 0..6 { (*eth).dest_mac.addr[i] = 0xFF; }
    for i in 0..6 { (*eth).src_mac.addr[i] = system_mac.addr[i]; }
    (*eth).ethertype = htons(0x0800);
    
    let iph = (buffer as u64 + sizeof(EthernetHeader) as u64) as ptr<Ipv4Header>;
    (*iph).ihl_version = 0x45;
    (*iph).tos = 0;
    (*iph).total_length = htons((sizeof(Ipv4Header) as u64 + sizeof(UdpHeader) as u64 + total_len) as u16);
    (*iph).id = htons(2);
    (*iph).flags_frag = 0;
    (*iph).ttl = 64;
    (*iph).protocol = 17;
    for i in 0..4 { (*iph).src_ip.addr[i] = system_ip.addr[i]; }
    for i in 0..4 { (*iph).dest_ip.addr[i] = system_dns_ip.addr[i]; }
    (*iph).checksum = calculate_checksum(iph as ptr<u8>, sizeof(Ipv4Header) as u32);
    
    let udph = (buffer as u64 + sizeof(EthernetHeader) as u64 + sizeof(Ipv4Header) as u64) as ptr<UdpHeader>;
    (*udph).src_port = htons(50000);
    (*udph).dest_port = htons(53);
    (*udph).length = htons((sizeof(UdpHeader) as u64 + total_len) as u16);
    (*udph).checksum = 0;
    
    let payload = (buffer as u64 + sizeof(EthernetHeader) as u64 + sizeof(Ipv4Header) as u64 + sizeof(UdpHeader) as u64) as ptr<u8>;
    memcpy(payload, &query_buf[0] as ptr<u8>, total_len);
    
    rtl8139_send(buffer, eth_len as u32);
    pmm_free_blocks(buffer as u64, 1);
}

struct UsbCbw {
    signature: u32,
    tag: u32,
    transfer_length: u32,
    flags: u8,
    lun: u8,
    cb_length: u8,
    cdb: [u8; 16],
}

struct UsbCsw {
    signature: u32,
    tag: u32,
    data_residue: u32,
    status: u8,
}

fn usb_bot_read_capacity(bulk_out: u8, bulk_in: u8) {
    let cbw = pmm_alloc_blocks(1) as ptr<UsbCbw>;
    memset(cbw as ptr<u8>, 0, sizeof(UsbCbw) as u64);
    (*cbw).signature = 0x43425355;
    (*cbw).tag = 0x11223344;
    (*cbw).transfer_length = 8;
    (*cbw).flags = 0x80;
    (*cbw).lun = 0;
    (*cbw).cb_length = 10;
    (*cbw).cdb[0] = 0x25;
    pmm_free_blocks(cbw as u64, 1);
}

struct Psf1Header {
    magic: u16,
    mode: u8,
    charsize: u8,
}

struct Psf2Header {
    magic: u32,
    version: u32,
    headersize: u32,
    flags: u32,
    length: u32,
    charsize: u32,
    height: u32,
    width: u32,
}

let mut system_font_ptr: ptr<u8>;
let mut system_font_w: u32 = 8;
let mut system_font_h: u32 = 16;

fn gui_draw_char(win: ptr<CompositorWindow>, c: u8, x: u32, y: u32, fg: u32, bg: u32) {
    let glyph_offset = c as u64 * system_font_h as u64;
    let glyph = (system_font_ptr as u64 + glyph_offset) as ptr<u8>;
    let buf = (*win).buffer_phys as ptr<u32>;
    for cy in 0..system_font_h {
        let row = *(glyph + cy as u64);
        for cx in 0..system_font_w {
            let px = x + cx;
            let py = y + cy;
            if px < (*win).width && py < (*win).height {
                let p_idx = (py * (*win).width + px) as u64;
                if (row & (0x80 >> cx)) != 0 {
                    *(buf + p_idx) = fg;
                } else {
                    if bg != 0xFFFFFFFF { *(buf + p_idx) = bg; }
                }
            }
        }
    }
}

fn gui_draw_string(win: ptr<CompositorWindow>, str: ptr<u8>, x: u32, y: u32, fg: u32, bg: u32) {
    let mut i: u64 = 0;
    let mut cx = x;
    while *(str + i) != 0 {
        if *(str + i) == 10 {
            cx = x;
            y = y + system_font_h + 2;
        } else {
            gui_draw_char(win, *(str + i), cx, y, fg, bg);
            cx = cx + system_font_w;
        }
        i = i + 1;
    }
}

fn gui_draw_button(win: ptr<CompositorWindow>, label: ptr<u8>, x: u32, y: u32, w: u32, h: u32) {
    comp_draw_rect(win, x, y, w, h, 0x555555);
    comp_draw_rect(win, x+1, y+1, w-2, h-2, 0x888888);
    let len = strlen(label) as u32;
    let text_x = x + (w / 2) - ((len * system_font_w) / 2);
    let text_y = y + (h / 2) - (system_font_h / 2);
    gui_draw_string(win, label, text_x, text_y, 0xFFFFFF, 0xFFFFFFFF);
}

fn gui_draw_panel(win: ptr<CompositorWindow>, title: ptr<u8>) {
    comp_draw_rect(win, 0, 0, (*win).width, (*win).height, 0x333333);
    comp_draw_rect(win, 0, 0, (*win).width, 24, 0x111111);
    gui_draw_string(win, title, 5, 4, 0xFFFFFF, 0x111111);
    gui_draw_button(win, "X" as ptr<u8>, (*win).width - 24, 2, 20, 20);
}

const TCP_STATE_CLOSED: u8 = 0;
const TCP_STATE_LISTEN: u8 = 1;
const TCP_STATE_SYN_SENT: u8 = 2;
const TCP_STATE_SYN_RCVD: u8 = 3;
const TCP_STATE_ESTABLISHED: u8 = 4;
const TCP_STATE_FIN_WAIT_1: u8 = 5;
const TCP_STATE_FIN_WAIT_2: u8 = 6;
const TCP_STATE_CLOSE_WAIT: u8 = 7;
const TCP_STATE_CLOSING: u8 = 8;
const TCP_STATE_LAST_ACK: u8 = 9;
const TCP_STATE_TIME_WAIT: u8 = 10;

struct TcpSocket {
    id: u64,
    state: u8,
    local_port: u16,
    remote_port: u16,
    remote_ip: Ipv4Addr,
    seq_num: u32,
    ack_num: u32,
    window_size: u16,
    rx_buffer: ptr<u8>,
    tx_buffer: ptr<u8>,
    rx_head: u32,
    rx_tail: u32,
    tx_head: u32,
    tx_tail: u32,
    lock: Spinlock,
    is_active: bool,
}

let mut global_tcp_sockets: [TcpSocket; 1024];
let mut tcp_socket_count: u64 = 1;

fn tcp_init_sockets() {
    for i in 0..1024 {
        global_tcp_sockets[i].is_active = false;
        global_tcp_sockets[i].id = 0;
        spin_init(&(global_tcp_sockets[i].lock));
    }
}

fn tcp_create_socket() -> ptr<TcpSocket> {
    for i in 0..1024 {
        if !global_tcp_sockets[i].is_active {
            global_tcp_sockets[i].is_active = true;
            global_tcp_sockets[i].id = tcp_socket_count;
            tcp_socket_count = tcp_socket_count + 1;
            global_tcp_sockets[i].state = TCP_STATE_CLOSED;
            global_tcp_sockets[i].local_port = 0;
            global_tcp_sockets[i].remote_port = 0;
            global_tcp_sockets[i].seq_num = 0;
            global_tcp_sockets[i].ack_num = 0;
            global_tcp_sockets[i].window_size = 8192;
            global_tcp_sockets[i].rx_buffer = pmm_alloc_blocks(2) as ptr<u8>;
            global_tcp_sockets[i].tx_buffer = pmm_alloc_blocks(2) as ptr<u8>;
            global_tcp_sockets[i].rx_head = 0;
            global_tcp_sockets[i].rx_tail = 0;
            global_tcp_sockets[i].tx_head = 0;
            global_tcp_sockets[i].tx_tail = 0;
            return &global_tcp_sockets[i];
        }
    }
    return 0 as ptr<TcpSocket>;
}

fn tcp_compute_checksum(src_ip: Ipv4Addr, dst_ip: Ipv4Addr, tcp_len: u16, tcp_data: ptr<u8>) -> u16 {
    let mut sum: u32 = 0;
    let src_ptr = &src_ip as ptr<Ipv4Addr> as ptr<u16>;
    let dst_ptr = &dst_ip as ptr<Ipv4Addr> as ptr<u16>;
    sum = sum + *(src_ptr) as u32;
    sum = sum + *(src_ptr as u64 + 2) as u32;
    sum = sum + *(dst_ptr) as u32;
    sum = sum + *(dst_ptr as u64 + 2) as u32;
    sum = sum + htons(6) as u32;
    sum = sum + htons(tcp_len) as u32;
    
    let mut data_ptr = tcp_data as ptr<u16>;
    let mut len = tcp_len;
    while len > 1 {
        sum = sum + *(data_ptr) as u32;
        data_ptr = (data_ptr as u64 + 2) as ptr<u16>;
        len = len - 2;
    }
    if len == 1 {
        let mut last_byte: u16 = 0;
        *(last_byte as u64 as ptr<u8>) = *(data_ptr as ptr<u8>);
        sum = sum + last_byte as u32;
    }
    while (sum >> 16) != 0 {
        sum = (sum & 0xFFFF) + (sum >> 16);
    }
    return (!sum) as u16;
}

fn tcp_send_segment(sock: ptr<TcpSocket>, flags: u16, payload: ptr<u8>, payload_len: u16) {
    let tcp_len = sizeof(TcpHeader) as u16 + payload_len;
    let ip_len = sizeof(Ipv4Header) as u16 + tcp_len;
    let eth_len = sizeof(EthernetHeader) as u16 + ip_len;
    
    let buffer = pmm_alloc_blocks(1) as ptr<u8>;
    memset(buffer, 0, eth_len as u64);
    
    let eth = buffer as ptr<EthernetHeader>;
    for i in 0..6 { (*eth).dest_mac.addr[i] = 0xFF; }
    for i in 0..6 { (*eth).src_mac.addr[i] = system_mac.addr[i]; }
    (*eth).ethertype = htons(0x0800);
    
    let iph = (buffer as u64 + sizeof(EthernetHeader) as u64) as ptr<Ipv4Header>;
    (*iph).ihl_version = 0x45;
    (*iph).tos = 0;
    (*iph).total_length = htons(ip_len);
    (*iph).id = htons(tcp_socket_count as u16);
    (*iph).flags_frag = 0;
    (*iph).ttl = 64;
    (*iph).protocol = 6;
    for i in 0..4 { (*iph).src_ip.addr[i] = system_ip.addr[i]; }
    for i in 0..4 { (*iph).dest_ip.addr[i] = (*sock).remote_ip.addr[i]; }
    (*iph).checksum = calculate_checksum(iph as ptr<u8>, sizeof(Ipv4Header) as u32);
    
    let tcph = (buffer as u64 + sizeof(EthernetHeader) as u64 + sizeof(Ipv4Header) as u64) as ptr<TcpHeader>;
    (*tcph).src_port = htons((*sock).local_port);
    (*tcph).dest_port = htons((*sock).remote_port);
    (*tcph).seq_num = htonl((*sock).seq_num);
    (*tcph).ack_num = htonl((*sock).ack_num);
    (*tcph).data_offset_flags = htons((5 << 12) | flags);
    (*tcph).window_size = htons((*sock).window_size);
    (*tcph).urgent_ptr = 0;
    
    let tcp_payload = (buffer as u64 + sizeof(EthernetHeader) as u64 + sizeof(Ipv4Header) as u64 + sizeof(TcpHeader) as u64) as ptr<u8>;
    if payload_len > 0 {
        memcpy(tcp_payload, payload, payload_len as u64);
    }
    
    (*tcph).checksum = tcp_compute_checksum(system_ip, (*sock).remote_ip, tcp_len, tcph as ptr<u8>);
    rtl8139_send(buffer, eth_len as u32);
    pmm_free_blocks(buffer as u64, 1);
}

fn tcp_connect(sock: ptr<TcpSocket>, remote_ip: Ipv4Addr, remote_port: u16) {
    spin_lock(&((*sock).lock));
    (*sock).remote_ip = remote_ip;
    (*sock).remote_port = remote_port;
    if (*sock).local_port == 0 {
        (*sock).local_port = 49152 + (tcp_socket_count as u16 % 16384);
    }
    (*sock).seq_num = 0x11223344;
    (*sock).state = TCP_STATE_SYN_SENT;
    tcp_send_segment(sock, 0x0002, 0 as ptr<u8>, 0);
    spin_unlock(&((*sock).lock));
}

fn tcp_close(sock: ptr<TcpSocket>) {
    spin_lock(&((*sock).lock));
    if (*sock).state == TCP_STATE_ESTABLISHED || (*sock).state == TCP_STATE_SYN_RCVD {
        (*sock).state = TCP_STATE_FIN_WAIT_1;
        tcp_send_segment(sock, 0x0011, 0 as ptr<u8>, 0);
    } else {
        (*sock).state = TCP_STATE_CLOSED;
        (*sock).is_active = false;
        pmm_free_blocks((*sock).rx_buffer as u64, 2);
        pmm_free_blocks((*sock).tx_buffer as u64, 2);
    }
    spin_unlock(&((*sock).lock));
}

fn tcp_bind(sock: ptr<TcpSocket>, port: u16) {
    spin_lock(&((*sock).lock));
    (*sock).local_port = port;
    spin_unlock(&((*sock).lock));
}

fn tcp_listen(sock: ptr<TcpSocket>) {
    spin_lock(&((*sock).lock));
    (*sock).state = TCP_STATE_LISTEN;
    spin_unlock(&((*sock).lock));
}

struct Fat32ExtBPB {
    jmp: [u8; 3],
    oem_name: [u8; 8],
    bytes_per_sector: u16,
    sectors_per_cluster: u8,
    reserved_sector_count: u16,
    num_fats: u8,
    root_entry_count: u16,
    total_sectors_16: u16,
    media_type: u8,
    table_size_16: u16,
    sectors_per_track: u16,
    head_side_count: u16,
    hidden_sector_count: u32,
    total_sectors_32: u32,
    table_size_32: u32,
    extended_flags: u16,
    fat_version: u16,
    root_cluster: u32,
    fat_info: u16,
    backup_boot_sector: u16,
    reserved_0: [u8; 12],
    drive_number: u8,
    reserved_1: u8,
    boot_signature: u8,
    volume_id: u32,
    volume_label: [u8; 11],
    fat_type_label: [u8; 8],
}

struct Fat32DirEntry {
    name: [u8; 11],
    attr: u8,
    nt_res: u8,
    crt_time_tenth: u8,
    crt_time: u16,
    crt_date: u16,
    lst_acc_date: u16,
    fst_clus_hi: u16,
    wrt_time: u16,
    wrt_date: u16,
    fst_clus_lo: u16,
    file_size: u32,
}

let mut fat32_lba_start: u32 = 0;
let mut fat32_fat_start: u32 = 0;
let mut fat32_data_start: u32 = 0;
let mut fat32_root_cluster: u32 = 0;
let mut fat32_sectors_per_cluster: u32 = 0;
let mut fat32_bytes_per_sector: u32 = 0;

fn fat32_init(lba_offset: u32) {
    fat32_lba_start = lba_offset;
    let bpb_buf = pmm_alloc_blocks(1) as ptr<u8>;
    let bpb = bpb_buf as ptr<Fat32ExtBPB>;
    fat32_bytes_per_sector = (*bpb).bytes_per_sector as u32;
    fat32_sectors_per_cluster = (*bpb).sectors_per_cluster as u32;
    fat32_fat_start = fat32_lba_start + (*bpb).reserved_sector_count as u32;
    let fat_size = (*bpb).table_size_32;
    fat32_data_start = fat32_fat_start + ((*bpb).num_fats as u32 * fat_size);
    fat32_root_cluster = (*bpb).root_cluster;
    pmm_free_blocks(bpb_buf as u64, 1);
}

fn fat32_cluster_to_lba(cluster: u32) -> u32 {
    return fat32_data_start + ((cluster - 2) * fat32_sectors_per_cluster);
}

fn fat32_read_next_cluster(cluster: u32) -> u32 {
    let fat_offset = cluster * 4;
    let fat_sector = fat32_fat_start + (fat_offset / fat32_bytes_per_sector);
    let ent_offset = fat_offset % fat32_bytes_per_sector;
    let buf = pmm_alloc_blocks(1) as ptr<u8>;
    let next_cluster = *((buf as u64 + ent_offset as u64) as ptr<u32>) & 0x0FFFFFFF;
    pmm_free_blocks(buf as u64, 1);
    return next_cluster;
}

fn fat32_find_file(dir_cluster: u32, filename: ptr<u8>) -> ptr<Fat32DirEntry> {
    let mut current_cluster = dir_cluster;
    let buf = pmm_alloc_blocks(1) as ptr<u8>;
    while current_cluster < 0x0FFFFFF8 {
        let entries_per_cluster = (fat32_sectors_per_cluster * fat32_bytes_per_sector) / 32;
        for i in 0..entries_per_cluster {
            let entry = (buf as u64 + (i * 32) as u64) as ptr<Fat32DirEntry>;
            if (*entry).name[0] == 0x00 {
                pmm_free_blocks(buf as u64, 1);
                return 0 as ptr<Fat32DirEntry>;
            }
            if (*entry).name[0] != 0xE5 && ((*entry).attr & 0x0F) != 0x0F {
                let mut match_found = true;
                for j in 0..11 {
                    if (*entry).name[j as usize] != *(filename + j) {
                        match_found = false;
                        break;
                    }
                }
                if match_found {
                    let ret_entry = pmm_alloc_blocks(1) as ptr<Fat32DirEntry>;
                    memcpy(ret_entry as ptr<u8>, entry as ptr<u8>, 32);
                    pmm_free_blocks(buf as u64, 1);
                    return ret_entry;
                }
            }
        }
        current_cluster = fat32_read_next_cluster(current_cluster);
    }
    pmm_free_blocks(buf as u64, 1);
    return 0 as ptr<Fat32DirEntry>;
}

fn acpi_get_pm1_control() -> (u32, u32) {
    if acpi_fadt == 0 as ptr<FADTHeader> { return (0, 0); }
    let pm1a = (*acpi_fadt).pm1a_control_block;
    let pm1b = (*acpi_fadt).pm1b_control_block;
    return (pm1a, pm1b);
}

fn acpi_power_off() {
    let (pm1a, pm1b) = acpi_get_pm1_control();
    if pm1a != 0 {
        let val = inw(pm1a as u16);
        outw(pm1a as u16, val | (5 << 10) | (1 << 13));
    }
    if pm1b != 0 {
        let val = inw(pm1b as u16);
        outw(pm1b as u16, val | (5 << 10) | (1 << 13));
    }
    cpu_cli();
    loop { cpu_hlt(); }
}

fn acpi_reset() {
    let reset_reg = 0x64;
    let reset_cmd = 0xFE;
    while (inb(reset_reg) & 2) != 0 { cpu_pause(); }
    outb(reset_reg, reset_cmd);
    cpu_cli();
    loop { cpu_hlt(); }
}

fn gui_draw_checkbox(win: ptr<CompositorWindow>, x: u32, y: u32, checked: bool, label: ptr<u8>) {
    comp_draw_rect(win, x, y, 16, 16, 0xFFFFFF);
    comp_draw_rect(win, x+1, y+1, 14, 14, 0x222222);
    if checked {
        comp_draw_rect(win, x+4, y+4, 8, 8, 0x00FF00);
    }
    gui_draw_string(win, label, x + 24, y, 0xFFFFFF, 0xFFFFFFFF);
}

fn gui_draw_radio(win: ptr<CompositorWindow>, x: u32, y: u32, selected: bool, label: ptr<u8>) {
    comp_draw_rect(win, x, y, 16, 16, 0x888888);
    comp_draw_rect(win, x+2, y+2, 12, 12, 0x222222);
    if selected {
        comp_draw_rect(win, x+5, y+5, 6, 6, 0x00AFFF);
    }
    gui_draw_string(win, label, x + 24, y, 0xFFFFFF, 0xFFFFFFFF);
}

fn gui_draw_progressbar(win: ptr<CompositorWindow>, x: u32, y: u32, w: u32, h: u32, progress: u32, max: u32) {
    comp_draw_rect(win, x, y, w, h, 0x444444);
    comp_draw_rect(win, x+1, y+1, w-2, h-2, 0x111111);
    let mut fill_w = 0;
    if max > 0 {
        fill_w = (progress * (w - 2)) / max;
    }
    if fill_w > 0 {
        comp_draw_rect(win, x+1, y+1, fill_w, h-2, 0x00FF00);
    }
}

fn gui_draw_slider(win: ptr<CompositorWindow>, x: u32, y: u32, w: u32, val: u32, max: u32) {
    let h = 10;
    comp_draw_rect(win, x, y + 4, w, 2, 0x888888);
    let mut pos_x = 0;
    if max > 0 {
        pos_x = (val * w) / max;
    }
    if pos_x > w - 8 { pos_x = w - 8; }
    comp_draw_rect(win, x + pos_x, y, 8, h, 0xFFFFFF);
}

struct AudioMixerChannel {
    is_playing: bool,
    buffer: ptr<u8>,
    length: u32,
    position: u32,
    volume: u8,
    sample_rate: u32,
}

let mut global_audio_mixer: [AudioMixerChannel; 16];

fn mixer_init() {
    for i in 0..16 {
        global_audio_mixer[i].is_playing = false;
        global_audio_mixer[i].position = 0;
        global_audio_mixer[i].volume = 128;
    }
}

fn mixer_play_pcm(buffer: ptr<u8>, length: u32, rate: u32) -> i32 {
    for i in 0..16 {
        if !global_audio_mixer[i].is_playing {
            global_audio_mixer[i].buffer = buffer;
            global_audio_mixer[i].length = length;
            global_audio_mixer[i].position = 0;
            global_audio_mixer[i].sample_rate = rate;
            global_audio_mixer[i].is_playing = true;
            return i as i32;
        }
    }
    return -1;
}

fn mixer_stop_channel(channel: u32) {
    if channel < 16 {
        global_audio_mixer[channel as usize].is_playing = false;
    }
}

fn mixer_process_frame(output_buffer: ptr<u16>, frames: u32) {
    for f in 0..frames {
        let mut mixed_sample_l: i32 = 0;
        let mut mixed_sample_r: i32 = 0;
        for c in 0..16 {
            let mut ch = &global_audio_mixer[c];
            if (*ch).is_playing && (*ch).position < (*ch).length {
                let sample_ptr = ((*ch).buffer as u64 + (*ch).position as u64 * 4) as ptr<i16>;
                let left = (*sample_ptr as i32 * (*ch).volume as i32) / 255;
                let right = (*(sample_ptr as u64 + 2) as ptr<i16> as i32 * (*ch).volume as i32) / 255;
                mixed_sample_l = mixed_sample_l + left;
                mixed_sample_r = mixed_sample_r + right;
                (*ch).position = (*ch).position + 1;
            } else if (*ch).is_playing {
                (*ch).is_playing = false;
            }
        }
        if mixed_sample_l > 32767 { mixed_sample_l = 32767; }
        if mixed_sample_l < -32768 { mixed_sample_l = -32768; }
        if mixed_sample_r > 32767 { mixed_sample_r = 32767; }
        if mixed_sample_r < -32768 { mixed_sample_r = -32768; }
        
        *(output_buffer as u64 + f as u64 * 4) as ptr<i16> = mixed_sample_l as i16;
        *(output_buffer as u64 + f as u64 * 4 + 2) as ptr<i16> = mixed_sample_r as i16;
    }
}

let mut usb_hid_kbd_map: [u8; 128] = [
    0, 0, 0, 0, 'a' as u8, 'b' as u8, 'c' as u8, 'd' as u8, 'e' as u8, 'f' as u8, 'g' as u8, 'h' as u8, 'i' as u8, 'j' as u8, 'k' as u8, 'l' as u8,
    'm' as u8, 'n' as u8, 'o' as u8, 'p' as u8, 'q' as u8, 'r' as u8, 's' as u8, 't' as u8, 'u' as u8, 'v' as u8, 'w' as u8, 'x' as u8, 'y' as u8, 'z' as u8,
    '1' as u8, '2' as u8, '3' as u8, '4' as u8, '5' as u8, '6' as u8, '7' as u8, '8' as u8, '9' as u8, '0' as u8,
    10, 27, 8, 9, ' ' as u8, '-' as u8, '=' as u8, '[' as u8, ']' as u8, '\\' as u8, 0, ';' as u8, '\'' as u8, '`' as u8, ',' as u8, '.' as u8, '/' as u8,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
];

let mut usb_hid_shift_map: [u8; 128] = [
    0, 0, 0, 0, 'A' as u8, 'B' as u8, 'C' as u8, 'D' as u8, 'E' as u8, 'F' as u8, 'G' as u8, 'H' as u8, 'I' as u8, 'J' as u8, 'K' as u8, 'L' as u8,
    'M' as u8, 'N' as u8, 'O' as u8, 'P' as u8, 'Q' as u8, 'R' as u8, 'S' as u8, 'T' as u8, 'U' as u8, 'V' as u8, 'W' as u8, 'X' as u8, 'Y' as u8, 'Z' as u8,
    '!' as u8, '@' as u8, '#' as u8, '$' as u8, '%' as u8, '^' as u8, '&' as u8, '*' as u8, '(' as u8, ')' as u8,
    10, 27, 8, 9, ' ' as u8, '_' as u8, '+' as u8, '{' as u8, '}' as u8, '|' as u8, 0, ':' as u8, '"' as u8, '~' as u8, '<' as u8, '>' as u8, '?' as u8,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
];

struct UsbDeviceDescriptor {
    length: u8,
    descriptor_type: u8,
    bcd_usb: u16,
    device_class: u8,
    device_subclass: u8,
    device_protocol: u8,
    max_packet_size: u8,
    id_vendor: u16,
    id_product: u16,
    bcd_device: u16,
    manufacturer: u8,
    product: u8,
    serial_number: u8,
    num_configurations: u8,
}

struct UsbEndpointDescriptor {
    length: u8,
    descriptor_type: u8,
    endpoint_address: u8,
    attributes: u8,
    max_packet_size: u16,
    interval: u8,
}

struct HidReport {
    modifier: u8,
    reserved: u8,
    keys: [u8; 6],
}

struct MouseReport {
    buttons: u8,
    x: i8,
    y: i8,
    wheel: i8,
}

let mut global_kbd_state_shift: bool = false;
let mut global_kbd_state_caps: bool = false;

fn usb_hid_parse_keyboard(report: ptr<HidReport>) {
    let m = (*report).modifier;
    global_kbd_state_shift = (m & 0x02) != 0 || (m & 0x20) != 0;
    
    for i in 0..6 {
        let k = (*report).keys[i];
        if k >= 4 && k <= 100 {
            let mut ascii = usb_hid_kbd_map[k as usize];
            if global_kbd_state_shift != global_kbd_state_caps {
                if k >= 4 && k <= 29 { ascii = usb_hid_shift_map[k as usize]; }
            }
            if global_kbd_state_shift && (k < 4 || k > 29) {
                ascii = usb_hid_shift_map[k as usize];
            }
            if ascii != 0 {
                kbd_buf[kbd_wp as usize] = ascii;
                kbd_wp = (kbd_wp + 1) % 1024;
            }
        }
    }
}

fn usb_hid_parse_mouse(report: ptr<MouseReport>) {
    let btn = (*report).buttons;
    let dx = (*report).x as i32;
    let dy = (*report).y as i32;
    
    mouse_x = mouse_x + dx;
    mouse_y = mouse_y + dy;
    
    if mouse_x < 0 { mouse_x = 0; }
    if mouse_y < 0 { mouse_y = 0; }
    if mouse_x >= comp_width as i32 { mouse_x = comp_width as i32 - 1; }
    if mouse_y >= comp_height as i32 { mouse_y = comp_height as i32 - 1; }
    
    mouse_b = btn;
}

const SWAP_MAGIC: u64 = 0x5357415053504143;
const MAX_SWAP_PAGES: u64 = 262144; 

struct SwapHeader {
    magic: u64,
    total_pages: u64,
    free_pages: u64,
    bitmap_offset: u64,
}

struct PageFrameInfo {
    phys_addr: u64,
    virt_addr: u64,
    pid: u64,
    access_time: u64,
    flags: u32,
    swap_idx: u64,
}

let mut swap_bitmap: ptr<u64>;
let mut pfn_database: ptr<PageFrameInfo>;
let mut pfn_count: u64 = 0;
let mut current_time_tick: u64 = 0;
let mut swap_lck: Spinlock;

fn swap_init() {
    spin_init(&swap_lck);
    let bitmap_sz = MAX_SWAP_PAGES / 64 * 8;
    swap_bitmap = pmm_alloc_blocks(bitmap_sz / PAGE_SIZE + 1) as ptr<u64>;
    memset(swap_bitmap as ptr<u8>, 0, bitmap_sz);
    
    let pfn_sz = (MAX_MEM_MB * 1024 * 1024) / PAGE_SIZE * sizeof(PageFrameInfo) as u64;
    pfn_database = pmm_alloc_blocks(pfn_sz / PAGE_SIZE + 1) as ptr<PageFrameInfo>;
    memset(pfn_database as ptr<u8>, 0, pfn_sz);
}

fn swap_alloc_slot() -> u64 {
    for i in 0..(MAX_SWAP_PAGES / 64) {
        if *(swap_bitmap + i) != 0xFFFFFFFFFFFFFFFF {
            for j in 0..64 {
                if (*(swap_bitmap + i) & (1 << j)) == 0 {
                    *(swap_bitmap + i) |= 1 << j;
                    return i * 64 + j;
                }
            }
        }
    }
    return 0xFFFFFFFFFFFFFFFF;
}

fn swap_free_slot(idx: u64) {
    *(swap_bitmap + (idx / 64)) &= !(1 << (idx % 64));
}

fn page_replacement_lru() -> ptr<PageFrameInfo> {
    let mut oldest_time: u64 = 0xFFFFFFFFFFFFFFFF;
    let mut victim: ptr<PageFrameInfo> = 0 as ptr<PageFrameInfo>;
    
    for i in 0..pfn_count {
        let frame = (pfn_database as u64 + i * sizeof(PageFrameInfo) as u64) as ptr<PageFrameInfo>;
        if ((*frame).flags & 1) != 0 && ((*frame).flags & 2) == 0 {
            if (*frame).access_time < oldest_time {
                oldest_time = (*frame).access_time;
                victim = frame;
            }
        }
    }
    return victim;
}

fn swap_page_out(frame: ptr<PageFrameInfo>) -> bool {
    spin_lock(&swap_lck);
    let slot = swap_alloc_slot();
    if slot == 0xFFFFFFFFFFFFFFFF {
        spin_unlock(&swap_lck);
        return false;
    }
    
    let disk_lba = 1000000 + (slot * 8);
    (*frame).swap_idx = slot;
    (*frame).flags &= !1;
    vmm_unmap_page((*frame).virt_addr);
    
    spin_unlock(&swap_lck);
    return true;
}

fn swap_page_in(frame: ptr<PageFrameInfo>) {
    spin_lock(&swap_lck);
    let phys = pmm_alloc_blocks(1);
    if phys == 0 {
        let victim = page_replacement_lru();
        if victim != 0 as ptr<PageFrameInfo> {
            swap_page_out(victim);
        }
    }
    
    let disk_lba = 1000000 + ((*frame).swap_idx * 8);
    (*frame).phys_addr = phys;
    (*frame).flags |= 1;
    vmm_map_page(phys, (*frame).virt_addr, 0x07);
    swap_free_slot((*frame).swap_idx);
    spin_unlock(&swap_lck);
}

fn page_fault_handler_adv(cr2: u64, err_code: u64) {
    let virt_align = cr2 & !(PAGE_SIZE - 1);
    for i in 0..pfn_count {
        let frame = (pfn_database as u64 + i * sizeof(PageFrameInfo) as u64) as ptr<PageFrameInfo>;
        if (*frame).virt_addr == virt_align && ((*frame).flags & 1) == 0 {
            swap_page_in(frame);
            return;
        }
    }
    cpu_cli();
    loop { cpu_hlt(); }
}

struct Vec3 { x: f32, y: f32, z: f32, w: f32 }
struct Mat4 { m: [[f32; 4]; 4] }

fn math_abs(a: f32) -> f32 { if a < 0.0 { return -a; } return a; }
fn math_fmod(a: f32, b: f32) -> f32 {
    let mut res = a;
    while res >= b { res = res - b; }
    while res < 0.0 { res = res + b; }
    return res;
}

fn taylor_sin(mut x: f32) -> f32 {
    let PI2 = 6.28318530718;
    x = math_fmod(x, PI2);
    if x > 3.14159265 { x = x - PI2; }
    let x2 = x * x;
    let x3 = x2 * x;
    let x5 = x3 * x2;
    let x7 = x5 * x2;
    return x - (x3 / 6.0) + (x5 / 120.0) - (x7 / 5040.0);
}

fn taylor_cos(mut x: f32) -> f32 {
    let PI2 = 6.28318530718;
    x = math_fmod(x, PI2);
    if x > 3.14159265 { x = x - PI2; }
    let x2 = x * x;
    let x4 = x2 * x2;
    let x6 = x4 * x2;
    return 1.0 - (x2 / 2.0) + (x4 / 24.0) - (x6 / 720.0);
}

fn mat4_identity() -> Mat4 {
    let mut mat: Mat4;
    for i in 0..4 { for j in 0..4 { mat.m[i][j] = 0.0; } }
    mat.m[0][0] = 1.0; mat.m[1][1] = 1.0; mat.m[2][2] = 1.0; mat.m[3][3] = 1.0;
    return mat;
}

fn mat4_mul(a: ptr<Mat4>, b: ptr<Mat4>) -> Mat4 {
    let mut res: Mat4;
    for c in 0..4 {
        for r in 0..4 {
            res.m[r][c] = (*a).m[r][0] * (*b).m[0][c] + (*a).m[r][1] * (*b).m[1][c] + (*a).m[r][2] * (*b).m[2][c] + (*a).m[r][3] * (*b).m[3][c];
        }
    }
    return res;
}

fn mat4_make_rot_x(angle: f32) -> Mat4 {
    let mut mat = mat4_identity();
    let c = taylor_cos(angle); let s = taylor_sin(angle);
    mat.m[1][1] = c; mat.m[1][2] = -s;
    mat.m[2][1] = s; mat.m[2][2] = c;
    return mat;
}

fn mat4_make_rot_y(angle: f32) -> Mat4 {
    let mut mat = mat4_identity();
    let c = taylor_cos(angle); let s = taylor_sin(angle);
    mat.m[0][0] = c; mat.m[0][2] = s;
    mat.m[2][0] = -s; mat.m[2][2] = c;
    return mat;
}

fn mat4_make_rot_z(angle: f32) -> Mat4 {
    let mut mat = mat4_identity();
    let c = taylor_cos(angle); let s = taylor_sin(angle);
    mat.m[0][0] = c; mat.m[0][1] = -s;
    mat.m[1][0] = s; mat.m[1][1] = c;
    return mat;
}

fn mat4_make_proj(fov: f32, aspect: f32, near: f32, far: f32) -> Mat4 {
    let f = 1.0 / taylor_sin(fov * 0.5) / taylor_cos(fov * 0.5);
    let mut mat: Mat4;
    for i in 0..4 { for j in 0..4 { mat.m[i][j] = 0.0; } }
    mat.m[0][0] = f / aspect;
    mat.m[1][1] = f;
    mat.m[2][2] = far / (far - near);
    mat.m[2][3] = (-far * near) / (far - near);
    mat.m[3][2] = 1.0;
    return mat;
}

fn mat4_multiply_vec(m: ptr<Mat4>, i: ptr<Vec3>) -> Vec3 {
    let mut v: Vec3;
    v.x = (*i).x * (*m).m[0][0] + (*i).y * (*m).m[0][1] + (*i).z * (*m).m[0][2] + (*i).w * (*m).m[0][3];
    v.y = (*i).x * (*m).m[1][0] + (*i).y * (*m).m[1][1] + (*i).z * (*m).m[1][2] + (*i).w * (*m).m[1][3];
    v.z = (*i).x * (*m).m[2][0] + (*i).y * (*m).m[2][1] + (*i).z * (*m).m[2][2] + (*i).w * (*m).m[2][3];
    v.w = (*i).x * (*m).m[3][0] + (*i).y * (*m).m[3][1] + (*i).z * (*m).m[3][2] + (*i).w * (*m).m[3][3];
    return v;
}

struct Triangle3D { p: [Vec3; 3], color: u32 }
struct Mesh3D { tris: ptr<Triangle3D>, count: u32 }

let mut z_buffer: ptr<f32>;

fn render_init_3d(w: u32, h: u32) {
    z_buffer = pmm_alloc_blocks((w * h * 4) / PAGE_SIZE + 1) as ptr<f32>;
}

fn render_clear_z_buffer(w: u32, h: u32) {
    for i in 0..(w * h) { *(z_buffer as u64 + i as u64 * 4) as ptr<f32> = 0.0; }
}

fn draw_flat_triangle(win: ptr<CompositorWindow>, x0: i32, y0: i32, z0: f32, x1: i32, y1: i32, z1: f32, x2: i32, y2: i32, z2: f32, color: u32) {
    let mut min_y = y0; if y1 < min_y { min_y = y1; } if y2 < min_y { min_y = y2; }
    let mut max_y = y0; if y1 > max_y { max_y = y1; } if y2 > max_y { max_y = y2; }
    let mut min_x = x0; if x1 < min_x { min_x = x1; } if x2 < min_x { min_x = x2; }
    let mut max_x = x0; if x1 > max_x { max_x = x1; } if x2 > max_x { max_x = x2; }

    if min_x < 0 { min_x = 0; }
    if min_y < 0 { min_y = 0; }
    if max_x >= (*win).width as i32 { max_x = (*win).width as i32 - 1; }
    if max_y >= (*win).height as i32 { max_y = (*win).height as i32 - 1; }

    let buf = (*win).buffer_phys as ptr<u32>;
    let z_ptr = z_buffer;

    for y in min_y..=max_y {
        for x in min_x..=max_x {
            let w0 = ((x1 - x0) * (y - y0) - (y1 - y0) * (x - x0)) as f32;
            let w1 = ((x2 - x1) * (y - y1) - (y2 - y1) * (x - x1)) as f32;
            let w2 = ((x0 - x2) * (y - y2) - (y0 - y2) * (x - x2)) as f32;

            if (w0 >= 0.0 && w1 >= 0.0 && w2 >= 0.0) || (w0 <= 0.0 && w1 <= 0.0 && w2 <= 0.0) {
                let area = w0 + w1 + w2;
                let b0 = w1 / area; let b1 = w2 / area; let b2 = w0 / area;
                let z = z0 * b0 + z1 * b1 + z2 * b2;
                let z_idx = (y * (*win).width as i32 + x) as u64;
                let current_z = *(z_ptr as u64 + z_idx * 4) as ptr<f32>;

                if z > *current_z {
                    *current_z = z;
                    *(buf + z_idx) = color;
                }
            }
        }
    }
}

fn render_mesh(win: ptr<CompositorWindow>, mesh: ptr<Mesh3D>, mat_world: ptr<Mat4>, mat_proj: ptr<Mat4>) {
    for i in 0..(*mesh).count {
        let tri = ((*mesh).tris as u64 + i as u64 * sizeof(Triangle3D) as u64) as ptr<Triangle3D>;
        let mut tri_proj: Triangle3D;
        let mut tri_trans: Triangle3D;
        
        for j in 0..3 {
            tri_trans.p[j] = mat4_multiply_vec(mat_world, &(*tri).p[j] as ptr<Vec3>);
            tri_proj.p[j] = mat4_multiply_vec(mat_proj, &tri_trans.p[j] as ptr<Vec3>);
            
            if tri_proj.p[j].w != 0.0 {
                tri_proj.p[j].x = tri_proj.p[j].x / tri_proj.p[j].w;
                tri_proj.p[j].y = tri_proj.p[j].y / tri_proj.p[j].w;
                tri_proj.p[j].z = tri_proj.p[j].z / tri_proj.p[j].w;
            }
            
            tri_proj.p[j].x = (tri_proj.p[j].x + 1.0) * 0.5 * (*win).width as f32;
            tri_proj.p[j].y = (tri_proj.p[j].y + 1.0) * 0.5 * (*win).height as f32;
        }
        
        let normal_x = (tri_trans.p[1].y - tri_trans.p[0].y) * (tri_trans.p[2].z - tri_trans.p[0].z) - (tri_trans.p[1].z - tri_trans.p[0].z) * (tri_trans.p[2].y - tri_trans.p[0].y);
        let normal_y = (tri_trans.p[1].z - tri_trans.p[0].z) * (tri_trans.p[2].x - tri_trans.p[0].x) - (tri_trans.p[1].x - tri_trans.p[0].x) * (tri_trans.p[2].z - tri_trans.p[0].z);
        let normal_z = (tri_trans.p[1].x - tri_trans.p[0].x) * (tri_trans.p[2].y - tri_trans.p[0].y) - (tri_trans.p[1].y - tri_trans.p[0].y) * (tri_trans.p[2].x - tri_trans.p[0].x);
        
        if normal_x * tri_trans.p[0].x + normal_y * tri_trans.p[0].y + normal_z * tri_trans.p[0].z < 0.0 {
            let shade = math_abs(normal_z) * 255.0;
            let c_r = (((*tri).color >> 16) & 0xFF) as f32 * shade / 255.0;
            let c_g = (((*tri).color >> 8) & 0xFF) as f32 * shade / 255.0;
            let c_b = ((*tri).color & 0xFF) as f32 * shade / 255.0;
            let shaded_color = ((c_r as u32) << 16) | ((c_g as u32) << 8) | (c_b as u32);
            
            draw_flat_triangle(win, tri_proj.p[0].x as i32, tri_proj.p[0].y as i32, tri_proj.p[0].z,
                                    tri_proj.p[1].x as i32, tri_proj.p[1].y as i32, tri_proj.p[1].z,
                                    tri_proj.p[2].x as i32, tri_proj.p[2].y as i32, tri_proj.p[2].z, shaded_color);
        }
    }
}

let mut prng_state: u64 = 0x8817263544132211;

fn rand_next() -> u64 {
    prng_state ^= prng_state << 13;
    prng_state ^= prng_state >> 7;
    prng_state ^= prng_state << 17;
    return prng_state;
}

fn rand_seed(seed: u64) {
    if seed != 0 { prng_state = seed; }
}

fn strchr(str: ptr<u8>, c: u8) -> ptr<u8> {
    let mut i: u64 = 0;
    while *(str + i) != 0 {
        if *(str + i) == c { return (str as u64 + i) as ptr<u8>; }
        i = i + 1;
    }
    if c == 0 { return (str as u64 + i) as ptr<u8>; }
    return 0 as ptr<u8>;
}

fn strcat(dest: ptr<u8>, src: ptr<u8>) {
    let mut i: u64 = 0;
    while *(dest + i) != 0 { i = i + 1; }
    let mut j: u64 = 0;
    while *(src + j) != 0 {
        *(dest + i + j) = *(src + j);
        j = j + 1;
    }
    *(dest + i + j) = 0;
}

fn strncmp(s1: ptr<u8>, s2: ptr<u8>, n: u64) -> i32 {
    for i in 0..n {
        if *(s1 + i) == 0 || *(s1 + i) != *(s2 + i) {
            return (*(s1 + i) - *(s2 + i)) as i32;
        }
    }
    return 0;
}

fn atoi(str: ptr<u8>) -> i32 {
    let mut res: i32 = 0;
    let mut sign: i32 = 1;
    let mut i: u64 = 0;
    if *(str + i) == '-' as u8 {
        sign = -1;
        i = i + 1;
    }
    while *(str + i) >= '0' as u8 && *(str + i) <= '9' as u8 {
        res = res * 10 + (*(str + i) - '0' as u8) as i32;
        i = i + 1;
    }
    return res * sign;
}

fn itoa(val: i32, base: i32, buf: ptr<u8>) {
    let mut i: u64 = 0;
    let mut is_neg = false;
    let mut num = val;
    if num == 0 {
        *(buf + i) = '0' as u8;
        *(buf + i + 1) = 0;
        return;
    }
    if num < 0 && base == 10 {
        is_neg = true;
        num = -num;
    }
    while num != 0 {
        let rem = num % base;
        if rem > 9 {
            *(buf + i) = (rem - 10 + 'a' as i32) as u8;
        } else {
            *(buf + i) = (rem + '0' as i32) as u8;
        }
        i = i + 1;
        num = num / base;
    }
    if is_neg {
        *(buf + i) = '-' as u8;
        i = i + 1;
    }
    *(buf + i) = 0;
    let mut start: u64 = 0;
    let mut end: u64 = i - 1;
    while start < end {
        let temp = *(buf + start);
        *(buf + start) = *(buf + end);
        *(buf + end) = temp;
        start = start + 1;
        end = end - 1;
    }
}

let mut b64_table: ptr<u8> = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/" as ptr<u8>;

fn base64_encode(src: ptr<u8>, len: u64, out: ptr<u8>) {
    let mut i: u64 = 0;
    let mut j: u64 = 0;
    while i < len {
        let octet_a = if i < len { *(src + i) } else { 0 };
        let octet_b = if i + 1 < len { *(src + i + 1) } else { 0 };
        let octet_c = if i + 2 < len { *(src + i + 2) } else { 0 };
        let triple = ((octet_a as u32) << 16) + ((octet_b as u32) << 8) + (octet_c as u32);
        *(out + j) = *(b64_table + ((triple >> 18) & 0x3F) as u64);
        *(out + j + 1) = *(b64_table + ((triple >> 12) & 0x3F) as u64);
        *(out + j + 2) = if i + 1 < len { *(b64_table + ((triple >> 6) & 0x3F) as u64) } else { '=' as u8 };
        *(out + j + 3) = if i + 2 < len { *(b64_table + (triple & 0x3F) as u64) } else { '=' as u8 };
        i = i + 3;
        j = j + 4;
    }
    *(out + j) = 0;
}

fn tcp_accept(sock: ptr<TcpSocket>) -> ptr<TcpSocket> {
    spin_lock(&((*sock).lock));
    if (*sock).state == TCP_STATE_SYN_RCVD {
        let new_sock = tcp_create_socket();
        if new_sock != 0 as ptr<TcpSocket> {
            (*new_sock).state = TCP_STATE_ESTABLISHED;
            (*new_sock).local_port = (*sock).local_port;
            (*new_sock).remote_port = (*sock).remote_port;
            (*new_sock).remote_ip = (*sock).remote_ip;
            (*new_sock).seq_num = (*sock).seq_num;
            (*new_sock).ack_num = (*sock).ack_num;
            (*sock).state = TCP_STATE_LISTEN;
            spin_unlock(&((*sock).lock));
            return new_sock;
        }
    }
    spin_unlock(&((*sock).lock));
    return 0 as ptr<TcpSocket>;
}

fn tcp_receive(sock: ptr<TcpSocket>, buffer: ptr<u8>, max_len: u32) -> u32 {
    spin_lock(&((*sock).lock));
    let mut bytes_read: u32 = 0;
    while (*sock).rx_head != (*sock).rx_tail && bytes_read < max_len {
        *(buffer + bytes_read as u64) = *((*sock).rx_buffer as u64 + (*sock).rx_tail as u64) as ptr<u8>;
        (*sock).rx_tail = ((*sock).rx_tail + 1) % (PAGE_SIZE as u32 * 2);
        bytes_read = bytes_read + 1;
    }
    spin_unlock(&((*sock).lock));
    return bytes_read;
}

fn tcp_send_data(sock: ptr<TcpSocket>, data: ptr<u8>, len: u32) {
    spin_lock(&((*sock).lock));
    if (*sock).state == TCP_STATE_ESTABLISHED {
        tcp_send_segment(sock, 0x0018, data, len as u16);
        (*sock).seq_num = (*sock).seq_num + len;
    }
    spin_unlock(&((*sock).lock));
}

let mut http_200_hdr: ptr<u8> = "HTTP/1.1 200 OK\r\nServer: Aegis-X/1.0\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n" as ptr<u8>;
let mut http_404_hdr: ptr<u8> = "HTTP/1.1 404 Not Found\r\nServer: Aegis-X/1.0\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n" as ptr<u8>;
let mut http_index_html: ptr<u8> = "<html><head><title>YBG13 Aegis-X</title></head><body style='background-color:#111;color:#0f0;font-family:monospace;'><h1>Aegis-X Web Server Running</h1><p>Welcome to the 64-bit OS Web Interface.</p><hr><p>Powered by CHT-Core</p></body></html>" as ptr<u8>;

fn http_handle_client(client_sock: ptr<TcpSocket>) {
    let req_buf = pmm_alloc_blocks(1) as ptr<u8>;
    memset(req_buf, 0, PAGE_SIZE);
    let mut wait_timeout = 10000;
    let mut req_len: u32 = 0;
    while wait_timeout > 0 {
        let r = tcp_receive(client_sock, (req_buf as u64 + req_len as u64) as ptr<u8>, PAGE_SIZE as u32 - req_len);
        req_len = req_len + r;
        if req_len > 4 {
            if *(req_buf as u64 + req_len as u64 - 1) as ptr<u8> == 10 && *(req_buf as u64 + req_len as u64 - 3) as ptr<u8> == 10 {
                break;
            }
        }
        wait_timeout = wait_timeout - 1;
        cpu_pause();
    }
    
    if req_len > 0 {
        if strncmp(req_buf, "GET / " as ptr<u8>, 6) == 0 {
            let res_buf = pmm_alloc_blocks(2) as ptr<u8>;
            memset(res_buf, 0, PAGE_SIZE * 2);
            strcpy(res_buf, http_200_hdr);
            strcat(res_buf, http_index_html);
            tcp_send_data(client_sock, res_buf, strlen(res_buf) as u32);
            pmm_free_blocks(res_buf as u64, 2);
        } else {
            let res_buf = pmm_alloc_blocks(1) as ptr<u8>;
            memset(res_buf, 0, PAGE_SIZE);
            strcpy(res_buf, http_404_hdr);
            strcat(res_buf, "<html><body><h1>404 File Not Found</h1></body></html>" as ptr<u8>);
            tcp_send_data(client_sock, res_buf, strlen(res_buf) as u32);
            pmm_free_blocks(res_buf as u64, 1);
        }
    }
    
    tcp_close(client_sock);
    pmm_free_blocks(req_buf as u64, 1);
    (*current_process).state = 0;
    scheduler_tick();
}

fn http_server_task() {
    let server_sock = tcp_create_socket();
    tcp_bind(server_sock, 80);
    tcp_listen(server_sock);
    
    loop {
        let client_sock = tcp_accept(server_sock);
        if client_sock != 0 as ptr<TcpSocket> {
            let proc = create_process(http_handle_client as u64, true);
            let ctx = (*proc).context;
            (*ctx).rdi = client_sock as u64;
        }
        scheduler_tick();
    }
}

struct ShellCtx {
    win: ptr<CompositorWindow>,
    cx: u32,
    cy: u32,
    buf: [u8; 512],
    pos: u32,
    cwd: [u8; 256],
    fg_color: u32,
}

let mut global_shell: ptr<ShellCtx>;

fn shell_print_char(c: u8) {
    if c == 10 {
        (*global_shell).cx = 2;
        (*global_shell).cy = (*global_shell).cy + system_font_h + 2;
    } else if c == 8 {
        if (*global_shell).cx > 2 {
            (*global_shell).cx = (*global_shell).cx - system_font_w;
            gui_draw_char((*global_shell).win, ' ' as u8, (*global_shell).cx, (*global_shell).cy, (*global_shell).fg_color, 0x000000);
        }
    } else {
        gui_draw_char((*global_shell).win, c, (*global_shell).cx, (*global_shell).cy, (*global_shell).fg_color, 0x000000);
        (*global_shell).cx = (*global_shell).cx + system_font_w;
        if (*global_shell).cx >= (*(*global_shell).win).width - system_font_w {
            (*global_shell).cx = 2;
            (*global_shell).cy = (*global_shell).cy + system_font_h + 2;
        }
    }
    if (*global_shell).cy >= (*(*global_shell).win).height - system_font_h {
        comp_draw_rect((*global_shell).win, 0, 0, (*(*global_shell).win).width, (*(*global_shell).win).height, 0x000000);
        (*global_shell).cx = 2;
        (*global_shell).cy = 2;
    }
}

fn shell_print_string(str: ptr<u8>) {
    let mut i: u64 = 0;
    while *(str + i) != 0 {
        shell_print_char(*(str + i));
        i = i + 1;
    }
}

fn shell_draw_prompt() {
    (*global_shell).fg_color = 0x00FF00;
    shell_print_string("root@aegis-x:" as ptr<u8>);
    (*global_shell).fg_color = 0x00AFFF;
    shell_print_string(&((*global_shell).cwd[0]) as ptr<u8>);
    (*global_shell).fg_color = 0xFFFFFF;
    shell_print_string("# " as ptr<u8>);
}

fn shell_cmd_clear() {
    comp_draw_rect((*global_shell).win, 0, 0, (*(*global_shell).win).width, (*(*global_shell).win).height, 0x000000);
    (*global_shell).cx = 2;
    (*global_shell).cy = 2;
}

fn shell_cmd_help() {
    shell_print_string("Aegis-X Shell v1.0\n" as ptr<u8>);
    shell_print_string("Commands: help, clear, echo, ls, cat, uptime, reboot, poweroff\n" as ptr<u8>);
}

fn shell_cmd_echo(args: ptr<u8>) {
    shell_print_string(args);
    shell_print_char(10);
}

fn shell_cmd_uptime() {
    let mut buf: [u8; 32];
    let ticks = rtc_tick;
    shell_print_string("Uptime: " as ptr<u8>);
    itoa(ticks as i32, 10, &buf[0] as ptr<u8>);
    shell_print_string(&buf[0] as ptr<u8>);
    shell_print_string(" ticks\n" as ptr<u8>);
}

fn shell_cmd_ls(args: ptr<u8>) {
    let mut path = &((*global_shell).cwd[0]) as ptr<u8>;
    if *args != 0 { path = args; }
    let dir = vfs_find_child(global_vfs_root, path);
    if dir == 0 as ptr<VfsNode> {
        shell_print_string("ls: cannot access path\n" as ptr<u8>);
        return;
    }
    if ((*dir).flags & 0x07) != 0 {
        let mut curr = (*dir).children;
        while curr != 0 as ptr<VfsNode> {
            if ((*curr).flags & 0x07) != 0 {
                (*global_shell).fg_color = 0x00AFFF;
            } else {
                (*global_shell).fg_color = 0xFFFFFF;
            }
            shell_print_string(&((*curr).name[0]) as ptr<u8>);
            shell_print_string("  " as ptr<u8>);
            curr = (*curr).next;
        }
        shell_print_char(10);
    } else {
        shell_print_string(&((*dir).name[0]) as ptr<u8>);
        shell_print_char(10);
    }
    (*global_shell).fg_color = 0xFFFFFF;
}

fn shell_execute() {
    let mut cmd_buf: [u8; 512];
    memcpy(&cmd_buf[0] as ptr<u8>, &((*global_shell).buf[0]) as ptr<u8>, (*global_shell).pos as u64);
    cmd_buf[(*global_shell).pos as usize] = 0;
    
    let mut i: u32 = 0;
    while cmd_buf[i as usize] != 0 && cmd_buf[i as usize] != ' ' as u8 { i = i + 1; }
    if cmd_buf[i as usize] == ' ' as u8 {
        cmd_buf[i as usize] = 0;
        i = i + 1;
    }
    let args = (&cmd_buf[0] as u64 + i as u64) as ptr<u8>;
    let cmd = &cmd_buf[0] as ptr<u8>;
    
    if (*global_shell).pos > 0 {
        if strcmp(cmd, "help" as ptr<u8>) == 0 { shell_cmd_help(); }
        else if strcmp(cmd, "clear" as ptr<u8>) == 0 { shell_cmd_clear(); }
        else if strcmp(cmd, "echo" as ptr<u8>) == 0 { shell_cmd_echo(args); }
        else if strcmp(cmd, "uptime" as ptr<u8>) == 0 { shell_cmd_uptime(); }
        else if strcmp(cmd, "ls" as ptr<u8>) == 0 { shell_cmd_ls(args); }
        else if strcmp(cmd, "reboot" as ptr<u8>) == 0 { acpi_reset(); }
        else if strcmp(cmd, "poweroff" as ptr<u8>) == 0 { acpi_power_off(); }
        else {
            shell_print_string("Command not found: " as ptr<u8>);
            shell_print_string(cmd);
            shell_print_char(10);
        }
    }
    
    (*global_shell).pos = 0;
    shell_draw_prompt();
}

fn shell_task() {
    let win = comp_create_window(50, 50, 800, 600, "Aegis Terminal" as ptr<u8>);
    comp_draw_rect(win, 0, 0, (*win).width, (*win).height, 0x000000);
    
    global_shell = pmm_alloc_blocks(1) as ptr<ShellCtx>;
    memset(global_shell as ptr<u8>, 0, sizeof(ShellCtx) as u64);
    (*global_shell).win = win;
    (*global_shell).cx = 2;
    (*global_shell).cy = 2;
    (*global_shell).fg_color = 0xFFFFFF;
    strcpy(&((*global_shell).cwd[0]) as ptr<u8>, "/" as ptr<u8>);
    
    shell_print_string("Welcome to YBG13 Aegis-X Terminal.\n" as ptr<u8>);
    shell_draw_prompt();
    
    loop {
        let c = kbd_read();
        if c != 0 {
            if c == 10 {
                shell_print_char(10);
                shell_execute();
            } else if c == 8 {
                if (*global_shell).pos > 0 {
                    (*global_shell).pos = (*global_shell).pos - 1;
                    shell_print_char(8);
                }
            } else {
                if (*global_shell).pos < 510 {
                    (*global_shell).buf[(*global_shell).pos as usize] = c;
                    (*global_shell).pos = (*global_shell).pos + 1;
                    shell_print_char(c);
                }
            }
        }
        scheduler_tick();
    }
}

struct VmaNode {
    start_vaddr: u64,
    end_vaddr: u64,
    flags: u32,
    file_node: ptr<VfsNode>,
    file_offset: u64,
    next: ptr<VmaNode>,
}

struct ProcessMemoryMap {
    vma_head: ptr<VmaNode>,
    brk_start: u64,
    brk_current: u64,
    stack_bottom: u64,
    stack_top: u64,
    mmap_base: u64,
}

fn vma_create(proc_map: ptr<ProcessMemoryMap>, start: u64, len: u64, flags: u32, file: ptr<VfsNode>, offset: u64) -> ptr<VmaNode> {
    let node = pmm_alloc_blocks(1) as ptr<VmaNode>;
    memset(node as ptr<u8>, 0, sizeof(VmaNode) as u64);
    (*node).start_vaddr = start;
    (*node).end_vaddr = start + len;
    (*node).flags = flags;
    (*node).file_node = file;
    (*node).file_offset = offset;
    
    if (*proc_map).vma_head == 0 as ptr<VmaNode> {
        (*proc_map).vma_head = node;
    } else {
        let mut curr = (*proc_map).vma_head;
        while (*curr).next != 0 as ptr<VmaNode> {
            curr = (*curr).next;
        }
        (*curr).next = node;
    }
    return node;
}

fn vma_find_region(proc_map: ptr<ProcessMemoryMap>, vaddr: u64) -> ptr<VmaNode> {
    let mut curr = (*proc_map).vma_head;
    while curr != 0 as ptr<VmaNode> {
        if vaddr >= (*curr).start_vaddr && vaddr < (*curr).end_vaddr {
            return curr;
        }
        curr = (*curr).next;
    }
    return 0 as ptr<VmaNode>;
}

struct TarHeader {
    filename: [u8; 100],
    filemode: [u8; 8],
    owner_id: [u8; 8],
    group_id: [u8; 8],
    filesize: [u8; 12],
    last_mod: [u8; 12],
    checksum: [u8; 8],
    type_flag: u8,
    linked_file: [u8; 100],
    ustar_magic: [u8; 6],
    ustar_version: [u8; 2],
    owner_name: [u8; 32],
    group_name: [u8; 32],
    dev_major: [u8; 8],
    dev_minor: [u8; 8],
    prefix: [u8; 155],
    padding: [u8; 12],
}

fn tar_octal_to_int(octal_str: ptr<u8>, len: u32) -> u64 {
    let mut result: u64 = 0;
    for i in 0..len {
        let c = *(octal_str + i as u64);
        if c >= '0' as u8 && c <= '7' as u8 {
            result = result * 8 + (c - '0' as u8) as u64;
        } else {
            break;
        }
    }
    return result;
}

fn tar_extract_initramfs(ramfs_base: u64, ramfs_size: u64) {
    let mut current_offset: u64 = 0;
    while current_offset < ramfs_size {
        let header = (ramfs_base + current_offset) as ptr<TarHeader>;
        if (*header).filename[0] == 0 { break; }
        
        let size_val = tar_octal_to_int(&((*header).filesize[0]) as ptr<u8>, 11);
        let mode_val = tar_octal_to_int(&((*header).filemode[0]) as ptr<u8>, 7);
        let mut name_buf: [u8; 256];
        memset(&name_buf[0] as ptr<u8>, 0, 256);
        
        if (*header).prefix[0] != 0 {
            strcpy(&name_buf[0] as ptr<u8>, &((*header).prefix[0]) as ptr<u8>);
            strcat(&name_buf[0] as ptr<u8>, "/" as ptr<u8>);
        }
        strcat(&name_buf[0] as ptr<u8>, &((*header).filename[0]) as ptr<u8>);
        
        let file_data_ptr = ramfs_base + current_offset + 512;
        
        if (*header).type_flag == '0' as u8 || (*header).type_flag == 0 {
            let mut fd: FileDescriptor;
            let node = vfs_create_node(global_vfs_root, &name_buf[0] as ptr<u8>, 0x06);
            (*node).ptr = file_data_ptr;
            (*node).length = size_val;
            (*node).uid = 0;
            (*node).gid = 0;
        } else if (*header).type_flag == '5' as u8 {
            vfs_create_node(global_vfs_root, &name_buf[0] as ptr<u8>, 0x07);
        }
        
        let aligned_size = (size_val + 511) & !511;
        current_offset = current_offset + 512 + aligned_size;
    }
}

const REG_TYPE_INT: u32 = 1;
const REG_TYPE_STR: u32 = 2;
const REG_TYPE_BIN: u32 = 3;

struct RegistryNode {
    key_name: [u8; 64],
    val_type: u32,
    val_int: u64,
    val_str: [u8; 256],
    val_bin: ptr<u8>,
    bin_len: u64,
    parent: ptr<RegistryNode>,
    child: ptr<RegistryNode>,
    next: ptr<RegistryNode>,
}

let mut global_registry_root: ptr<RegistryNode>;

fn registry_init() {
    global_registry_root = pmm_alloc_blocks(1) as ptr<RegistryNode>;
    memset(global_registry_root as ptr<u8>, 0, sizeof(RegistryNode) as u64);
    strcpy(&((*global_registry_root).key_name[0]) as ptr<u8>, "ROOT" as ptr<u8>);
}

fn registry_create_key(parent: ptr<RegistryNode>, name: ptr<u8>) -> ptr<RegistryNode> {
    let node = pmm_alloc_blocks(1) as ptr<RegistryNode>;
    memset(node as ptr<u8>, 0, sizeof(RegistryNode) as u64);
    strcpy(&((*node).key_name[0]) as ptr<u8>, name);
    (*node).parent = parent;
    
    if (*parent).child == 0 as ptr<RegistryNode> {
        (*parent).child = node;
    } else {
        let mut curr = (*parent).child;
        while (*curr).next != 0 as ptr<RegistryNode> {
            curr = (*curr).next;
        }
        (*curr).next = node;
    }
    return node;
}

fn registry_find_key(parent: ptr<RegistryNode>, name: ptr<u8>) -> ptr<RegistryNode> {
    let mut curr = (*parent).child;
    while curr != 0 as ptr<RegistryNode> {
        if strcmp(&((*curr).key_name[0]) as ptr<u8>, name) == 0 {
            return curr;
        }
        curr = (*curr).next;
    }
    return 0 as ptr<RegistryNode>;
}

fn registry_set_int(node: ptr<RegistryNode>, val: u64) {
    (*node).val_type = REG_TYPE_INT;
    (*node).val_int = val;
}

fn registry_set_str(node: ptr<RegistryNode>, val: ptr<u8>) {
    (*node).val_type = REG_TYPE_STR;
    strcpy(&((*node).val_str[0]) as ptr<u8>, val);
}

fn registry_set_bin(node: ptr<RegistryNode>, val: ptr<u8>, len: u64) {
    (*node).val_type = REG_TYPE_BIN;
    if (*node).val_bin != 0 as ptr<u8> {
        pmm_free_blocks((*node).val_bin as u64, ((*node).bin_len / PAGE_SIZE) + 1);
    }
    (*node).val_bin = pmm_alloc_blocks((len / PAGE_SIZE) + 1) as ptr<u8>;
    memcpy((*node).val_bin, val, len);
    (*node).bin_len = len;
}

struct UserAccount {
    uid: u32,
    gid: u32,
    username: [u8; 32],
    pass_hash: [u8; 32],
    pass_salt: [u8; 16],
    home_dir: [u8; 64],
    shell_path: [u8; 64],
    next: ptr<UserAccount>,
}

let mut global_user_db: ptr<UserAccount>;
let mut next_uid: u32 = 1000;

fn auth_init_system() {
    global_user_db = 0 as ptr<UserAccount>;
    let mut root_salt: [u8; 16];
    for i in 0..16 { root_salt[i] = (rand_next() & 0xFF) as u8; }
    auth_create_user("root" as ptr<u8>, "aegis_admin" as ptr<u8>, 0, 0, "/root" as ptr<u8>, "/bin/shell" as ptr<u8>);
}

fn auth_generate_hash(password: ptr<u8>, salt: ptr<u8>, out_hash: ptr<u8>) {
    let mut pass_len = strlen(password);
    let mut buffer: [u8; 128];
    memset(&buffer[0] as ptr<u8>, 0, 128);
    memcpy(&buffer[0] as ptr<u8>, password, pass_len);
    memcpy((&buffer[0] as u64 + pass_len) as ptr<u8>, salt, 16);
    
    let mut ctx: Sha256Ctx;
    sha256_init(&ctx);
    sha256_transform(&ctx, &buffer[0] as ptr<u8>);
    
    for iter in 0..999 {
        let mut temp_ctx: Sha256Ctx;
        sha256_init(&temp_ctx);
        let state_ptr = &ctx.state[0] as ptr<u32> as ptr<u8>;
        sha256_transform(&temp_ctx, state_ptr);
        for i in 0..8 { ctx.state[i] = temp_ctx.state[i]; }
    }
    
    let state_ptr = &ctx.state[0] as ptr<u32> as ptr<u8>;
    for i in 0..32 {
        *(out_hash + i) = *(state_ptr + i);
    }
}

fn auth_create_user(username: ptr<u8>, password: ptr<u8>, uid_force: u32, gid: u32, home: ptr<u8>, shell: ptr<u8>) -> ptr<UserAccount> {
    let new_user = pmm_alloc_blocks(1) as ptr<UserAccount>;
    memset(new_user as ptr<u8>, 0, sizeof(UserAccount) as u64);
    
    strcpy(&((*new_user).username[0]) as ptr<u8>, username);
    strcpy(&((*new_user).home_dir[0]) as ptr<u8>, home);
    strcpy(&((*new_user).shell_path[0]) as ptr<u8>, shell);
    
    if uid_force != 0xFFFFFFFF {
        (*new_user).uid = uid_force;
    } else {
        (*new_user).uid = next_uid;
        next_uid = next_uid + 1;
    }
    (*new_user).gid = gid;
    
    for i in 0..16 { (*new_user).pass_salt[i] = (rand_next() & 0xFF) as u8; }
    auth_generate_hash(password, &((*new_user).pass_salt[0]) as ptr<u8>, &((*new_user).pass_hash[0]) as ptr<u8>);
    
    (*new_user).next = global_user_db;
    global_user_db = new_user;
    return new_user;
}

fn auth_verify_login(username: ptr<u8>, password: ptr<u8>) -> ptr<UserAccount> {
    let mut curr = global_user_db;
    while curr != 0 as ptr<UserAccount> {
        if strcmp(&((*curr).username[0]) as ptr<u8>, username) == 0 {
            let mut test_hash: [u8; 32];
            auth_generate_hash(password, &((*curr).pass_salt[0]) as ptr<u8>, &test_hash[0] as ptr<u8>);
            if memcmp(&((*curr).pass_hash[0]) as ptr<u8>, &test_hash[0] as ptr<u8>, 32) == 0 {
                return curr;
            } else {
                return 0 as ptr<UserAccount>;
            }
        }
        curr = (*curr).next;
    }
    return 0 as ptr<UserAccount>;
}

struct ServiceDaemon {
    name: [u8; 64],
    exec_path: [u8; 128],
    pid: u64,
    status: u32,
    runlevel: u32,
    restart_count: u32,
    deps: [u64; 8],
    dep_count: u32,
    next: ptr<ServiceDaemon>,
}

const SRV_STATUS_STOPPED: u32 = 0;
const SRV_STATUS_STARTING: u32 = 1;
const SRV_STATUS_RUNNING: u32 = 2;
const SRV_STATUS_FAILED: u32 = 3;

let mut global_service_list: ptr<ServiceDaemon>;
let mut init_current_runlevel: u32 = 0;

fn init_register_service(name: ptr<u8>, path: ptr<u8>, runlevel: u32) -> ptr<ServiceDaemon> {
    let srv = pmm_alloc_blocks(1) as ptr<ServiceDaemon>;
    memset(srv as ptr<u8>, 0, sizeof(ServiceDaemon) as u64);
    strcpy(&((*srv).name[0]) as ptr<u8>, name);
    strcpy(&((*srv).exec_path[0]) as ptr<u8>, path);
    (*srv).status = SRV_STATUS_STOPPED;
    (*srv).runlevel = runlevel;
    (*srv).dep_count = 0;
    
    (*srv).next = global_service_list;
    global_service_list = srv;
    return srv;
}

fn init_add_dependency(srv: ptr<ServiceDaemon>, target_name: ptr<u8>) {
    let mut curr = global_service_list;
    while curr != 0 as ptr<ServiceDaemon> {
        if strcmp(&((*curr).name[0]) as ptr<u8>, target_name) == 0 {
            if (*srv).dep_count < 8 {
                (*srv).deps[(*srv).dep_count as usize] = curr as u64;
                (*srv).dep_count = (*srv).dep_count + 1;
            }
            return;
        }
        curr = (*curr).next;
    }
}

fn init_start_service(srv: ptr<ServiceDaemon>) -> bool {
    if (*srv).status == SRV_STATUS_RUNNING { return true; }
    
    for i in 0..(*srv).dep_count {
        let dep = (*srv).deps[i as usize] as ptr<ServiceDaemon>;
        if (*dep).status != SRV_STATUS_RUNNING {
            if !init_start_service(dep) {
                (*srv).status = SRV_STATUS_FAILED;
                return false;
            }
        }
    }
    
    (*srv).status = SRV_STATUS_STARTING;
    let pid = execve_ring3(&((*srv).exec_path[0]) as ptr<u8>, 0, 0);
    if pid != 0 {
        (*srv).pid = pid;
        (*srv).status = SRV_STATUS_RUNNING;
        return true;
    } else {
        (*srv).status = SRV_STATUS_FAILED;
        return false;
    }
}

fn init_set_runlevel(level: u32) {
    init_current_runlevel = level;
    let mut curr = global_service_list;
    while curr != 0 as ptr<ServiceDaemon> {
        if (*curr).runlevel <= level && (*curr).status == SRV_STATUS_STOPPED {
            init_start_service(curr);
        } else if (*curr).runlevel > level && (*curr).status == SRV_STATUS_RUNNING {
            let mut proc = process_queue;
            while proc != 0 as ptr<ProcessControlBlock> {
                if (*proc).pid == (*curr).pid {
                    (*proc).state = 0;
                    (*curr).status = SRV_STATUS_STOPPED;
                    break;
                }
                proc = (*proc).next;
            }
        }
        curr = (*curr).next;
    }
}

fn init_monitor_loop() {
    loop {
        let mut curr = global_service_list;
        while curr != 0 as ptr<ServiceDaemon> {
            if (*curr).status == SRV_STATUS_RUNNING {
                let mut is_alive = false;
                let mut proc = process_queue;
                while proc != 0 as ptr<ProcessControlBlock> {
                    if (*proc).pid == (*curr).pid && (*proc).state == 1 {
                        is_alive = true;
                        break;
                    }
                    proc = (*proc).next;
                }
                if !is_alive {
                    (*curr).status = SRV_STATUS_FAILED;
                    (*curr).restart_count = (*curr).restart_count + 1;
                    if (*curr).restart_count < 5 {
                        init_start_service(curr);
                    }
                }
            }
            curr = (*curr).next;
        }
        for i in 0..100000 { cpu_pause(); }
        scheduler_tick();
    }
}

struct Ext2Superblock {
    s_inodes_count: u32,
    s_blocks_count: u32,
    s_r_blocks_count: u32,
    s_free_blocks_count: u32,
    s_free_inodes_count: u32,
    s_first_data_block: u32,
    s_log_block_size: u32,
    s_log_frag_size: i32,
    s_blocks_per_group: u32,
    s_frags_per_group: u32,
    s_inodes_per_group: u32,
    s_mtime: u32,
    s_wtime: u32,
    s_mnt_count: u16,
    s_max_mnt_count: i16,
    s_magic: u16,
    s_state: u16,
    s_errors: u16,
    s_minor_rev_level: u16,
    s_lastcheck: u32,
    s_checkinterval: u32,
    s_creator_os: u32,
    s_rev_level: u32,
    s_def_resuid: u16,
    s_def_resgid: u16,
    s_first_ino: u32,
    s_inode_size: u16,
    s_block_group_nr: u16,
    s_feature_compat: u32,
    s_feature_incompat: u32,
    s_feature_ro_compat: u32,
    s_uuid: [u8; 16],
    s_volume_name: [u8; 16],
    s_last_mounted: [u8; 64],
    s_algo_bitmap: u32,
}

struct Ext2BlockGroupDesc {
    bg_block_bitmap: u32,
    bg_inode_bitmap: u32,
    bg_inode_table: u32,
    bg_free_blocks_count: u16,
    bg_free_inodes_count: u16,
    bg_used_dirs_count: u16,
    bg_pad: u16,
    bg_reserved: [u32; 3],
}

struct Ext2Inode {
    i_mode: u16,
    i_uid: u16,
    i_size: u32,
    i_atime: u32,
    i_ctime: u32,
    i_mtime: u32,
    i_dtime: u32,
    i_gid: u16,
    i_links_count: u16,
    i_blocks: u32,
    i_flags: u32,
    i_osd1: u32,
    i_block: [u32; 15],
    i_generation: u32,
    i_file_acl: u32,
    i_dir_acl: u32,
    i_faddr: u32,
    i_osd2: [u32; 3],
}

struct Ext2DirEntry {
    inode: u32,
    rec_len: u16,
    name_len: u8,
    file_type: u8,
}

let mut ext2_sb: ptr<Ext2Superblock>;
let mut ext2_bgdt: ptr<Ext2BlockGroupDesc>;
let mut ext2_block_size: u32 = 0;
let mut ext2_inodes_per_group: u32 = 0;
let mut ext2_inode_size: u32 = 0;
let mut ext2_partition_base: u64 = 0;

fn ext2_read_block(block_num: u32, buf: ptr<u8>) {
    let offset = ext2_partition_base + (block_num as u64 * ext2_block_size as u64);
    let dev_fd = pmm_alloc_blocks(1) as ptr<FileDescriptor>;
    (*dev_fd).node = vfs_find_child(global_vfs_root, "dev/sda1" as ptr<u8>);
    (*dev_fd).offset = offset;
    vfs_read(dev_fd, buf, ext2_block_size as u64);
    pmm_free_blocks(dev_fd as u64, 1);
}

fn ext2_init(partition_base: u64) {
    ext2_partition_base = partition_base;
    let sb_buf = pmm_alloc_blocks(1) as ptr<u8>;
    let dev_fd = pmm_alloc_blocks(1) as ptr<FileDescriptor>;
    (*dev_fd).node = vfs_find_child(global_vfs_root, "dev/sda1" as ptr<u8>);
    (*dev_fd).offset = ext2_partition_base + 1024;
    vfs_read(dev_fd, sb_buf, 1024);
    
    ext2_sb = sb_buf as ptr<Ext2Superblock>;
    if (*ext2_sb).s_magic != 0xEF53 {
        pmm_free_blocks(sb_buf as u64, 1);
        pmm_free_blocks(dev_fd as u64, 1);
        return;
    }
    
    ext2_block_size = 1024 << (*ext2_sb).s_log_block_size;
    ext2_inodes_per_group = (*ext2_sb).s_inodes_per_group;
    if (*ext2_sb).s_rev_level == 0 {
        ext2_inode_size = 128;
    } else {
        ext2_inode_size = (*ext2_sb).s_inode_size as u32;
    }
    
    let bgdt_block = if ext2_block_size == 1024 { 2 } else { 1 };
    let bgdt_buf = pmm_alloc_blocks((ext2_block_size / PAGE_SIZE as u32) + 1) as ptr<u8>;
    ext2_read_block(bgdt_block, bgdt_buf);
    ext2_bgdt = bgdt_buf as ptr<Ext2BlockGroupDesc>;
    
    pmm_free_blocks(dev_fd as u64, 1);
}

fn ext2_get_inode(inode_num: u32, out_inode: ptr<Ext2Inode>) {
    let bg_idx = (inode_num - 1) / ext2_inodes_per_group;
    let local_idx = (inode_num - 1) % ext2_inodes_per_group;
    let bgd = (ext2_bgdt as u64 + bg_idx as u64 * sizeof(Ext2BlockGroupDesc) as u64) as ptr<Ext2BlockGroupDesc>;
    
    let inode_table_block = (*bgd).bg_inode_table;
    let byte_offset = local_idx * ext2_inode_size;
    let block_offset = byte_offset / ext2_block_size;
    let internal_offset = byte_offset % ext2_block_size;
    
    let target_block = inode_table_block + block_offset;
    let buf = pmm_alloc_blocks((ext2_block_size / PAGE_SIZE as u32) + 1) as ptr<u8>;
    ext2_read_block(target_block, buf);
    
    memcpy(out_inode as ptr<u8>, (buf as u64 + internal_offset as u64) as ptr<u8>, sizeof(Ext2Inode) as u64);
    pmm_free_blocks(buf as u64, (ext2_block_size / PAGE_SIZE as u32) + 1);
}

fn ext2_read_inode_data(inode: ptr<Ext2Inode>, buf: ptr<u8>) {
    let blocks_to_read = ((*inode).i_size + ext2_block_size - 1) / ext2_block_size;
    let mut current_block = 0;
    while current_block < blocks_to_read && current_block < 12 {
        let physical_block = (*inode).i_block[current_block as usize];
        if physical_block != 0 {
            ext2_read_block(physical_block, (buf as u64 + current_block as u64 * ext2_block_size as u64) as ptr<u8>);
        }
        current_block = current_block + 1;
    }
}

struct Elf64_Sym {
    st_name: u32,
    st_info: u8,
    st_other: u8,
    st_shndx: u16,
    st_value: u64,
    st_size: u64,
}

struct Elf64_Rela {
    r_offset: u64,
    r_info: u64,
    r_addend: i64,
}

struct Elf64_Dyn {
    d_tag: u64,
    d_val: u64,
}

const DT_NULL: u64 = 0;
const DT_NEEDED: u64 = 1;
const DT_PLTRELSZ: u64 = 2;
const DT_PLTGOT: u64 = 3;
const DT_HASH: u64 = 4;
const DT_STRTAB: u64 = 5;
const DT_SYMTAB: u64 = 6;
const DT_RELA: u64 = 7;
const DT_RELASZ: u64 = 8;
const DT_RELAENT: u64 = 9;
const DT_STRSZ: u64 = 10;
const DT_SYMENT: u64 = 11;

const R_X86_64_NONE: u64 = 0;
const R_X86_64_64: u64 = 1;
const R_X86_64_PC32: u64 = 2;
const R_X86_64_GOT32: u64 = 3;
const R_X86_64_PLT32: u64 = 4;
const R_X86_64_COPY: u64 = 5;
const R_X86_64_GLOB_DAT: u64 = 6;
const R_X86_64_JUMP_SLOT: u64 = 7;
const R_X86_64_RELATIVE: u64 = 8;

fn elf_resolve_dynamic(load_base: u64, dyn_table: ptr<Elf64_Dyn>) {
    let mut strtab: ptr<u8> = 0 as ptr<u8>;
    let mut symtab: ptr<Elf64_Sym> = 0 as ptr<Elf64_Sym>;
    let mut rela: ptr<Elf64_Rela> = 0 as ptr<Elf64_Rela>;
    let mut relasz: u64 = 0;
    
    let mut curr = dyn_table;
    while (*curr).d_tag != DT_NULL {
        if (*curr).d_tag == DT_STRTAB { strtab = (load_base + (*curr).d_val) as ptr<u8>; }
        else if (*curr).d_tag == DT_SYMTAB { symtab = (load_base + (*curr).d_val) as ptr<Elf64_Sym>; }
        else if (*curr).d_tag == DT_RELA { rela = (load_base + (*curr).d_val) as ptr<Elf64_Rela>; }
        else if (*curr).d_tag == DT_RELASZ { relasz = (*curr).d_val; }
        curr = (curr as u64 + sizeof(Elf64_Dyn) as u64) as ptr<Elf64_Dyn>;
    }
    
    if rela != 0 as ptr<Elf64_Rela> && symtab != 0 as ptr<Elf64_Sym> {
        let rela_count = relasz / sizeof(Elf64_Rela) as u64;
        for i in 0..rela_count {
            let rel = (rela as u64 + i * sizeof(Elf64_Rela) as u64) as ptr<Elf64_Rela>;
            let r_type = (*rel).r_info & 0xFFFFFFFF;
            let sym_idx = (*rel).r_info >> 32;
            let target_addr = (load_base + (*rel).r_offset) as ptr<u64>;
            
            if r_type == R_X86_64_RELATIVE {
                *target_addr = (load_base as i64 + (*rel).r_addend) as u64;
            } else if r_type == R_X86_64_GLOB_DAT || r_type == R_X86_64_JUMP_SLOT || r_type == R_X86_64_64 {
                let sym = (symtab as u64 + sym_idx * sizeof(Elf64_Sym) as u64) as ptr<Elf64_Sym>;
                let sym_val = (*sym).st_value;
                if sym_val != 0 {
                    *target_addr = (load_base + sym_val) as i64 as u64 + (*rel).r_addend as u64;
                }
            }
        }
    }
}

struct AnsiState {
    in_escape: bool,
    in_bracket: bool,
    params: [u32; 8],
    param_count: u32,
    current_param: u32,
    saved_x: u32,
    saved_y: u32,
}

let mut global_ansi_state: AnsiState;

fn ansi_init() {
    global_ansi_state.in_escape = false;
    global_ansi_state.in_bracket = false;
    global_ansi_state.param_count = 0;
    global_ansi_state.current_param = 0;
    global_ansi_state.saved_x = 0;
    global_ansi_state.saved_y = 0;
}

fn ansi_apply_colors() {
    for i in 0..global_ansi_state.param_count {
        let p = global_ansi_state.params[i as usize];
        if p == 0 {
            (*global_shell).fg_color = 0xFFFFFF;
        } else if p >= 30 && p <= 37 {
            if p == 30 { (*global_shell).fg_color = 0x000000; }
            else if p == 31 { (*global_shell).fg_color = 0xFF0000; }
            else if p == 32 { (*global_shell).fg_color = 0x00FF00; }
            else if p == 33 { (*global_shell).fg_color = 0xFFFF00; }
            else if p == 34 { (*global_shell).fg_color = 0x0000FF; }
            else if p == 35 { (*global_shell).fg_color = 0xFF00FF; }
            else if p == 36 { (*global_shell).fg_color = 0x00FFFF; }
            else if p == 37 { (*global_shell).fg_color = 0xFFFFFF; }
        }
    }
}

fn ansi_process_char(c: u8) -> bool {
    if c == 27 {
        global_ansi_state.in_escape = true;
        global_ansi_state.in_bracket = false;
        global_ansi_state.param_count = 0;
        global_ansi_state.current_param = 0;
        return true;
    }
    if global_ansi_state.in_escape {
        if !global_ansi_state.in_bracket {
            if c == '[' as u8 {
                global_ansi_state.in_bracket = true;
            } else {
                global_ansi_state.in_escape = false;
            }
            return true;
        }
        
        if c >= '0' as u8 && c <= '9' as u8 {
            global_ansi_state.current_param = global_ansi_state.current_param * 10 + (c - '0' as u8) as u32;
            return true;
        } else if c == ';' as u8 {
            if global_ansi_state.param_count < 8 {
                global_ansi_state.params[global_ansi_state.param_count as usize] = global_ansi_state.current_param;
                global_ansi_state.param_count = global_ansi_state.param_count + 1;
            }
            global_ansi_state.current_param = 0;
            return true;
        } else {
            if global_ansi_state.param_count < 8 {
                global_ansi_state.params[global_ansi_state.param_count as usize] = global_ansi_state.current_param;
                global_ansi_state.param_count = global_ansi_state.param_count + 1;
            }
            
            if c == 'm' as u8 {
                ansi_apply_colors();
            } else if c == 'H' as u8 || c == 'f' as u8 {
                let row = if global_ansi_state.param_count > 0 { global_ansi_state.params[0] } else { 1 };
                let col = if global_ansi_state.param_count > 1 { global_ansi_state.params[1] } else { 1 };
                (*global_shell).cx = col * system_font_w;
                (*global_shell).cy = row * system_font_h;
            } else if c == 'J' as u8 {
                if global_ansi_state.params[0] == 2 {
                    comp_draw_rect((*global_shell).win, 0, 0, (*(*global_shell).win).width, (*(*global_shell).win).height, 0x000000);
                    (*global_shell).cx = 2; (*global_shell).cy = 2;
                }
            }
            
            global_ansi_state.in_escape = false;
            return true;
        }
    }
    return false;
}

struct ShmSegment {
    shm_id: u64,
    key: u32,
    size: u64,
    phys_base: u64,
    ref_count: u32,
    owner_pid: u64,
    permissions: u32,
}

let mut global_shm_table: [ShmSegment; 256];
let mut shm_next_id: u64 = 100;
let mut shm_lock: Spinlock;

fn shm_init() {
    spin_init(&shm_lock);
    for i in 0..256 {
        global_shm_table[i].shm_id = 0;
    }
}

fn shm_create(key: u32, size: u64, permissions: u32, pid: u64) -> u64 {
    spin_lock(&shm_lock);
    for i in 0..256 {
        if global_shm_table[i].key == key && global_shm_table[i].shm_id != 0 {
            spin_unlock(&shm_lock);
            return global_shm_table[i].shm_id;
        }
    }
    
    for i in 0..256 {
        if global_shm_table[i].shm_id == 0 {
            let pages = (size + PAGE_SIZE - 1) / PAGE_SIZE;
            let phys = pmm_alloc_blocks(pages);
            memset(phys as ptr<u8>, 0, pages * PAGE_SIZE);
            
            global_shm_table[i].shm_id = shm_next_id;
            shm_next_id = shm_next_id + 1;
            global_shm_table[i].key = key;
            global_shm_table[i].size = size;
            global_shm_table[i].phys_base = phys;
            global_shm_table[i].ref_count = 0;
            global_shm_table[i].owner_pid = pid;
            global_shm_table[i].permissions = permissions;
            
            spin_unlock(&shm_lock);
            return global_shm_table[i].shm_id;
        }
    }
    spin_unlock(&shm_lock);
    return 0;
}

fn shm_attach(shm_id: u64, cr3: u64, vaddr_suggest: u64) -> u64 {
    spin_lock(&shm_lock);
    for i in 0..256 {
        if global_shm_table[i].shm_id == shm_id {
            let pages = (global_shm_table[i].size + PAGE_SIZE - 1) / PAGE_SIZE;
            let mut vaddr = vaddr_suggest;
            if vaddr == 0 { vaddr = 0x5000000000; }
            
            let old_cr3 = rdmsr(0);
            asm { "mov cr3, %0" in "%0" = cr3; }
            for p in 0..pages {
                vmm_map_page(global_shm_table[i].phys_base + p * PAGE_SIZE, vaddr + p * PAGE_SIZE, 0x07);
            }
            asm { "mov cr3, %0" in "%0" = old_cr3; }
            
            global_shm_table[i].ref_count = global_shm_table[i].ref_count + 1;
            spin_unlock(&shm_lock);
            return vaddr;
        }
    }
    spin_unlock(&shm_lock);
    return 0;
}

struct ProcessStat {
    pid: u64,
    state: u8,
    time_slice: u64,
    vram_usage: u64,
    name: [u8; 32],
}

fn get_system_stats(out_stats: ptr<ProcessStat>, max_count: u32) -> u32 {
    let mut count = 0;
    let mut curr = process_queue;
    while curr != 0 as ptr<ProcessControlBlock> && count < max_count {
        let stat = (out_stats as u64 + count as u64 * sizeof(ProcessStat) as u64) as ptr<ProcessStat>;
        (*stat).pid = (*curr).pid;
        (*stat).state = (*curr).state;
        (*stat).time_slice = (*curr).time_slice;
        (*stat).vram_usage = 0;
        count = count + 1;
        curr = (*curr).next;
    }
    return count;
}

let mut loopback_mac: MacAddr;
let mut loopback_ip: Ipv4Addr;

fn loopback_init() {
    for i in 0..6 { loopback_mac.addr[i] = 0; }
    loopback_ip.addr[0] = 127;
    loopback_ip.addr[1] = 0;
    loopback_ip.addr[2] = 0;
    loopback_ip.addr[3] = 1;
}

fn loopback_send(packet: ptr<u8>, length: u32) {
    let rx_buffer = pmm_alloc_blocks((length as u64 / PAGE_SIZE) + 1) as ptr<u8>;
    memcpy(rx_buffer, packet, length as u64);
    pmm_free_blocks(rx_buffer as u64, (length as u64 / PAGE_SIZE) + 1);
}

struct AegisContainer {
    container_id: u64,
    vfs_root: ptr<VfsNode>,
    pid_offset: u64,
    network_isolated: bool,
    virtual_ip: Ipv4Addr,
    memory_limit: u64,
    current_memory: u64,
    is_active: bool,
    name: [u8; 32],
}

let mut global_containers: [AegisContainer; 64];
let mut container_count: u64 = 1;

fn container_init() {
    for i in 0..64 {
        global_containers[i].is_active = false;
    }
}

fn container_create(name: ptr<u8>, mem_limit: u64) -> ptr<AegisContainer> {
    for i in 0..64 {
        if !global_containers[i].is_active {
            global_containers[i].container_id = container_count;
            container_count = container_count + 1;
            strcpy(&(global_containers[i].name[0]) as ptr<u8>, name);
            global_containers[i].memory_limit = mem_limit;
            global_containers[i].current_memory = 0;
            global_containers[i].pid_offset = container_count * 10000;
            global_containers[i].network_isolated = true;
            
            let root_name = pmm_alloc_blocks(1) as ptr<u8>;
            strcpy(root_name, "c_root" as ptr<u8>);
            global_containers[i].vfs_root = vfs_create_node(global_vfs_root, root_name, 0x07);
            pmm_free_blocks(root_name as u64, 1);
            
            global_containers[i].is_active = true;
            return &global_containers[i];
        }
    }
    return 0 as ptr<AegisContainer>;
}

fn container_execute(container: ptr<AegisContainer>, path: ptr<u8>) -> u64 {
    let node = vfs_find_child((*container).vfs_root, path);
    if node == 0 as ptr<VfsNode> { return 0; }
    
    let pid = execve_ring3(path, 0, 0);
    if pid != 0 {
        let mut proc = process_queue;
        while proc != 0 as ptr<ProcessControlBlock> {
            if (*proc).pid == pid {
                (*proc).pid = (*container).pid_offset + pid;
                break;
            }
            proc = (*proc).next;
        }
        return (*container).pid_offset + pid;
    }
    return 0;
}

struct IntelGpuRing {
    tail: u32,
    head: u32,
    start: u32,
    ctl: u32,
}

let mut intel_mmio_base: u64 = 0;
let mut intel_ring_buf: ptr<u32>;
let mut intel_ring_tail: u32 = 0;

fn intel_gpu_read(offset: u32) -> u32 {
    let ptr = (intel_mmio_base + offset as u64) as ptr<u32>;
    return *ptr;
}

fn intel_gpu_write(offset: u32, val: u32) {
    let ptr = (intel_mmio_base + offset as u64) as ptr<u32>;
    *ptr = val;
}

fn intel_gpu_init(bar0: u64) {
    intel_mmio_base = bar0 & 0xFFFFFFFFFFFFFFF0;
    intel_ring_buf = pmm_alloc_blocks(4) as ptr<u32>;
    memset(intel_ring_buf as ptr<u8>, 0, PAGE_SIZE * 4);
    
    intel_gpu_write(0x02080, 0);
    intel_gpu_write(0x02030, 0);
    intel_gpu_write(0x02034, intel_ring_buf as u64 as u32);
    let ring_size = (PAGE_SIZE * 4) as u32;
    intel_gpu_write(0x02038, ((ring_size / 4096) - 1) | 1);
    
    intel_ring_tail = 0;
}

fn intel_gpu_submit_cmd(cmd: u32) {
    *(intel_ring_buf as u64 + intel_ring_tail as u64 * 4) as ptr<u32> = cmd;
    intel_ring_tail = (intel_ring_tail + 1) % ((PAGE_SIZE as u32 * 4) / 4);
    let aligned_tail = (intel_ring_tail * 4) & 0x1FFFF8;
    intel_gpu_write(0x02030, aligned_tail);
}

fn intel_gpu_fill_rect(x: u32, y: u32, w: u32, h: u32, color: u32) {
    let cmd_len = 6;
    intel_gpu_submit_cmd(0x50000000 | (cmd_len - 2));
    intel_gpu_submit_cmd((y << 16) | x);
    intel_gpu_submit_cmd(((y + h) << 16) | (x + w));
    intel_gpu_submit_cmd(color);
    intel_gpu_submit_cmd(0);
    intel_gpu_submit_cmd(0);
}

const PCI_CAP_ID_MSI: u8 = 0x05;
const PCI_CAP_ID_MSIX: u8 = 0x11;

struct MsixTableEntry {
    msg_addr_lo: u32,
    msg_addr_hi: u32,
    msg_data: u32,
    vector_ctrl: u32,
}

fn pcie_find_capability(base: u64, bus: u8, dev: u8, func: u8, cap_id: u8) -> u8 {
    let status = pcie_read_16(base, bus, dev, func, 0x06);
    if (status & 0x0010) == 0 { return 0; }
    
    let mut cap_ptr = pcie_read_16(base, bus, dev, func, 0x34) & 0xFC;
    while cap_ptr != 0 {
        let cap_data = pcie_read_16(base, bus, dev, func, cap_ptr);
        let id = (cap_data & 0xFF) as u8;
        let next = ((cap_data >> 8) & 0xFC) as u8;
        if id == cap_id { return cap_ptr as u8; }
        cap_ptr = next as u16;
    }
    return 0;
}

fn pcie_enable_msix(base: u64, bus: u8, dev: u8, func: u8, vector: u8, apic_id: u8) {
    let cap_offset = pcie_find_capability(base, bus, dev, func, PCI_CAP_ID_MSIX);
    if cap_offset == 0 { return; }
    
    let msg_ctrl = pcie_read_16(base, bus, dev, func, cap_offset as u16 + 2);
    let table_offset_reg = pcie_read_32(base, bus, dev, func, cap_offset as u16 + 4);
    let bir = (table_offset_reg & 0x07) as u8;
    let table_offset = table_offset_reg & 0xFFFFFFF8;
    
    let bar_reg = 0x10 + (bir * 4);
    let bar_val = pcie_read_32(base, bus, dev, func, bar_reg as u16);
    let bar_base = (bar_val & 0xFFFFFFF0) as u64;
    
    let table_ptr = (bar_base + table_offset as u64) as ptr<MsixTableEntry>;
    
    let addr_lo = 0xFEE00000 | ((apic_id as u32) << 12);
    let data = vector as u32;
    
    (*table_ptr).msg_addr_lo = addr_lo;
    (*table_ptr).msg_addr_hi = 0;
    (*table_ptr).msg_data = data;
    (*table_ptr).vector_ctrl = 0;
    
    pcie_write_32(base, bus, dev, func, cap_offset as u16 + 2, (msg_ctrl | 0x8000) as u32);
}

struct RiffHeader {
    chunk_id: u32,
    chunk_size: u32,
    format: u32,
}

struct WavFormatChunk {
    subchunk1_id: u32,
    subchunk1_size: u32,
    audio_format: u16,
    num_channels: u16,
    sample_rate: u32,
    byte_rate: u32,
    block_align: u16,
    bits_per_sample: u16,
}

struct WavDataChunk {
    subchunk2_id: u32,
    subchunk2_size: u32,
}

fn audio_play_wav(wav_data: ptr<u8>) {
    let riff = wav_data as ptr<RiffHeader>;
    if (*riff).chunk_id != 0x46464952 { return; } // 'RIFF'
    if (*riff).format != 0x45564157 { return; }   // 'WAVE'
    
    let fmt = (wav_data as u64 + sizeof(RiffHeader) as u64) as ptr<WavFormatChunk>;
    if (*fmt).subchunk1_id != 0x20746d66 { return; } // 'fmt '
    
    let data_offset = sizeof(RiffHeader) as u64 + 8 + (*fmt).subchunk1_size as u64;
    let data_chunk = (wav_data as u64 + data_offset) as ptr<WavDataChunk>;
    if (*data_chunk).subchunk2_id != 0x61746164 { return; } // 'data'
    
    let pcm_data = (wav_data as u64 + data_offset + 8) as ptr<u8>;
    let pcm_size = (*data_chunk).subchunk2_size;
    
    mixer_play_pcm(pcm_data, pcm_size / 4, (*fmt).sample_rate);
}

struct NatEntry {
    internal_ip: Ipv4Addr,
    internal_port: u16,
    external_port: u16,
    protocol: u8,
    is_active: bool,
}

let mut global_nat_table: [NatEntry; 1024];
let mut nat_next_port: u16 = 50000;

fn nat_init() {
    for i in 0..1024 {
        global_nat_table[i].is_active = false;
    }
}

fn nat_add_mapping(int_ip: Ipv4Addr, int_port: u16, proto: u8) -> u16 {
    for i in 0..1024 {
        if !global_nat_table[i].is_active {
            global_nat_table[i].internal_ip = int_ip;
            global_nat_table[i].internal_port = int_port;
            global_nat_table[i].external_port = nat_next_port;
            global_nat_table[i].protocol = proto;
            global_nat_table[i].is_active = true;
            
            let port = nat_next_port;
            nat_next_port = nat_next_port + 1;
            if nat_next_port > 65000 { nat_next_port = 50000; }
            return port;
        }
    }
    return 0;
}

fn nat_translate_outbound(packet: ptr<u8>) {
    let iph = (packet as u64 + sizeof(EthernetHeader) as u64) as ptr<Ipv4Header>;
    let proto = (*iph).protocol;
    
    if proto == 6 {
        let tcph = (packet as u64 + sizeof(EthernetHeader) as u64 + sizeof(Ipv4Header) as u64) as ptr<TcpHeader>;
        let ext_port = nat_add_mapping((*iph).src_ip, htons((*tcph).src_port), proto);
        
        for i in 0..4 { (*iph).src_ip.addr[i] = system_ip.addr[i]; }
        (*tcph).src_port = htons(ext_port);
        (*tcph).checksum = 0; 
        (*iph).checksum = 0;
    }
}

fn nat_translate_inbound(packet: ptr<u8>) -> bool {
    let iph = (packet as u64 + sizeof(EthernetHeader) as u64) as ptr<Ipv4Header>;
    let proto = (*iph).protocol;
    
    if proto == 6 {
        let tcph = (packet as u64 + sizeof(EthernetHeader) as u64 + sizeof(Ipv4Header) as u64) as ptr<TcpHeader>;
        let dest_port = htons((*tcph).dest_port);
        
        for i in 0..1024 {
            if global_nat_table[i].is_active && global_nat_table[i].external_port == dest_port && global_nat_table[i].protocol == proto {
                for j in 0..4 { (*iph).dest_ip.addr[j] = global_nat_table[i].internal_ip.addr[j]; }
                (*tcph).dest_port = htons(global_nat_table[i].internal_port);
                return true; 
            }
        }
    }
    return false;
}

struct AhciCmdFis {
    fis_type: u8,
    pmport_c: u8,
    command: u8,
    feature_l: u8,
    lba0: u8,
    lba1: u8,
    lba2: u8,
    device: u8,
    lba3: u8,
    lba4: u8,
    lba5: u8,
    feature_h: u8,
    count_l: u8,
    count_h: u8,
    icc: u8,
    control: u8,
    rsv1: [u8; 4],
}

fn ahci_find_cmd_slot(port: ptr<AHCIPortRegs>) -> i32 {
    let slots = ((*global_ahci_hba).cap >> 8) & 0x1F;
    for i in 0..=slots {
        if ((*port).ci & (1 << i)) == 0 && ((*port).sact & (1 << i)) == 0 {
            return i as i32;
        }
    }
    return -1;
}

fn ahci_read_sectors(port: ptr<AHCIPortRegs>, start_lba: u64, count: u32, buf_phys: u64) -> bool {
    (*port).is = 0xFFFFFFFF;
    let slot = ahci_find_cmd_slot(port);
    if slot == -1 { return false; }
    
    let cmd_header = ((*port).clb + (slot as u64 * sizeof(AHCICmdHeader) as u64)) as ptr<AHCICmdHeader>;
    (*cmd_header).cfl_p_r_c = (sizeof(AhciCmdFis) / 4) as u16;
    (*cmd_header).prdtl = 1;
    
    let cmd_table = (*cmd_header).ctba as ptr<AHCICmdTable>;
    memset(cmd_table as ptr<u8>, 0, sizeof(AHCICmdTable) as u64);
    
    (*cmd_table).prdt_entry[0].dba = buf_phys;
    (*cmd_table).prdt_entry[0].dbc_i = (count * 512) - 1;
    
    let fis = &(*cmd_table).cfis[0] as ptr<AhciCmdFis>;
    (*fis).fis_type = 0x27;
    (*fis).pmport_c = 0x80;
    (*fis).command = 0x25;
    
    (*fis).lba0 = (start_lba & 0xFF) as u8;
    (*fis).lba1 = ((start_lba >> 8) & 0xFF) as u8;
    (*fis).lba2 = ((start_lba >> 16) & 0xFF) as u8;
    (*fis).device = 0x40;
    
    (*fis).lba3 = ((start_lba >> 24) & 0xFF) as u8;
    (*fis).lba4 = ((start_lba >> 32) & 0xFF) as u8;
    (*fis).lba5 = ((start_lba >> 40) & 0xFF) as u8;
    
    (*fis).count_l = (count & 0xFF) as u8;
    (*fis).count_h = ((count >> 8) & 0xFF) as u8;
    
    while ((*port).tfd & (0x80 | 0x08)) != 0 { cpu_pause(); }
    (*port).ci = 1 << slot;
    
    while true {
        if ((*port).ci & (1 << slot)) == 0 { break; }
        if ((*port).is & 0x40000000) != 0 { return false; }
        cpu_pause();
    }
    return true;
}

fn ahci_write_sectors(port: ptr<AHCIPortRegs>, start_lba: u64, count: u32, buf_phys: u64) -> bool {
    (*port).is = 0xFFFFFFFF;
    let slot = ahci_find_cmd_slot(port);
    if slot == -1 { return false; }
    
    let cmd_header = ((*port).clb + (slot as u64 * sizeof(AHCICmdHeader) as u64)) as ptr<AHCICmdHeader>;
    (*cmd_header).cfl_p_r_c = ((sizeof(AhciCmdFis) / 4) as u16) | 0x0040;
    (*cmd_header).prdtl = 1;
    
    let cmd_table = (*cmd_header).ctba as ptr<AHCICmdTable>;
    memset(cmd_table as ptr<u8>, 0, sizeof(AHCICmdTable) as u64);
    
    (*cmd_table).prdt_entry[0].dba = buf_phys;
    (*cmd_table).prdt_entry[0].dbc_i = (count * 512) - 1;
    
    let fis = &(*cmd_table).cfis[0] as ptr<AhciCmdFis>;
    (*fis).fis_type = 0x27;
    (*fis).pmport_c = 0x80;
    (*fis).command = 0x35;
    
    (*fis).lba0 = (start_lba & 0xFF) as u8;
    (*fis).lba1 = ((start_lba >> 8) & 0xFF) as u8;
    (*fis).lba2 = ((start_lba >> 16) & 0xFF) as u8;
    (*fis).device = 0x40;
    
    (*fis).lba3 = ((start_lba >> 24) & 0xFF) as u8;
    (*fis).lba4 = ((start_lba >> 32) & 0xFF) as u8;
    (*fis).lba5 = ((start_lba >> 40) & 0xFF) as u8;
    
    (*fis).count_l = (count & 0xFF) as u8;
    (*fis).count_h = ((count >> 8) & 0xFF) as u8;
    
    while ((*port).tfd & (0x80 | 0x08)) != 0 { cpu_pause(); }
    (*port).ci = 1 << slot;
    
    while true {
        if ((*port).ci & (1 << slot)) == 0 { break; }
        if ((*port).is & 0x40000000) != 0 { return false; }
        cpu_pause();
    }
    return true;
}

struct SignalContext {
    pending_mask: u32,
    blocked_mask: u32,
    handlers: [u64; 32],
    trampoline_addr: u64,
    saved_ctx: CpuContext,
    is_handling: bool,
}

struct ProcessControlBlockExt {
    base: ProcessControlBlock,
    sig_ctx: ptr<SignalContext>,
}

const SIGKILL: u32 = 9;
const SIGSEGV: u32 = 11;
const SIGTERM: u32 = 15;

fn signal_init_process(proc: ptr<ProcessControlBlock>) {
    let proc_ext = proc as ptr<ProcessControlBlockExt>;
    (*proc_ext).sig_ctx = pmm_alloc_blocks(1) as ptr<SignalContext>;
    memset((*proc_ext).sig_ctx as ptr<u8>, 0, sizeof(SignalContext) as u64);
}

fn signal_send(target_pid: u64, signum: u32) -> bool {
    let mut curr = process_queue;
    while curr != 0 as ptr<ProcessControlBlock> {
        if (*curr).pid == target_pid {
            let proc_ext = curr as ptr<ProcessControlBlockExt>;
            if (*(*proc_ext).sig_ctx).is_handling { return false; }
            (*(*proc_ext).sig_ctx).pending_mask |= 1 << signum;
            if signum == SIGKILL {
                (*curr).state = 0;
            }
            return true;
        }
        curr = (*curr).next;
    }
    return false;
}

fn signal_check_pending() {
    if current_process == 0 as ptr<ProcessControlBlock> { return; }
    let proc_ext = current_process as ptr<ProcessControlBlockExt>;
    let sig_ctx = (*proc_ext).sig_ctx;
    
    if (*sig_ctx).is_handling { return; }
    
    let active_sigs = (*sig_ctx).pending_mask & !(*sig_ctx).blocked_mask;
    if active_sigs == 0 { return; }
    
    for i in 1..32 {
        if (active_sigs & (1 << i)) != 0 {
            (*sig_ctx).pending_mask &= !(1 << i);
            let handler = (*sig_ctx).handlers[i as usize];
            if handler != 0 {
                memcpy(&((*sig_ctx).saved_ctx) as ptr<u8>, (*current_process).context as ptr<u8>, sizeof(CpuContext) as u64);
                (*sig_ctx).is_handling = true;
                (*(*current_process).context).rip = handler;
                (*(*current_process).context).rdi = i as u64;
                let rsp = (*(*current_process).context).rsp;
                (*(*current_process).context).rsp = rsp - 128;
                return;
            }
        }
    }
}

fn signal_return() {
    if current_process == 0 as ptr<ProcessControlBlock> { return; }
    let proc_ext = current_process as ptr<ProcessControlBlockExt>;
    let sig_ctx = (*proc_ext).sig_ctx;
    if !(*sig_ctx).is_handling { return; }
    
    memcpy((*current_process).context as ptr<u8>, &((*sig_ctx).saved_ctx) as ptr<u8>, sizeof(CpuContext) as u64);
    (*sig_ctx).is_handling = false;
}

struct TcpCongestionExt {
    cwnd: u32,
    ssthresh: u32,
    dup_acks: u32,
    rtt: u32,
    rto: u32,
    in_fast_recovery: bool,
}

let mut global_tcp_cc: [TcpCongestionExt; 1024];

fn tcp_cc_init(sock_idx: u32) {
    global_tcp_cc[sock_idx as usize].cwnd = 1460;
    global_tcp_cc[sock_idx as usize].ssthresh = 65535;
    global_tcp_cc[sock_idx as usize].dup_acks = 0;
    global_tcp_cc[sock_idx as usize].rto = 1000;
    global_tcp_cc[sock_idx as usize].in_fast_recovery = false;
}

fn tcp_cc_ack_received(sock_idx: u32, ack_diff: u32, is_dup: bool) {
    let cc = &global_tcp_cc[sock_idx as usize];
    if is_dup {
        (*cc).dup_acks = (*cc).dup_acks + 1;
        if (*cc).dup_acks == 3 {
            (*cc).ssthresh = (*cc).cwnd / 2;
            if (*cc).ssthresh < 1460 * 2 { (*cc).ssthresh = 1460 * 2; }
            (*cc).cwnd = (*cc).ssthresh + 3 * 1460;
            (*cc).in_fast_recovery = true;
        } else if (*cc).in_fast_recovery {
            (*cc).cwnd = (*cc).cwnd + 1460;
        }
    } else {
        (*cc).dup_acks = 0;
        if (*cc).in_fast_recovery {
            (*cc).cwnd = (*cc).ssthresh;
            (*cc).in_fast_recovery = false;
        } else {
            if (*cc).cwnd < (*cc).ssthresh {
                (*cc).cwnd = (*cc).cwnd + 1460;
            } else {
                (*cc).cwnd = (*cc).cwnd + (1460 * 1460) / (*cc).cwnd;
            }
        }
    }
}

fn tcp_cc_timeout(sock_idx: u32) {
    let cc = &global_tcp_cc[sock_idx as usize];
    (*cc).ssthresh = (*cc).cwnd / 2;
    if (*cc).ssthresh < 1460 * 2 { (*cc).ssthresh = 1460 * 2; }
    (*cc).cwnd = 1460;
    (*cc).dup_acks = 0;
    (*cc).in_fast_recovery = false;
    (*cc).rto = (*cc).rto * 2;
    if (*cc).rto > 64000 { (*cc).rto = 64000; }
}

struct VirtualConsole {
    id: u32,
    buffer_phys: u64,
    cursor_x: u32,
    cursor_y: u32,
    fg_color: u32,
    bg_color: u32,
    is_active: bool,
}

let mut global_vt_list: [VirtualConsole; 6];
let mut vt_active_id: u32 = 0;
let mut vt_lock: Spinlock;

fn vt_init() {
    spin_init(&vt_lock);
    for i in 0..6 {
        global_vt_list[i].id = i as u32;
        global_vt_list[i].buffer_phys = pmm_alloc_blocks((comp_width * comp_height * 4) / PAGE_SIZE as u32 + 1);
        memset(global_vt_list[i].buffer_phys as ptr<u8>, 0, (comp_width * comp_height * 4) as u64);
        global_vt_list[i].cursor_x = 0;
        global_vt_list[i].cursor_y = 0;
        global_vt_list[i].fg_color = 0xFFFFFF;
        global_vt_list[i].bg_color = 0x000000;
        global_vt_list[i].is_active = false;
    }
    global_vt_list[0].is_active = true;
}

fn vt_switch(new_id: u32) {
    if new_id >= 6 || new_id == vt_active_id { return; }
    spin_lock(&vt_lock);
    global_vt_list[vt_active_id as usize].is_active = false;
    vt_active_id = new_id;
    global_vt_list[vt_active_id as usize].is_active = true;
    memcpy(fb_ptr as ptr<u8>, global_vt_list[vt_active_id as usize].buffer_phys as ptr<u8>, (comp_width * comp_height * 4) as u64);
    spin_unlock(&vt_lock);
}

fn vt_write_char(vt_id: u32, c: u8) {
    let vt = &global_vt_list[vt_id as usize];
    if c == 10 {
        (*vt).cursor_x = 0;
        (*vt).cursor_y = (*vt).cursor_y + system_font_h;
    } else {
        let buf = (*vt).buffer_phys as ptr<u32>;
        let glyph_offset = c as u64 * system_font_h as u64;
        let glyph = (system_font_ptr as u64 + glyph_offset) as ptr<u8>;
        
        for cy in 0..system_font_h {
            let row = *(glyph + cy as u64);
            for cx in 0..system_font_w {
                let px = (*vt).cursor_x + cx;
                let py = (*vt).cursor_y + cy;
                if px < comp_width && py < comp_height {
                    let p_idx = (py * comp_width + px) as u64;
                    if (row & (0x80 >> cx)) != 0 {
                        *(buf + p_idx) = (*vt).fg_color;
                    } else {
                        *(buf + p_idx) = (*vt).bg_color;
                    }
                }
            }
        }
        (*vt).cursor_x = (*vt).cursor_x + system_font_w;
        if (*vt).cursor_x >= comp_width {
            (*vt).cursor_x = 0;
            (*vt).cursor_y = (*vt).cursor_y + system_font_h;
        }
    }
    
    if (*vt).cursor_y >= comp_height {
        let buf = (*vt).buffer_phys as ptr<u32>;
        let row_bytes = (comp_width * system_font_h * 4) as u64;
        let total_bytes = (comp_width * comp_height * 4) as u64;
        memmove(buf as ptr<u8>, (buf as u64 + row_bytes) as ptr<u8>, total_bytes - row_bytes);
        memset((buf as u64 + total_bytes - row_bytes) as ptr<u8>, 0, row_bytes);
        (*vt).cursor_y = (*vt).cursor_y - system_font_h;
    }
    
    if (*vt).is_active {
        memcpy(fb_ptr as ptr<u8>, (*vt).buffer_phys as ptr<u8>, (comp_width * comp_height * 4) as u64);
    }
}

struct AmlNode {
    opcode: u8,
    name: [u8; 4],
    length: u32,
    data_ptr: ptr<u8>,
    parent: ptr<AmlNode>,
    child: ptr<AmlNode>,
    next: ptr<AmlNode>,
}

let mut aml_root: ptr<AmlNode>;

fn aml_parse_name(data: ptr<u8>) -> u32 {
    let mut offset: u32 = 0;
    if *data == 0x5C { offset = offset + 1; }
    if *(data as u64 + offset as u64) as ptr<u8> == 0x2E { offset = offset + 1; }
    offset = offset + 4;
    return offset;
}

fn aml_parse_pkg_length(data: ptr<u8>) -> (u32, u32) {
    let lead = *data;
    let byte_count = (lead >> 6) as u32;
    if byte_count == 0 {
        return ((lead & 0x3F) as u32, 1);
    }
    let mut length = (lead & 0x0F) as u32;
    for i in 0..byte_count {
        length |= (*(data as u64 + 1 + i as u64) as u32) << (4 + i * 8);
    }
    return (length, byte_count + 1);
}

fn aml_process_scope(parent: ptr<AmlNode>, data: ptr<u8>, limit: u32) {
    let mut offset: u32 = 0;
    while offset < limit {
        let opcode = *(data as u64 + offset as u64) as ptr<u8>;
        let mut parsed_len: u32 = 1;
        
        if opcode == 0x10 {
            let (pkg_len, pkg_bytes) = aml_parse_pkg_length((data as u64 + offset as u64 + 1) as ptr<u8>);
            let name_offset = aml_parse_name((data as u64 + offset as u64 + 1 + pkg_bytes as u64) as ptr<u8>);
            parsed_len = 1 + pkg_bytes + pkg_len;
            
            let node = pmm_alloc_blocks(1) as ptr<AmlNode>;
            memset(node as ptr<u8>, 0, sizeof(AmlNode) as u64);
            (*node).opcode = opcode;
            (*node).parent = parent;
            
            if (*parent).child == 0 as ptr<AmlNode> {
                (*parent).child = node;
            } else {
                let mut curr = (*parent).child;
                while (*curr).next != 0 as ptr<AmlNode> { curr = (*curr).next; }
                (*curr).next = node;
            }
            
            aml_process_scope(node, (data as u64 + offset as u64 + 1 + pkg_bytes as u64 + name_offset as u64) as ptr<u8>, pkg_len - name_offset);
        } else if opcode == 0x14 {
            let (pkg_len, pkg_bytes) = aml_parse_pkg_length((data as u64 + offset as u64 + 1) as ptr<u8>);
            parsed_len = 1 + pkg_bytes + pkg_len;
        } else if opcode == 0x08 {
            let name_offset = aml_parse_name((data as u64 + offset as u64 + 1) as ptr<u8>);
            parsed_len = 1 + name_offset + 1;
        } else {
            parsed_len = 1;
        }
        offset = offset + parsed_len;
    }
}

fn acpi_dsdt_init() {
    if acpi_fadt == 0 as ptr<FADTHeader> { return; }
    let dsdt_ptr = (*acpi_fadt).dsdt as u64 as ptr<ACPISDTHeader>;
    if !acpi_checksum(dsdt_ptr as ptr<u8>, (*dsdt_ptr).length) { return; }
    
    aml_root = pmm_alloc_blocks(1) as ptr<AmlNode>;
    memset(aml_root as ptr<u8>, 0, sizeof(AmlNode) as u64);
    
    let aml_data = (dsdt_ptr as u64 + sizeof(ACPISDTHeader) as u64) as ptr<u8>;
    let aml_len = (*dsdt_ptr).length - sizeof(ACPISDTHeader) as u32;
    aml_process_scope(aml_root, aml_data, aml_len);
}

const DOM_NODE_ELEMENT: u8 = 1;
const DOM_NODE_TEXT: u8 = 2;

struct HtmlAttribute {
    name: [u8; 32],
    value: [u8; 128],
    next: ptr<HtmlAttribute>,
}

struct DomNode {
    node_type: u8,
    tag_name: [u8; 32],
    text_content: ptr<u8>,
    attributes: ptr<HtmlAttribute>,
    parent: ptr<DomNode>,
    first_child: ptr<DomNode>,
    next_sibling: ptr<DomNode>,
}

let mut dom_node_pool: ptr<DomNode>;
let mut dom_pool_idx: u32 = 0;

fn html_init_parser() {
    dom_node_pool = pmm_alloc_blocks(64) as ptr<DomNode>; 
    memset(dom_node_pool as ptr<u8>, 0, PAGE_SIZE * 64);
    dom_pool_idx = 0;
}

fn html_alloc_node() -> ptr<DomNode> {
    let node = (dom_node_pool as u64 + dom_pool_idx as u64 * sizeof(DomNode) as u64) as ptr<DomNode>;
    dom_pool_idx = dom_pool_idx + 1;
    return node;
}

fn html_skip_whitespace(html: ptr<u8>, pos: ptr<u32>) {
    while *(html as u64 + *pos as u64) as ptr<u8> == ' ' as u8 ||
          *(html as u64 + *pos as u64) as ptr<u8> == 10 ||
          *(html as u64 + *pos as u64) as ptr<u8> == 9 ||
          *(html as u64 + *pos as u64) as ptr<u8> == 13 {
        *pos = *pos + 1;
    }
}

fn html_parse_tag_name(html: ptr<u8>, pos: ptr<u32>, out_name: ptr<u8>) {
    let mut i: u32 = 0;
    while *(html as u64 + *pos as u64) as ptr<u8> != '>' as u8 &&
          *(html as u64 + *pos as u64) as ptr<u8> != ' ' as u8 &&
          *(html as u64 + *pos as u64) as ptr<u8> != '/' as u8 &&
          *(html as u64 + *pos as u64) as ptr<u8> != 0 &&
          i < 31 {
        *(out_name as u64 + i as u64) as ptr<u8> = *(html as u64 + *pos as u64) as ptr<u8>;
        *pos = *pos + 1;
        i = i + 1;
    }
    *(out_name as u64 + i as u64) as ptr<u8> = 0;
}

fn html_parse_node(html: ptr<u8>, pos: ptr<u32>, parent: ptr<DomNode>) -> ptr<DomNode> {
    html_skip_whitespace(html, pos);
    if *(html as u64 + *pos as u64) as ptr<u8> == 0 { return 0 as ptr<DomNode>; }
    
    let node = html_alloc_node();
    (*node).parent = parent;
    
    if *(html as u64 + *pos as u64) as ptr<u8> == '<' as u8 {
        *pos = *pos + 1;
        if *(html as u64 + *pos as u64) as ptr<u8> == '/' as u8 {
            while *(html as u64 + *pos as u64) as ptr<u8> != '>' as u8 && *(html as u64 + *pos as u64) as ptr<u8> != 0 {
                *pos = *pos + 1;
            }
            if *(html as u64 + *pos as u64) as ptr<u8> == '>' as u8 { *pos = *pos + 1; }
            return 0 as ptr<DomNode>;
        }
        
        (*node).node_type = DOM_NODE_ELEMENT;
        html_parse_tag_name(html, pos, &((*node).tag_name[0]) as ptr<u8>);
        
        while *(html as u64 + *pos as u64) as ptr<u8> != '>' as u8 && *(html as u64 + *pos as u64) as ptr<u8> != 0 {
            *pos = *pos + 1; 
        }
        
        let mut is_self_closing = false;
        if *(html as u64 + *pos as u64 - 1) as ptr<u8> == '/' as u8 {
            is_self_closing = true;
        }
        
        if *(html as u64 + *pos as u64) as ptr<u8> == '>' as u8 { *pos = *pos + 1; }
        
        if !is_self_closing {
            let mut last_child = 0 as ptr<DomNode>;
            loop {
                let child = html_parse_node(html, pos, node);
                if child == 0 as ptr<DomNode> { break; }
                if (*node).first_child == 0 as ptr<DomNode> {
                    (*node).first_child = child;
                } else {
                    (*last_child).next_sibling = child;
                }
                last_child = child;
            }
        }
    } else {
        (*node).node_type = DOM_NODE_TEXT;
        let mut start_pos = *pos;
        let mut len: u32 = 0;
        while *(html as u64 + *pos as u64) as ptr<u8> != '<' as u8 && *(html as u64 + *pos as u64) as ptr<u8> != 0 {
            *pos = *pos + 1;
            len = len + 1;
        }
        (*node).text_content = pmm_alloc_blocks((len / PAGE_SIZE as u32) + 1) as ptr<u8>;
        memcpy((*node).text_content, (html as u64 + start_pos as u64) as ptr<u8>, len as u64);
        *((*node).text_content as u64 + len as u64) as ptr<u8> = 0;
    }
    
    return node;
}

const RAID_LEVEL_5: u32 = 5;
const RAID_STRIPE_SIZE: u64 = 65536;

struct RaidDisk {
    disk_id: u32,
    ahci_port: ptr<AHCIPortRegs>,
    is_online: bool,
    total_sectors: u64,
}

struct RaidArray {
    array_id: u32,
    level: u32,
    disks: [RaidDisk; 8],
    disk_count: u32,
    online_count: u32,
    total_capacity: u64,
    stripe_size: u64,
}

let mut global_raid_sys: RaidArray;

fn raid_init_system() {
    global_raid_sys.array_id = 1;
    global_raid_sys.level = RAID_LEVEL_5;
    global_raid_sys.disk_count = 0;
    global_raid_sys.online_count = 0;
    global_raid_sys.stripe_size = RAID_STRIPE_SIZE;
}

fn raid_add_disk(port: ptr<AHCIPortRegs>, sectors: u64) {
    if global_raid_sys.disk_count < 8 {
        let idx = global_raid_sys.disk_count;
        global_raid_sys.disks[idx as usize].disk_id = idx;
        global_raid_sys.disks[idx as usize].ahci_port = port;
        global_raid_sys.disks[idx as usize].is_online = true;
        global_raid_sys.disks[idx as usize].total_sectors = sectors;
        global_raid_sys.disk_count = global_raid_sys.disk_count + 1;
        global_raid_sys.online_count = global_raid_sys.online_count + 1;
        global_raid_sys.total_capacity = (global_raid_sys.disk_count - 1) as u64 * sectors * 512;
    }
}

fn raid_compute_parity(buffers: ptr<u64>, count: u32, parity_buf: u64, size: u64) {
    let p_ptr = parity_buf as ptr<u64>;
    for i in 0..(size / 8) {
        let mut xor_val: u64 = 0;
        for d in 0..count {
            let buf_ptr = *(buffers + d as u64) as ptr<u64>;
            xor_val = xor_val ^ *(buf_ptr as u64 + i as u64 * 8) as ptr<u64>;
        }
        *(p_ptr as u64 + i as u64 * 8) as ptr<u64> = xor_val;
    }
}

fn raid_reconstruct_data(buffers: ptr<u64>, count: u32, parity_buf: u64, missing_idx: u32, size: u64) {
    let missing_ptr = *(buffers + missing_idx as u64) as ptr<u64>;
    let p_ptr = parity_buf as ptr<u64>;
    for i in 0..(size / 8) {
        let mut xor_val: u64 = *(p_ptr as u64 + i as u64 * 8) as ptr<u64>;
        for d in 0..count {
            if d != missing_idx {
                let buf_ptr = *(buffers + d as u64) as ptr<u64>;
                xor_val = xor_val ^ *(buf_ptr as u64 + i as u64 * 8) as ptr<u64>;
            }
        }
        *(missing_ptr as u64 + i as u64 * 8) as ptr<u64> = xor_val;
    }
}

fn raid_write_stripe(stripe_lba: u64, data_buffers: ptr<u64>) {
    let disk_cnt = global_raid_sys.disk_count;
    let parity_disk = (stripe_lba / (RAID_STRIPE_SIZE / 512)) % disk_cnt as u64;
    
    let parity_buf = pmm_alloc_blocks(RAID_STRIPE_SIZE / PAGE_SIZE);
    raid_compute_parity(data_buffers, disk_cnt - 1, parity_buf, RAID_STRIPE_SIZE);
    
    let mut data_idx = 0;
    for i in 0..disk_cnt {
        let port = global_raid_sys.disks[i as usize].ahci_port;
        if i as u64 == parity_disk {
            ahci_write_sectors(port, stripe_lba, (RAID_STRIPE_SIZE / 512) as u32, parity_buf);
        } else {
            let d_buf = *(data_buffers + data_idx as u64);
            ahci_write_sectors(port, stripe_lba, (RAID_STRIPE_SIZE / 512) as u32, d_buf);
            data_idx = data_idx + 1;
        }
    }
    pmm_free_blocks(parity_buf, RAID_STRIPE_SIZE / PAGE_SIZE);
}

struct CpuRunQueue {
    core_id: u32,
    head: ptr<ProcessControlBlock>,
    tail: ptr<ProcessControlBlock>,
    load_factor: u32,
    lock: Spinlock,
}

let mut global_run_queues: [CpuRunQueue; 256];

fn smp_balancer_init() {
    for i in 0..smp_core_count {
        global_run_queues[i as usize].core_id = smp_cores[i as usize].apic_id as u32;
        global_run_queues[i as usize].head = 0 as ptr<ProcessControlBlock>;
        global_run_queues[i as usize].tail = 0 as ptr<ProcessControlBlock>;
        global_run_queues[i as usize].load_factor = 0;
        spin_init(&(global_run_queues[i as usize].lock));
    }
}

fn smp_enqueue_task(core_idx: u32, task: ptr<ProcessControlBlock>) {
    let rq = &global_run_queues[core_idx as usize];
    spin_lock(&((*rq).lock));
    (*task).next = 0 as ptr<ProcessControlBlock>;
    if (*rq).tail == 0 as ptr<ProcessControlBlock> {
        (*rq).head = task;
        (*rq).tail = task;
    } else {
        (*((*rq).tail)).next = task;
        (*rq).tail = task;
    }
    (*rq).load_factor = (*rq).load_factor + 1;
    spin_unlock(&((*rq).lock));
}

fn smp_dequeue_task(core_idx: u32) -> ptr<ProcessControlBlock> {
    let rq = &global_run_queues[core_idx as usize];
    spin_lock(&((*rq).lock));
    if (*rq).head == 0 as ptr<ProcessControlBlock> {
        spin_unlock(&((*rq).lock));
        return 0 as ptr<ProcessControlBlock>;
    }
    let task = (*rq).head;
    (*rq).head = (*task).next;
    if (*rq).head == 0 as ptr<ProcessControlBlock> {
        (*rq).tail = 0 as ptr<ProcessControlBlock>;
    }
    (*rq).load_factor = (*rq).load_factor - 1;
    spin_unlock(&((*rq).lock));
    return task;
}

fn smp_balance_load() {
    let mut max_load: u32 = 0;
    let mut min_load: u32 = 0xFFFFFFFF;
    let mut busiest_core: u32 = 0;
    let mut idlest_core: u32 = 0;
    
    for i in 0..smp_core_count {
        let load = global_run_queues[i as usize].load_factor;
        if load > max_load { max_load = load; busiest_core = i; }
        if load < min_load { min_load = load; idlest_core = i; }
    }
    
    if max_load > min_load + 2 {
        let task = smp_dequeue_task(busiest_core);
        if task != 0 as ptr<ProcessControlBlock> {
            smp_enqueue_task(idlest_core, task);
        }
    }
}

struct WaylandBuffer {
    shm_id: u64,
    width: u32,
    height: u32,
    stride: u32,
    format: u32,
}

struct WaylandSurface {
    surface_id: u32,
    owner_pid: u64,
    buffer: ptr<WaylandBuffer>,
    x: i32,
    y: i32,
    z_order: u32,
    is_mapped: bool,
    next: ptr<WaylandSurface>,
}

let mut display_srv_surfaces: ptr<WaylandSurface>;
let mut display_srv_next_id: u32 = 1000;

fn display_srv_create_surface(pid: u64) -> u32 {
    let surf = pmm_alloc_blocks(1) as ptr<WaylandSurface>;
    memset(surf as ptr<u8>, 0, sizeof(WaylandSurface) as u64);
    (*surf).surface_id = display_srv_next_id;
    display_srv_next_id = display_srv_next_id + 1;
    (*surf).owner_pid = pid;
    (*surf).is_mapped = false;
    (*surf).next = display_srv_surfaces;
    display_srv_surfaces = surf;
    return (*surf).surface_id;
}

fn display_srv_attach_buffer(surface_id: u32, shm_id: u64, w: u32, h: u32) {
    let mut curr = display_srv_surfaces;
    while curr != 0 as ptr<WaylandSurface> {
        if (*curr).surface_id == surface_id {
            let buf = pmm_alloc_blocks(1) as ptr<WaylandBuffer>;
            (*buf).shm_id = shm_id;
            (*buf).width = w;
            (*buf).height = h;
            (*buf).stride = w * 4;
            (*buf).format = 1;
            (*curr).buffer = buf;
            return;
        }
        curr = (*curr).next;
    }
}

fn display_srv_commit(surface_id: u32, x: i32, y: i32) {
    let mut curr = display_srv_surfaces;
    while curr != 0 as ptr<WaylandSurface> {
        if (*curr).surface_id == surface_id {
            (*curr).x = x;
            (*curr).y = y;
            (*curr).is_mapped = true;
            return;
        }
        curr = (*curr).next;
    }
}

fn display_srv_composite() {
    let bg_color = 0x1A1A1A;
    comp_draw_rect(comp_root_window, 0, 0, comp_width, comp_height, bg_color);
    
    let mut curr = display_srv_surfaces;
    while curr != 0 as ptr<WaylandSurface> {
        if (*curr).is_mapped && (*curr).buffer != 0 as ptr<WaylandBuffer> {
            let buf_info = (*curr).buffer;
            let mut phys_base: u64 = 0;
            for i in 0..256 {
                if global_shm_table[i].shm_id == (*buf_info).shm_id {
                    phys_base = global_shm_table[i].phys_base;
                    break;
                }
            }
            if phys_base != 0 {
                let p_pixels = phys_base as ptr<u32>;
                for h in 0..(*buf_info).height {
                    for w in 0..(*buf_info).width {
                        let sx = (*curr).x + w as i32;
                        let sy = (*curr).y + h as i32;
                        if sx >= 0 && sx < comp_width as i32 && sy >= 0 && sy < comp_height as i32 {
                            let color = *(p_pixels as u64 + (h * (*buf_info).width + w) as u64 * 4) as ptr<u32>;
                            if (*color & 0xFF000000) != 0 {
                                *(comp_back_buffer as u64 + (sy as u32 * comp_width + sx as u32) as u64 * 4) as ptr<u32> = *color;
                            }
                        }
                    }
                }
            }
        }
        curr = (*curr).next;
    }
    memcpy(fb_ptr as ptr<u8>, comp_back_buffer as ptr<u8>, (comp_width * comp_height * 4) as u64);
}

struct XhciIsochTrb {
    data_buffer_ptr: u64,
    tlc_tdpc_int_cc: u32,
    flags: u32,
}

fn xhci_queue_isoch_transfer(ring: ptr<u8>, phys_buf: u64, length: u32, frame_id: u32) {
    let trb = ring as ptr<XhciIsochTrb>;
    (*trb).data_buffer_ptr = phys_buf;
    (*trb).tlc_tdpc_int_cc = length & 0x1FFFF;
    (*trb).flags = (frame_id << 20) | (32 << 10) | 1; 
}

fn math_exp(x: f32) -> f32 {
    let mut sum: f32 = 1.0;
    let mut term: f32 = 1.0;
    for i in 1..20 {
        term = term * x / (i as f32);
        sum = sum + term;
    }
    return sum;
}

struct Tensor2D {
    rows: u32,
    cols: u32,
    data: ptr<f32>,
}

fn tensor_create(rows: u32, cols: u32) -> ptr<Tensor2D> {
    let t = pmm_alloc_blocks(1) as ptr<Tensor2D>;
    (*t).rows = rows;
    (*t).cols = cols;
    let bytes = rows * cols * 4;
    let pages = (bytes / PAGE_SIZE as u32) + 1;
    (*t).data = pmm_alloc_blocks(pages as u64) as ptr<f32>;
    memset((*t).data as ptr<u8>, 0, (pages * PAGE_SIZE as u32) as u64);
    return t;
}

fn tensor_destroy(t: ptr<Tensor2D>) {
    let bytes = (*t).rows * (*t).cols * 4;
    let pages = (bytes / PAGE_SIZE as u32) + 1;
    pmm_free_blocks((*t).data as u64, pages as u64);
    pmm_free_blocks(t as u64, 1);
}

fn tensor_matmul(a: ptr<Tensor2D>, b: ptr<Tensor2D>, out: ptr<Tensor2D>) {
    if (*a).cols != (*b).rows { return; }
    if (*out).rows != (*a).rows || (*out).cols != (*b).cols { return; }
    
    for i in 0..(*a).rows {
        for j in 0..(*b).cols {
            let mut sum: f32 = 0.0;
            for k in 0..(*a).cols {
                let val_a = *((*a).data as u64 + (i * (*a).cols + k) as u64 * 4) as ptr<f32>;
                let val_b = *((*b).data as u64 + (k * (*b).cols + j) as u64 * 4) as ptr<f32>;
                sum = sum + (*val_a * *val_b);
            }
            *((*out).data as u64 + (i * (*out).cols + j) as u64 * 4) as ptr<f32> = sum;
        }
    }
}

fn tensor_relu(t: ptr<Tensor2D>) {
    let total = (*t).rows * (*t).cols;
    for i in 0..total {
        let val_ptr = ((*t).data as u64 + i as u64 * 4) as ptr<f32>;
        if *val_ptr < 0.0 {
            *val_ptr = 0.0;
        }
    }
}

fn tensor_sigmoid(t: ptr<Tensor2D>) {
    let total = (*t).rows * (*t).cols;
    for i in 0..total {
        let val_ptr = ((*t).data as u64 + i as u64 * 4) as ptr<f32>;
        let e_x = math_exp(-(*val_ptr));
        *val_ptr = 1.0 / (1.0 + e_x);
    }
}

fn tensor_softmax(t: ptr<Tensor2D>) {
    for i in 0..(*t).rows {
        let mut max_val = *((*t).data as u64 + (i * (*t).cols) as u64 * 4) as ptr<f32>;
        for j in 1..(*t).cols {
            let v = *((*t).data as u64 + (i * (*t).cols + j) as u64 * 4) as ptr<f32>;
            if v > max_val { max_val = v; }
        }
        
        let mut sum_exp: f32 = 0.0;
        for j in 0..(*t).cols {
            let val_ptr = ((*t).data as u64 + (i * (*t).cols + j) as u64 * 4) as ptr<f32>;
            let e = math_exp(*val_ptr - max_val);
            *val_ptr = e;
            sum_exp = sum_exp + e;
        }
        
        for j in 0..(*t).cols {
            let val_ptr = ((*t).data as u64 + (i * (*t).cols + j) as u64 * 4) as ptr<f32>;
            *val_ptr = *val_ptr / sum_exp;
        }
    }
}

const FW_ACTION_ALLOW: u8 = 0;
const FW_ACTION_DROP: u8 = 1;
const FW_ACTION_REJECT: u8 = 2;

const FW_PROTO_TCP: u8 = 6;
const FW_PROTO_UDP: u8 = 17;
const FW_PROTO_ICMP: u8 = 1;

struct FirewallRule {
    src_ip: Ipv4Addr,
    src_mask: Ipv4Addr,
    dst_ip: Ipv4Addr,
    dst_mask: Ipv4Addr,
    src_port_min: u16,
    src_port_max: u16,
    dst_port_min: u16,
    dst_port_max: u16,
    protocol: u8,
    action: u8,
    is_active: bool,
    hit_count: u64,
}

struct FwConnectionState {
    src_ip: Ipv4Addr,
    dst_ip: Ipv4Addr,
    src_port: u16,
    dst_port: u16,
    protocol: u8,
    state: u8,
    last_activity: u64,
    is_active: bool,
}

let mut global_fw_rules: [FirewallRule; 512];
let mut global_fw_states: [FwConnectionState; 4096];
let mut fw_lock: Spinlock;
let mut fw_enabled: bool = true;
let mut fw_syn_cookie_secret: u32 = 0;

fn fw_init() {
    spin_init(&fw_lock);
    for i in 0..512 { global_fw_rules[i].is_active = false; }
    for i in 0..4096 { global_fw_states[i].is_active = false; }
    fw_syn_cookie_secret = rand_next() as u32;
}

fn fw_add_rule(src_ip: Ipv4Addr, src_mask: Ipv4Addr, dst_ip: Ipv4Addr, dst_mask: Ipv4Addr, p_min: u16, p_max: u16, proto: u8, action: u8) -> bool {
    spin_lock(&fw_lock);
    for i in 0..512 {
        if !global_fw_rules[i].is_active {
            global_fw_rules[i].src_ip = src_ip;
            global_fw_rules[i].src_mask = src_mask;
            global_fw_rules[i].dst_ip = dst_ip;
            global_fw_rules[i].dst_mask = dst_mask;
            global_fw_rules[i].src_port_min = 0;
            global_fw_rules[i].src_port_max = 65535;
            global_fw_rules[i].dst_port_min = p_min;
            global_fw_rules[i].dst_port_max = p_max;
            global_fw_rules[i].protocol = proto;
            global_fw_rules[i].action = action;
            global_fw_rules[i].hit_count = 0;
            global_fw_rules[i].is_active = true;
            spin_unlock(&fw_lock);
            return true;
        }
    }
    spin_unlock(&fw_lock);
    return false;
}

fn fw_match_ip(ip: Ipv4Addr, rule_ip: Ipv4Addr, mask: Ipv4Addr) -> bool {
    for i in 0..4 {
        if (ip.addr[i] & mask.addr[i]) != (rule_ip.addr[i] & mask.addr[i]) {
            return false;
        }
    }
    return true;
}

fn fw_track_connection(src_ip: Ipv4Addr, dst_ip: Ipv4Addr, src_port: u16, dst_port: u16, proto: u8, tcp_flags: u16) -> bool {
    for i in 0..4096 {
        if global_fw_states[i].is_active {
            let mut match_fwd = true;
            let mut match_rev = true;
            for j in 0..4 {
                if global_fw_states[i].src_ip.addr[j] != src_ip.addr[j] || global_fw_states[i].dst_ip.addr[j] != dst_ip.addr[j] { match_fwd = false; }
                if global_fw_states[i].src_ip.addr[j] != dst_ip.addr[j] || global_fw_states[i].dst_ip.addr[j] != src_ip.addr[j] { match_rev = false; }
            }
            if global_fw_states[i].protocol != proto { match_fwd = false; match_rev = false; }
            if global_fw_states[i].src_port != src_port || global_fw_states[i].dst_port != dst_port { match_fwd = false; }
            if global_fw_states[i].src_port != dst_port || global_fw_states[i].dst_port != src_port { match_rev = false; }
            
            if match_fwd || match_rev {
                global_fw_states[i].last_activity = current_time_tick;
                if proto == FW_PROTO_TCP && (tcp_flags & 0x01) != 0 {
                    global_fw_states[i].is_active = false; 
                }
                return true; 
            }
        }
    }
    
    if proto == FW_PROTO_TCP && (tcp_flags & 0x02) != 0 && (tcp_flags & 0x10) == 0 {
        for i in 0..4096 {
            if !global_fw_states[i].is_active {
                global_fw_states[i].src_ip = src_ip;
                global_fw_states[i].dst_ip = dst_ip;
                global_fw_states[i].src_port = src_port;
                global_fw_states[i].dst_port = dst_port;
                global_fw_states[i].protocol = proto;
                global_fw_states[i].state = 1;
                global_fw_states[i].last_activity = current_time_tick;
                global_fw_states[i].is_active = true;
                return true;
            }
        }
    }
    
    return false;
}

fn fw_inspect_packet(packet: ptr<u8>, length: u32) -> u8 {
    if !fw_enabled { return FW_ACTION_ALLOW; }
    
    let eth = packet as ptr<EthernetHeader>;
    if htons((*eth).ethertype) != 0x0800 { return FW_ACTION_ALLOW; } 
    
    let iph = (packet as u64 + sizeof(EthernetHeader) as u64) as ptr<Ipv4Header>;
    let proto = (*iph).protocol;
    let mut src_port: u16 = 0;
    let mut dst_port: u16 = 0;
    let mut tcp_flags: u16 = 0;
    
    if proto == FW_PROTO_TCP {
        let tcph = (packet as u64 + sizeof(EthernetHeader) as u64 + sizeof(Ipv4Header) as u64) as ptr<TcpHeader>;
        src_port = htons((*tcph).src_port);
        dst_port = htons((*tcph).dest_port);
        tcp_flags = htons((*tcph).data_offset_flags) & 0x01FF;
    } else if proto == FW_PROTO_UDP {
        let udph = (packet as u64 + sizeof(EthernetHeader) as u64 + sizeof(Ipv4Header) as u64) as ptr<UdpHeader>;
        src_port = htons((*udph).src_port);
        dst_port = htons((*udph).dest_port);
    }
    
    spin_lock(&fw_lock);
    let tracked = fw_track_connection((*iph).src_ip, (*iph).dest_ip, src_port, dst_port, proto, tcp_flags);
    if tracked {
        spin_unlock(&fw_lock);
        return FW_ACTION_ALLOW;
    }
    
    let mut final_action = FW_ACTION_DROP; 
    
    for i in 0..512 {
        if global_fw_rules[i].is_active {
            let mut match_rule = true;
            if global_fw_rules[i].protocol != 0 && global_fw_rules[i].protocol != proto { match_rule = false; }
            if !fw_match_ip((*iph).src_ip, global_fw_rules[i].src_ip, global_fw_rules[i].src_mask) { match_rule = false; }
            if !fw_match_ip((*iph).dest_ip, global_fw_rules[i].dst_ip, global_fw_rules[i].dst_mask) { match_rule = false; }
            if proto == FW_PROTO_TCP || proto == FW_PROTO_UDP {
                if src_port < global_fw_rules[i].src_port_min || src_port > global_fw_rules[i].src_port_max { match_rule = false; }
                if dst_port < global_fw_rules[i].dst_port_min || dst_port > global_fw_rules[i].dst_port_max { match_rule = false; }
            }
            
            if match_rule {
                global_fw_rules[i].hit_count = global_fw_rules[i].hit_count + 1;
                final_action = global_fw_rules[i].action;
                break;
            }
        }
    }
    
    spin_unlock(&fw_lock);
    return final_action;
}

struct HciCommandHeader {
    opcode: u16,
    param_length: u8,
}

struct HciAclHeader {
    handle_flags: u16,
    data_length: u16,
}

struct L2capHeader {
    length: u16,
    channel_id: u16,
}

const HCI_CMD_RESET: u16 = 0x0C03;
const HCI_CMD_READ_BD_ADDR: u16 = 0x1009;
const HCI_CMD_INQUIRY: u16 = 0x0401;
const HCI_CMD_CREATE_CONNECTION: u16 = 0x0405;

let mut bt_hci_tx_ring: ptr<u8>;
let mut bt_hci_rx_ring: ptr<u8>;

fn bt_init_controller() {
    bt_hci_tx_ring = pmm_alloc_blocks(1) as ptr<u8>;
    bt_hci_rx_ring = pmm_alloc_blocks(1) as ptr<u8>;
    memset(bt_hci_tx_ring, 0, PAGE_SIZE);
    memset(bt_hci_rx_ring, 0, PAGE_SIZE);
}

fn bt_send_hci_command(opcode: u16, params: ptr<u8>, param_len: u8) {
    let hdr = bt_hci_tx_ring as ptr<HciCommandHeader>;
    (*hdr).opcode = opcode;
    (*hdr).param_length = param_len;
    if param_len > 0 {
        let payload = (bt_hci_tx_ring as u64 + sizeof(HciCommandHeader) as u64) as ptr<u8>;
        memcpy(payload, params, param_len as u64);
    }
    let total_len = sizeof(HciCommandHeader) as u64 + param_len as u64;
    xhci_queue_isoch_transfer(0 as ptr<u8>, bt_hci_tx_ring as u64, total_len as u32, 0);
}

fn bt_send_l2cap(handle: u16, cid: u16, data: ptr<u8>, len: u16) {
    let acl_hdr = bt_hci_tx_ring as ptr<HciAclHeader>;
    (*acl_hdr).handle_flags = handle | 0x2000;
    (*acl_hdr).data_length = sizeof(L2capHeader) as u16 + len;
    
    let l2cap_hdr = (bt_hci_tx_ring as u64 + sizeof(HciAclHeader) as u64) as ptr<L2capHeader>;
    (*l2cap_hdr).length = len;
    (*l2cap_hdr).channel_id = cid;
    
    let payload = (bt_hci_tx_ring as u64 + sizeof(HciAclHeader) as u64 + sizeof(L2capHeader) as u64) as ptr<u8>;
    memcpy(payload, data, len as u64);
    
    let total_len = sizeof(HciAclHeader) as u64 + (*acl_hdr).data_length as u64;
    xhci_queue_isoch_transfer(0 as ptr<u8>, bt_hci_tx_ring as u64, total_len as u32, 0);
}

struct Jbd2Header {
    h_magic: u32,
    h_blocktype: u32,
    h_sequence: u32,
}

struct Jbd2BlockTag {
    t_blocknr: u32,
    t_flags: u16,
}

const JBD2_MAGIC_NUMBER: u32 = 0xC03B3998;
const JBD2_DESCRIPTOR_BLOCK: u32 = 1;
const JBD2_COMMIT_BLOCK: u32 = 2;
const JBD2_SUPERBLOCK_V1: u32 = 3;
const JBD2_SUPERBLOCK_V2: u32 = 4;
const JBD2_REVOKE_BLOCK: u32 = 5;

let mut jbd2_journal_start: u32 = 0;
let mut jbd2_journal_end: u32 = 0;
let mut jbd2_current_seq: u32 = 1;

fn jbd2_init(start_block: u32, end_block: u32) {
    jbd2_journal_start = start_block;
    jbd2_journal_end = end_block;
    jbd2_current_seq = 1;
}

fn jbd2_start_transaction() -> u32 {
    let seq = jbd2_current_seq;
    jbd2_current_seq = jbd2_current_seq + 1;
    return seq;
}

fn jbd2_write_descriptor(seq: u32, target_blocks: ptr<u32>, count: u32) -> u32 {
    let buf = pmm_alloc_blocks((ext2_block_size / PAGE_SIZE as u32) + 1) as ptr<u8>;
    memset(buf, 0, ext2_block_size as u64);
    
    let hdr = buf as ptr<Jbd2Header>;
    (*hdr).h_magic = htonl(JBD2_MAGIC_NUMBER);
    (*hdr).h_blocktype = htonl(JBD2_DESCRIPTOR_BLOCK);
    (*hdr).h_sequence = htonl(seq);
    
    let mut offset = sizeof(Jbd2Header) as u64;
    for i in 0..count {
        let tag = (buf as u64 + offset) as ptr<Jbd2BlockTag>;
        (*tag).t_blocknr = htonl(*(target_blocks as u64 + i as u64 * 4) as ptr<u32>);
        (*tag).t_flags = 0;
        if i == count - 1 { (*tag).t_flags = htons(8); } 
        offset = offset + sizeof(Jbd2BlockTag) as u64;
    }
    
    let lba = fat32_cluster_to_lba(jbd2_journal_start); 
    ahci_write_sectors(global_raid_sys.disks[0].ahci_port, lba as u64, (ext2_block_size / 512) as u32, buf as u64);
    pmm_free_blocks(buf as u64, (ext2_block_size / PAGE_SIZE as u32) + 1);
    return jbd2_journal_start + 1;
}

fn jbd2_commit_transaction(seq: u32, cur_journal_block: u32) {
    let buf = pmm_alloc_blocks((ext2_block_size / PAGE_SIZE as u32) + 1) as ptr<u8>;
    memset(buf, 0, ext2_block_size as u64);
    
    let hdr = buf as ptr<Jbd2Header>;
    (*hdr).h_magic = htonl(JBD2_MAGIC_NUMBER);
    (*hdr).h_blocktype = htonl(JBD2_COMMIT_BLOCK);
    (*hdr).h_sequence = htonl(seq);
    
    let lba = fat32_cluster_to_lba(cur_journal_block);
    ahci_write_sectors(global_raid_sys.disks[0].ahci_port, lba as u64, (ext2_block_size / 512) as u32, buf as u64);
    pmm_free_blocks(buf as u64, (ext2_block_size / PAGE_SIZE as u32) + 1);
}

struct UacFormatTypeI {
    length: u8,
    descriptor_type: u8,
    descriptor_subtype: u8,
    format_type: u8,
    num_channels: u8,
    subframe_size: u8,
    bit_resolution: u8,
    sample_freq_type: u8,
    sample_freq: [u8; 3],
}

fn uac_set_sample_rate(ep_addr: u8, rate: u32) {
    let mut setup_packet: [u8; 8];
    setup_packet[0] = 0x22; 
    setup_packet[1] = 0x01; 
    setup_packet[2] = 0x01; 
    setup_packet[3] = 0x01; 
    setup_packet[4] = ep_addr; 
    setup_packet[5] = 0x00;
    setup_packet[6] = 0x03; 
    setup_packet[7] = 0x00;
    
    let mut data_packet: [u8; 3];
    data_packet[0] = (rate & 0xFF) as u8;
    data_packet[1] = ((rate >> 8) & 0xFF) as u8;
    data_packet[2] = ((rate >> 16) & 0xFF) as u8;
}

fn hw_rdrand_64() -> u64 {
    let mut val: u64 = 0;
    let mut retry: u32 = 10;
    while retry > 0 {
        let mut success: u8 = 0;
        asm {
            "rdrand rax\n setc bl"
            out rax = val;
            out bl = success;
        }
        if success == 1 { return val; }
        retry = retry - 1;
    }
    return rand_next(); 
}

fn hw_rdseed_64() -> u64 {
    let mut val: u64 = 0;
    let mut retry: u32 = 10;
    while retry > 0 {
        let mut success: u8 = 0;
        asm {
            "rdseed rax\n setc bl"
            out rax = val;
            out bl = success;
        }
        if success == 1 { return val; }
        retry = retry - 1;
    }
    return hw_rdrand_64();
}

struct VmxonRegion {
    revision_id: u32,
    data: [u8; 4092],
}

struct VmcsRegion {
    revision_id: u32,
    abort_indicator: u32,
    data: [u8; 4088],
}

let mut vmx_enabled: bool = false;
let mut vmxon_region_phys: u64 = 0;

fn vmx_check_support() -> bool {
    let mut ecx: u32 = 0;
    asm {
        "mov eax, 1\n cpuid"
        out ecx = ecx;
    }
    return (ecx & (1 << 5)) != 0; 
}

fn vmx_enable() {
    let mut cr4: u64 = 0;
    asm { "mov %0, cr4" out cr4 = cr4; }
    cr4 |= (1 << 13); 
    asm { "mov cr4, %0" in "%0" = cr4; }
    
    let feature_control = rdmsr(0x3A);
    if (feature_control & 1) == 0 {
        wrmsr(0x3A, feature_control | 5); 
    }
}

fn vmx_init() {
    if !vmx_check_support() { return; }
    vmx_enable();
    
    let vmx_basic = rdmsr(0x480);
    let revision_id = (vmx_basic & 0xFFFFFFFF) as u32;
    
    vmxon_region_phys = pmm_alloc_blocks(1);
    memset(vmxon_region_phys as ptr<u8>, 0, PAGE_SIZE);
    *(vmxon_region_phys as ptr<u32>) = revision_id;
    
    let mut success: u8 = 0;
    asm {
        "vmxon [%0]\n setz al\n setc ah"
        in "%0" = &vmxon_region_phys;
        out al = success;
    }
    if success == 0 { vmx_enabled = true; }
}

fn vmx_create_vm() -> ptr<VmcsRegion> {
    if !vmx_enabled { return 0 as ptr<VmcsRegion>; }
    
    let vmx_basic = rdmsr(0x480);
    let revision_id = (vmx_basic & 0xFFFFFFFF) as u32;
    
    let vmcs_phys = pmm_alloc_blocks(1);
    memset(vmcs_phys as ptr<u8>, 0, PAGE_SIZE);
    *(vmcs_phys as ptr<u32>) = revision_id;
    
    asm {
        "vmclear [%0]"
        in "%0" = &vmcs_phys;
    }
    
    asm {
        "vmptrld [%0]"
        in "%0" = &vmcs_phys;
    }
    
    return vmcs_phys as ptr<VmcsRegion>;
}

struct WasmModule {
    magic: u32,
    version: u32,
    memory_pages: u32,
    memory_base: u64,
    code_base: ptr<u8>,
    code_size: u64,
}

const WASM_MAGIC: u32 = 0x6D736100; 

fn wasm_parse_leb128(data: ptr<u8>, offset: ptr<u64>) -> u64 {
    let mut result: u64 = 0;
    let mut shift: u64 = 0;
    loop {
        let byte = *(data as u64 + *offset) as ptr<u8>;
        *offset = *offset + 1;
        result |= ((*byte & 0x7F) as u64) << shift;
        shift = shift + 7;
        if (*byte & 0x80) == 0 { break; }
    }
    return result;
}

fn wasm_load_module(wasm_data: ptr<u8>, size: u64) -> ptr<WasmModule> {
    let magic = *(wasm_data as ptr<u32>);
    if magic != WASM_MAGIC { return 0 as ptr<WasmModule>; }
    
    let version = *((wasm_data as u64 + 4) as ptr<u32>);
    if version != 1 { return 0 as ptr<WasmModule>; }
    
    let module = pmm_alloc_blocks(1) as ptr<WasmModule>;
    memset(module as ptr<u8>, 0, sizeof(WasmModule) as u64);
    (*module).magic = magic;
    (*module).version = version;
    
    let mut offset: u64 = 8;
    while offset < size {
        let section_id = *(wasm_data as u64 + offset) as ptr<u8>;
        offset = offset + 1;
        let section_size = wasm_parse_leb128(wasm_data, &offset);
        
        if *section_id == 10 { 
            (*module).code_base = (wasm_data as u64 + offset) as ptr<u8>;
            (*module).code_size = section_size;
        } else if *section_id == 5 { 
            let _num_mems = wasm_parse_leb128(wasm_data, &offset);
            let flags = wasm_parse_leb128(wasm_data, &offset);
            let initial_pages = wasm_parse_leb128(wasm_data, &offset);
            (*module).memory_pages = initial_pages as u32;
            (*module).memory_base = pmm_alloc_blocks(initial_pages * 16); 
            memset((*module).memory_base as ptr<u8>, 0, initial_pages * 65536);
        }
        offset = offset + section_size;
    }
    return module;
}

fn wasm_execute_function(module: ptr<WasmModule>, func_offset: u64) {
    let mut pc = func_offset;
    let mut stack: [u64; 1024];
    let mut sp: u32 = 0;
    
    let code = (*module).code_base;
    loop {
        let opcode = *(code as u64 + pc) as ptr<u8>;
        pc = pc + 1;
        
        if *opcode == 0x0B { 
            break;
        } else if *opcode == 0x20 { 
            let local_idx = wasm_parse_leb128(code, &pc);
            stack[sp as usize] = 0; 
            sp = sp + 1;
        } else if *opcode == 0x41 { 
            let val = wasm_parse_leb128(code, &pc);
            stack[sp as usize] = val;
            sp = sp + 1;
        } else if *opcode == 0x6A { 
            sp = sp - 1; let b = stack[sp as usize] as i32;
            sp = sp - 1; let a = stack[sp as usize] as i32;
            stack[sp as usize] = (a + b) as u64;
            sp = sp + 1;
        } else if *opcode == 0x6B { 
            sp = sp - 1; let b = stack[sp as usize] as i32;
            sp = sp - 1; let a = stack[sp as usize] as i32;
            stack[sp as usize] = (a - b) as u64;
            sp = sp + 1;
        } else if *opcode == 0x6C { 
            sp = sp - 1; let b = stack[sp as usize] as i32;
            sp = sp - 1; let a = stack[sp as usize] as i32;
            stack[sp as usize] = (a * b) as u64;
            sp = sp + 1;
        }
    }
}

const DB_TYPE_STRING: u8 = 1;
const DB_TYPE_LIST: u8 = 2;
const DB_TYPE_INT: u8 = 3;

struct AegisDbEntry {
    key: [u8; 32],
    val_type: u8,
    val_int: u64,
    val_str: ptr<u8>,
    val_size: u64,
    next: ptr<AegisDbEntry>,
}

let mut global_db_hash_table: [ptr<AegisDbEntry>; 1024];
let mut db_lock: Spinlock;

fn db_hash_key(key: ptr<u8>) -> u32 {
    let mut hash: u32 = 5381;
    let mut i: u64 = 0;
    while *(key + i) != 0 {
        hash = ((hash << 5) + hash) + (*(key + i) as u32);
        i = i + 1;
    }
    return hash % 1024;
}

fn db_init() {
    spin_init(&db_lock);
    for i in 0..1024 {
        global_db_hash_table[i] = 0 as ptr<AegisDbEntry>;
    }
}

fn db_set_string(key: ptr<u8>, value: ptr<u8>) {
    spin_lock(&db_lock);
    let idx = db_hash_key(key);
    
    let mut curr = global_db_hash_table[idx as usize];
    while curr != 0 as ptr<AegisDbEntry> {
        if strcmp(&((*curr).key[0]) as ptr<u8>, key) == 0 {
            if (*curr).val_str != 0 as ptr<u8> {
                pmm_free_blocks((*curr).val_str as u64, ((*curr).val_size / PAGE_SIZE) + 1);
            }
            let len = strlen(value) + 1;
            (*curr).val_type = DB_TYPE_STRING;
            (*curr).val_size = len;
            (*curr).val_str = pmm_alloc_blocks((len / PAGE_SIZE) + 1) as ptr<u8>;
            strcpy((*curr).val_str, value);
            spin_unlock(&db_lock);
            return;
        }
        curr = (*curr).next;
    }
    
    let new_entry = pmm_alloc_blocks(1) as ptr<AegisDbEntry>;
    memset(new_entry as ptr<u8>, 0, sizeof(AegisDbEntry) as u64);
    strcpy(&((*new_entry).key[0]) as ptr<u8>, key);
    let len = strlen(value) + 1;
    (*new_entry).val_type = DB_TYPE_STRING;
    (*new_entry).val_size = len;
    (*new_entry).val_str = pmm_alloc_blocks((len / PAGE_SIZE) + 1) as ptr<u8>;
    strcpy((*new_entry).val_str, value);
    
    (*new_entry).next = global_db_hash_table[idx as usize];
    global_db_hash_table[idx as usize] = new_entry;
    spin_unlock(&db_lock);
}

fn db_get_string(key: ptr<u8>, out_buf: ptr<u8>) -> bool {
    spin_lock(&db_lock);
    let idx = db_hash_key(key);
    let mut curr = global_db_hash_table[idx as usize];
    while curr != 0 as ptr<AegisDbEntry> {
        if strcmp(&((*curr).key[0]) as ptr<u8>, key) == 0 && (*curr).val_type == DB_TYPE_STRING {
            strcpy(out_buf, (*curr).val_str);
            spin_unlock(&db_lock);
            return true;
        }
        curr = (*curr).next;
    }
    spin_unlock(&db_lock);
    return false;
}

const PTRACE_TRACEME: u32 = 0;
const PTRACE_PEEKTEXT: u32 = 1;
const PTRACE_POKETEXT: u32 = 4;
const PTRACE_CONT: u32 = 7;
const PTRACE_SINGLESTEP: u32 = 9;
const PTRACE_GETREGS: u32 = 12;
const PTRACE_SETREGS: u32 = 13;
const PTRACE_ATTACH: u32 = 16;
const PTRACE_DETACH: u32 = 17;

struct PtraceState {
    is_traced: bool,
    tracer_pid: u64,
    stop_signal: u32,
    saved_opcode: u8,
    breakpoint_addr: u64,
}

fn ptrace_attach(target_pid: u64, tracer_pid: u64) -> i32 {
    let mut curr = process_queue;
    while curr != 0 as ptr<ProcessControlBlock> {
        if (*curr).pid == target_pid {
            let proc_ext = curr as ptr<ProcessControlBlockExt>;
            let pstate = (proc_ext as u64 + sizeof(ProcessControlBlockExt) as u64) as ptr<PtraceState>;
            if (*pstate).is_traced { return -1; }
            (*pstate).is_traced = true;
            (*pstate).tracer_pid = tracer_pid;
            signal_send(target_pid, 19); 
            return 0;
        }
        curr = (*curr).next;
    }
    return -1;
}

fn ptrace_getregs(target_pid: u64, out_ctx: ptr<CpuContext>) -> i32 {
    let mut curr = process_queue;
    while curr != 0 as ptr<ProcessControlBlock> {
        if (*curr).pid == target_pid {
            let proc_ext = curr as ptr<ProcessControlBlockExt>;
            let pstate = (proc_ext as u64 + sizeof(ProcessControlBlockExt) as u64) as ptr<PtraceState>;
            if !(*pstate).is_traced { return -1; }
            memcpy(out_ctx as ptr<u8>, (*curr).context as ptr<u8>, sizeof(CpuContext) as u64);
            return 0;
        }
        curr = (*curr).next;
    }
    return -1;
}

fn ptrace_set_breakpoint(target_pid: u64, addr: u64) -> i32 {
    let mut curr = process_queue;
    while curr != 0 as ptr<ProcessControlBlock> {
        if (*curr).pid == target_pid {
            let proc_ext = curr as ptr<ProcessControlBlockExt>;
            let pstate = (proc_ext as u64 + sizeof(ProcessControlBlockExt) as u64) as ptr<PtraceState>;
            if !(*pstate).is_traced { return -1; }
            
            let old_cr3 = rdmsr(0);
            asm { "mov cr3, %0" in "%0" = (*curr).cr3_phys; }
            
            (*pstate).saved_opcode = *(addr as ptr<u8>);
            *(addr as ptr<u8>) = 0xCC; 
            (*pstate).breakpoint_addr = addr;
            
            asm { "mov cr3, %0" in "%0" = old_cr3; }
            return 0;
        }
        curr = (*curr).next;
    }
    return -1;
}

fn exc_breakpoint_handler_adv() {
    let proc_ext = current_process as ptr<ProcessControlBlockExt>;
    let pstate = (proc_ext as u64 + sizeof(ProcessControlBlockExt) as u64) as ptr<PtraceState>;
    
    if (*pstate).is_traced {
        (*current_process).state = 0; 
        let rip = (*(*current_process).context).rip - 1;
        
        if rip == (*pstate).breakpoint_addr {
            *(rip as ptr<u8>) = (*pstate).saved_opcode;
            (*(*current_process).context).rip = rip;
        }
        
        signal_send((*pstate).tracer_pid, 17); 
        scheduler_tick();
    }
}

const MSR_IA32_PERF_GLOBAL_CTRL: u32 = 0x38F;
const MSR_IA32_PERFEVTSEL0: u32 = 0x186;
const MSR_IA32_PERFEVTSEL1: u32 = 0x187;
const MSR_IA32_PMC0: u32 = 0xC1;
const MSR_IA32_PMC1: u32 = 0xC2;
const MSR_IA32_FIXED_CTR_CTRL: u32 = 0x38D;
const MSR_IA32_FIXED_CTR0: u32 = 0x309; 
const MSR_IA32_FIXED_CTR1: u32 = 0x30A; 
const MSR_IA32_FIXED_CTR2: u32 = 0x30B; 

struct PmuStats {
    instructions: u64,
    core_cycles: u64,
    ref_cycles: u64,
    cache_misses: u64,
    branch_misses: u64,
}

let mut global_pmu_stats: PmuStats;

fn pmu_init() {
    let mut cpuid_eax: u32 = 0;
    let mut cpuid_ebx: u32 = 0;
    let mut cpuid_ecx: u32 = 0;
    let mut cpuid_edx: u32 = 0;
    cpuid(0x0A, 0, &mut cpuid_eax, &mut cpuid_ebx, &mut cpuid_ecx, &mut cpuid_edx);
    let pmu_version = cpuid_eax & 0xFF;
    if pmu_version < 2 { return; } 

    wrmsr(MSR_IA32_PERF_GLOBAL_CTRL, 0);

    wrmsr(MSR_IA32_FIXED_CTR_CTRL, 0x333);

    let evt_cache_miss = (0x41 << 8) | 0x2E | (1 << 16) | (1 << 22); 
    wrmsr(MSR_IA32_PERFEVTSEL0, evt_cache_miss);
    
    let evt_branch_miss = (0x00 << 8) | 0xC5 | (1 << 16) | (1 << 22);
    wrmsr(MSR_IA32_PERFEVTSEL1, evt_branch_miss);

    wrmsr(MSR_IA32_PERF_GLOBAL_CTRL, (1 << 32) | (1 << 33) | (1 << 34) | 1 | 2);
}

fn pmu_read_stats() {
    global_pmu_stats.instructions = rdmsr(MSR_IA32_FIXED_CTR0);
    global_pmu_stats.core_cycles = rdmsr(MSR_IA32_FIXED_CTR1);
    global_pmu_stats.ref_cycles = rdmsr(MSR_IA32_FIXED_CTR2);
    global_pmu_stats.cache_misses = rdmsr(MSR_IA32_PMC0);
    global_pmu_stats.branch_misses = rdmsr(MSR_IA32_PMC1);
}

const EC_CMD_PORT: u16 = 0x66;
const EC_DATA_PORT: u16 = 0x62;
const EC_CMD_READ: u8 = 0x80;
const EC_CMD_WRITE: u8 = 0x81;
const EC_STAT_OBF: u8 = 0x01;
const EC_STAT_IBF: u8 = 0x02;

fn acpi_ec_wait_write() {
    let mut timeout = 100000;
    while (inb(EC_CMD_PORT) & EC_STAT_IBF) != 0 && timeout > 0 {
        cpu_pause();
        timeout = timeout - 1;
    }
}

fn acpi_ec_wait_read() {
    let mut timeout = 100000;
    while (inb(EC_CMD_PORT) & EC_STAT_OBF) == 0 && timeout > 0 {
        cpu_pause();
        timeout = timeout - 1;
    }
}

fn acpi_ec_read(addr: u8) -> u8 {
    acpi_ec_wait_write();
    outb(EC_CMD_PORT, EC_CMD_READ);
    acpi_ec_wait_write();
    outb(EC_DATA_PORT, addr);
    acpi_ec_wait_read();
    return inb(EC_DATA_PORT);
}

fn acpi_ec_write(addr: u8, data: u8) {
    acpi_ec_wait_write();
    outb(EC_CMD_PORT, EC_CMD_WRITE);
    acpi_ec_wait_write();
    outb(EC_DATA_PORT, addr);
    acpi_ec_wait_write();
    outb(EC_DATA_PORT, data);
}

struct BatteryState {
    is_present: bool,
    is_charging: bool,
    capacity_percent: u8,
    voltage_mv: u16,
    temperature_c: u8,
}

let mut global_battery_state: BatteryState;

fn acpi_update_battery_state() {
    let bat_status = acpi_ec_read(0x10); 
    global_battery_state.is_present = (bat_status & 0x01) != 0;
    global_battery_state.is_charging = (bat_status & 0x02) != 0;
    
    if global_battery_state.is_present {
        let cap_high = acpi_ec_read(0x11);
        let cap_low = acpi_ec_read(0x12);
        let max_cap = 10000; 
        let current_cap = ((cap_high as u16) << 8) | (cap_low as u16);
        global_battery_state.capacity_percent = ((current_cap as u32 * 100) / max_cap as u32) as u8;
        
        let volt_high = acpi_ec_read(0x13);
        let volt_low = acpi_ec_read(0x14);
        global_battery_state.voltage_mv = ((volt_high as u16) << 8) | (volt_low as u16);
        
        let temp_raw = acpi_ec_read(0x15);
        global_battery_state.temperature_c = temp_raw - 27; 
    }
}

struct UsbHubDescriptor {
    length: u8,
    descriptor_type: u8,
    num_ports: u8,
    hub_characteristics: u16,
    power_on_to_power_good: u8,
    hub_control_current: u8,
    device_removable: u8,
    port_power_ctrl_mask: u8,
}

struct UsbHubPort {
    port_id: u8,
    is_connected: bool,
    is_enabled: bool,
    is_superspeed: bool,
    device_address: u8,
}

struct UsbHubDevice {
    address: u8,
    num_ports: u8,
    ports: [UsbHubPort; 16],
    is_active: bool,
}

let mut global_usb_hubs: [UsbHubDevice; 8];
let mut usb_hub_count: u32 = 0;

fn usb_hub_init_device(device_addr: u8) {
    if usb_hub_count >= 8 { return; }
    
    let hub = &global_usb_hubs[usb_hub_count as usize];
    (*hub).address = device_addr;
    (*hub).is_active = true;
    
    let desc_buf = pmm_alloc_blocks(1) as ptr<UsbHubDescriptor>;
    
    let mut setup: [u8; 8];
    setup[0] = 0xA0; 
    setup[1] = 0x06; 
    setup[2] = 0x00;
    setup[3] = 0x29; 
    setup[4] = 0x00;
    setup[5] = 0x00;
    setup[6] = sizeof(UsbHubDescriptor) as u8;
    setup[7] = 0x00;
    
    (*hub).num_ports = (*desc_buf).num_ports;
    if (*hub).num_ports > 16 { (*hub).num_ports = 16; }
    
    for p in 0..(*hub).num_ports {
        (*hub).ports[p as usize].port_id = p + 1;
        (*hub).ports[p as usize].is_connected = false;
        
        setup[0] = 0x23; 
        setup[1] = 0x03; 
        setup[2] = 8;    
        setup[3] = 0;
        setup[4] = p + 1;
        setup[5] = 0;
        setup[6] = 0;
        setup[7] = 0;
    }
    
    usb_hub_count = usb_hub_count + 1;
    pmm_free_blocks(desc_buf as u64, 1);
}

fn usb_hub_poll_ports() {
    for i in 0..usb_hub_count {
        let hub = &global_usb_hubs[i as usize];
        if (*hub).is_active {
            for p in 0..(*hub).num_ports {
                
                let mut setup: [u8; 8];
                setup[0] = 0xA3; 
                setup[1] = 0x00; 
                setup[2] = 0x00;
                setup[3] = 0x00;
                setup[4] = (*hub).ports[p as usize].port_id;
                setup[5] = 0x00;
                setup[6] = 0x04;
                setup[7] = 0x00;
                
                let mut status: u32 = 0;
                
                let connected = (status & 0x0001) != 0;
                let connect_change = (status & 0x10000) != 0;
                
                if connect_change {
                    
                    setup[0] = 0x23; setup[1] = 0x01; setup[2] = 16; setup[4] = (*hub).ports[p as usize].port_id;
                    
                    if connected && !(*hub).ports[p as usize].is_connected {
                        
                        setup[0] = 0x23; setup[1] = 0x03; setup[2] = 4; setup[4] = (*hub).ports[p as usize].port_id;
                        (*hub).ports[p as usize].is_connected = true;
                    } else if !connected && (*hub).ports[p as usize].is_connected {
                        (*hub).ports[p as usize].is_connected = false;
                        (*hub).ports[p as usize].device_address = 0;
                    }
                }
            }
        }
    }
}

const SHADER_OP_NOP: u8 = 0;
const SHADER_OP_MOV: u8 = 1;
const SHADER_OP_ADD: u8 = 2;
const SHADER_OP_MUL: u8 = 3;
const SHADER_OP_DOT3: u8 = 4;
const SHADER_OP_TEX: u8 = 5;
const SHADER_OP_END: u8 = 255;

struct ShaderInstruction {
    opcode: u8,
    dest_reg: u8,
    src1_reg: u8,
    src2_reg: u8,
}

struct GpuEuProgram {
    instructions: ptr<u32>,
    inst_count: u32,
}

fn gpu_shader_compile(shader_src: ptr<ShaderInstruction>, count: u32) -> ptr<GpuEuProgram> {
    let prog = pmm_alloc_blocks(1) as ptr<GpuEuProgram>;
    let max_native_inst = count * 4; 
    (*prog).instructions = pmm_alloc_blocks((max_native_inst * 4 / PAGE_SIZE as u32) + 1) as ptr<u32>;
    (*prog).inst_count = 0;
    
    for i in 0..count {
        let inst = (shader_src as u64 + i as u64 * sizeof(ShaderInstruction) as u64) as ptr<ShaderInstruction>;
        let op = (*inst).opcode;
        let dst = (*inst).dest_reg;
        let s1 = (*inst).src1_reg;
        let s2 = (*inst).src2_reg;
        
        let out_ptr = ((*prog).instructions as u64 + (*prog).inst_count as u64 * 4) as ptr<u32>;
        
        if op == SHADER_OP_ADD {
            *out_ptr = 0x40000000 | ((dst as u32) << 16) | ((s1 as u32) << 8) | (s2 as u32);
            (*prog).inst_count = (*prog).inst_count + 1;
        } else if op == SHADER_OP_MUL {
            *out_ptr = 0x41000000 | ((dst as u32) << 16) | ((s1 as u32) << 8) | (s2 as u32);
            (*prog).inst_count = (*prog).inst_count + 1;
        } else if op == SHADER_OP_DOT3 {
            *out_ptr = 0x42000000 | ((dst as u32) << 16) | ((s1 as u32) << 8) | (s2 as u32);
            (*prog).inst_count = (*prog).inst_count + 1;
        } else if op == SHADER_OP_END {
            *out_ptr = 0xFFFFFFFF;
            (*prog).inst_count = (*prog).inst_count + 1;
            break;
        }
    }
    return prog;
}

fn gpu_shader_bind(prog: ptr<GpuEuProgram>) {
    let phys_addr = (*prog).instructions as u64;
    intel_gpu_submit_cmd(0x71000000); 
    intel_gpu_submit_cmd((phys_addr & 0xFFFFFFFF) as u32);
    intel_gpu_submit_cmd((phys_addr >> 32) as u32);
    intel_gpu_submit_cmd((*prog).inst_count * 4);
}

fn chainload_mbr(drive_num: u8, partition_lba: u64) {
    let boot_sector = 0x7C00 as ptr<u8>;
    
    ahci_read_sectors(global_raid_sys.disks[0].ahci_port, partition_lba, 1, boot_sector as u64);
    
    let signature = *(0x7DFE as ptr<u16>);
    if signature != 0xAA55 {
        shell_print_string("Chainload failed: Invalid MBR signature.\n" as ptr<u8>);
        return;
    }
    
    cpu_cli();
    
    asm {
        "mov edx, %0\n"
        "jmp 0x0000:0x7C00"
        in "%0" = drive_num as u32;
    }
}

struct Tpm2CrbControlArea {
    req: u32,
    sts: u32,
    cancel: u32,
    start: u32,
    int_ctrl: u64,
    cmd_size: u32,
    cmd_addr_low: u32,
    cmd_addr_high: u32,
    rsp_size: u32,
    rsp_addr_low: u32,
    rsp_addr_high: u32,
}

struct Tpm2CmdHeader {
    tag: u16,
    param_size: u32,
    cmd_code: u32,
}

let mut tpm2_crb_base: u64 = 0;
let mut tpm2_ctrl_area: ptr<Tpm2CrbControlArea>;
let mut tpm2_cmd_buf: ptr<u8>;
let mut tpm2_rsp_buf: ptr<u8>;

fn tpm2_init(acpi_tpm2_base: u64) {
    tpm2_crb_base = acpi_tpm2_base;
    tpm2_ctrl_area = (tpm2_crb_base + 0x40) as ptr<Tpm2CrbControlArea>;
    
    (*tpm2_ctrl_area).req = 1; 
    while ((*tpm2_ctrl_area).sts & 1) == 0 { cpu_pause(); } 
    
    tpm2_cmd_buf = ((((*tpm2_ctrl_area).cmd_addr_high as u64) << 32) | (*tpm2_ctrl_area).cmd_addr_low as u64) as ptr<u8>;
    tpm2_rsp_buf = ((((*tpm2_ctrl_area).rsp_addr_high as u64) << 32) | (*tpm2_ctrl_area).rsp_addr_low as u64) as ptr<u8>;
}

fn tpm2_send_command(cmd: ptr<u8>, size: u32) -> bool {
    memcpy(tpm2_cmd_buf, cmd, size as u64);
    (*tpm2_ctrl_area).start = 1;
    
    let mut timeout = 1000000;
    while (*tpm2_ctrl_area).start != 0 && timeout > 0 {
        cpu_pause();
        timeout = timeout - 1;
    }
    return timeout > 0;
}

fn tpm2_get_random(bytes: u16, out_buf: ptr<u8>) -> bool {
    let mut cmd: [u8; 12];
    let hdr = &cmd[0] as ptr<Tpm2CmdHeader>;
    (*hdr).tag = htons(0x8001); 
    (*hdr).param_size = htonl(12);
    (*hdr).cmd_code = htonl(0x0000017B); 
    cmd[10] = (bytes >> 8) as u8;
    cmd[11] = (bytes & 0xFF) as u8;
    
    if !tpm2_send_command(&cmd[0] as ptr<u8>, 12) { return false; }
    
    let rsp_tag = htons(*(tpm2_rsp_buf as ptr<u16>));
    let rsp_code = htonl(*((tpm2_rsp_buf as u64 + 6) as ptr<u32>));
    if rsp_code != 0 { return false; }
    
    let out_size = htons(*((tpm2_rsp_buf as u64 + 10) as ptr<u16>));
    memcpy(out_buf, (tpm2_rsp_buf as u64 + 12) as ptr<u8>, out_size as u64);
    return true;
}

fn rotl32(v: u32, c: u32) -> u32 { return (v << c) | (v >> (32 - c)); }

struct ChaCha20Ctx {
    state: [u32; 16],
}

fn chacha20_init(ctx: ptr<ChaCha20Ctx>, key: ptr<u8>, nonce: ptr<u8>, counter: u32) {
    (*ctx).state[0] = 0x61707865;
    (*ctx).state[1] = 0x3320646e;
    (*ctx).state[2] = 0x79622d32;
    (*ctx).state[3] = 0x6b206574;
    for i in 0..8 {
        (*ctx).state[4 + i] = *((key as u64 + i as u64 * 4) as ptr<u32>);
    }
    (*ctx).state[12] = counter;
    for i in 0..3 {
        (*ctx).state[13 + i] = *((nonce as u64 + i as u64 * 4) as ptr<u32>);
    }
}

fn chacha20_quarter_round(state: ptr<u32>, a: usize, b: usize, c: usize, d: usize) {
    let s = state;
    *(s.offset(a as isize)) = *(s.offset(a as isize)) + *(s.offset(b as isize)); *(s.offset(d as isize)) = rotl32(*(s.offset(d as isize)) ^ *(s.offset(a as isize)), 16);
    *(s.offset(c as isize)) = *(s.offset(c as isize)) + *(s.offset(d as isize)); *(s.offset(b as isize)) = rotl32(*(s.offset(b as isize)) ^ *(s.offset(c as isize)), 12);
    *(s.offset(a as isize)) = *(s.offset(a as isize)) + *(s.offset(b as isize)); *(s.offset(d as isize)) = rotl32(*(s.offset(d as isize)) ^ *(s.offset(a as isize)), 8);
    *(s.offset(c as isize)) = *(s.offset(c as isize)) + *(s.offset(d as isize)); *(s.offset(b as isize)) = rotl32(*(s.offset(b as isize)) ^ *(s.offset(c as isize)), 7);
}

fn chacha20_block(ctx: ptr<ChaCha20Ctx>, out: ptr<u32>) {
    let mut working_state: [u32; 16];
    for i in 0..16 { working_state[i] = (*ctx).state[i]; }
    
    for _ in 0..10 {
        chacha20_quarter_round(&working_state[0] as ptr<u32>, 0, 4, 8, 12);
        chacha20_quarter_round(&working_state[0] as ptr<u32>, 1, 5, 9, 13);
        chacha20_quarter_round(&working_state[0] as ptr<u32>, 2, 6, 10, 14);
        chacha20_quarter_round(&working_state[0] as ptr<u32>, 3, 7, 11, 15);
        chacha20_quarter_round(&working_state[0] as ptr<u32>, 0, 5, 10, 15);
        chacha20_quarter_round(&working_state[0] as ptr<u32>, 1, 6, 11, 12);
        chacha20_quarter_round(&working_state[0] as ptr<u32>, 2, 7, 8, 13);
        chacha20_quarter_round(&working_state[0] as ptr<u32>, 3, 4, 9, 14);
    }
    
    for i in 0..16 { *(out as u64 + i as u64 * 4) as ptr<u32> = (*ctx).state[i] + working_state[i]; }
    (*ctx).state[12] = (*ctx).state[12] + 1;
}

fn chacha20_encrypt(ctx: ptr<ChaCha20Ctx>, data: ptr<u8>, len: u64) {
    let mut i: u64 = 0;
    let mut block: [u32; 16];
    while i < len {
        chacha20_block(ctx, &block[0] as ptr<u32>);
        let block_u8 = &block[0] as ptr<u32> as ptr<u8>;
        let mut chunk = 64;
        if len - i < 64 { chunk = len - i; }
        for j in 0..chunk {
            *(data as u64 + i + j) = *(data as u64 + i + j) ^ *(block_u8 as u64 + j);
        }
        i = i + 64;
    }
}

struct AvSignature {
    id: u32,
    name: [u8; 32],
    pattern: [u8; 16],
    pattern_len: u64,
    is_active: bool,
}

let mut global_av_signatures: [AvSignature; 1024];
let mut av_sig_count: u32 = 0;

fn av_init() {
    for i in 0..1024 { global_av_signatures[i].is_active = false; }
}

fn av_add_signature(name: ptr<u8>, pattern: ptr<u8>, len: u64) {
    if av_sig_count >= 1024 { return; }
    let sig = &global_av_signatures[av_sig_count as usize];
    (*sig).id = av_sig_count;
    strcpy(&((*sig).name[0]) as ptr<u8>, name);
    memcpy(&((*sig).pattern[0]) as ptr<u8>, pattern, len);
    (*sig).pattern_len = len;
    (*sig).is_active = true;
    av_sig_count = av_sig_count + 1;
}

fn av_scan_memory_region(start_addr: u64, length: u64) -> ptr<AvSignature> {
    let data = start_addr as ptr<u8>;
    for i in 0..av_sig_count {
        let sig = &global_av_signatures[i as usize];
        if (*sig).is_active {
            for j in 0..(length - (*sig).pattern_len) {
                let mut is_match = true;
                for k in 0..(*sig).pattern_len {
                    if *(data as u64 + j + k) != (*sig).pattern[k as usize] {
                        is_match = false;
                        break;
                    }
                }
                if is_match { return sig; }
            }
        }
    }
    return 0 as ptr<AvSignature>;
}

fn av_monitor_process(pid: u64) {
    let mut curr = process_queue;
    while curr != 0 as ptr<ProcessControlBlock> {
        if (*curr).pid == pid {
            let proc_map = (curr as u64 + sizeof(ProcessControlBlockExt) as u64) as ptr<ProcessMemoryMap>;
            let mut vma = (*proc_map).vma_head;
            while vma != 0 as ptr<VmaNode> {
                if ((*vma).flags & 4) != 0 { 
                    let sig = av_scan_memory_region((*vma).start_vaddr, (*vma).end_vaddr - (*vma).start_vaddr);
                    if sig != 0 as ptr<AvSignature> {
                        shell_print_string("AEGIS-AV ALERT: Malicious code detected! PID: " as ptr<u8>);
                        let mut buf: [u8; 16]; itoa(pid as i32, 10, &buf[0] as ptr<u8>);
                        shell_print_string(&buf[0] as ptr<u8>);
                        shell_print_string(" Threat: " as ptr<u8>);
                        shell_print_string(&((*sig).name[0]) as ptr<u8>);
                        shell_print_char(10);
                        signal_send(pid, SIGKILL);
                        return;
                    }
                }
                vma = (*vma).next;
            }
            break;
        }
        curr = (*curr).next;
    }
}

struct CowBlock {
    logical_block: u64,
    physical_block: u64,
    ref_count: u32,
    next: ptr<CowBlock>,
}

struct CowSnapshot {
    snap_id: u32,
    timestamp: u64,
    blocks: ptr<CowBlock>,
    next: ptr<CowSnapshot>,
}

let mut global_cow_mapping: ptr<CowBlock>;
let mut global_snapshots: ptr<CowSnapshot>;
let mut cow_next_snap_id: u32 = 1;

fn cow_init() {
    global_cow_mapping = 0 as ptr<CowBlock>;
    global_snapshots = 0 as ptr<CowSnapshot>;
}

fn cow_get_physical(logical: u64) -> u64 {
    let mut curr = global_cow_mapping;
    while curr != 0 as ptr<CowBlock> {
        if (*curr).logical_block == logical { return (*curr).physical_block; }
        curr = (*curr).next;
    }
    return logical; 
}

fn cow_write_block(logical: u64, data_buf: u64) {
    let mut curr = global_cow_mapping;
    let mut target_node = 0 as ptr<CowBlock>;
    
    while curr != 0 as ptr<CowBlock> {
        if (*curr).logical_block == logical { target_node = curr; break; }
        curr = (*curr).next;
    }
    
    if target_node != 0 as ptr<CowBlock> && (*target_node).ref_count > 1 {
        (*target_node).ref_count = (*target_node).ref_count - 1;
        let new_phys = swap_alloc_slot() + 2000000; 
        
        let new_node = pmm_alloc_blocks(1) as ptr<CowBlock>;
        memset(new_node as ptr<u8>, 0, sizeof(CowBlock) as u64);
        (*new_node).logical_block = logical;
        (*new_node).physical_block = new_phys;
        (*new_node).ref_count = 1;
        (*new_node).next = global_cow_mapping;
        global_cow_mapping = new_node;
        
        ahci_write_sectors(global_raid_sys.disks[0].ahci_port, new_phys, 8, data_buf);
    } else if target_node != 0 as ptr<CowBlock> {
        ahci_write_sectors(global_raid_sys.disks[0].ahci_port, (*target_node).physical_block, 8, data_buf);
    } else {
        let new_node = pmm_alloc_blocks(1) as ptr<CowBlock>;
        memset(new_node as ptr<u8>, 0, sizeof(CowBlock) as u64);
        (*new_node).logical_block = logical;
        (*new_node).physical_block = logical; 
        (*new_node).ref_count = 1;
        (*new_node).next = global_cow_mapping;
        global_cow_mapping = new_node;
        ahci_write_sectors(global_raid_sys.disks[0].ahci_port, logical, 8, data_buf);
    }
}

fn cow_create_snapshot() -> u32 {
    let snap = pmm_alloc_blocks(1) as ptr<CowSnapshot>;
    memset(snap as ptr<u8>, 0, sizeof(CowSnapshot) as u64);
    (*snap).snap_id = cow_next_snap_id;
    cow_next_snap_id = cow_next_snap_id + 1;
    (*snap).timestamp = current_time_tick;
    
    let mut curr_block = global_cow_mapping;
    while curr_block != 0 as ptr<CowBlock> {
        (*curr_block).ref_count = (*curr_block).ref_count + 1;
        
        let copy_node = pmm_alloc_blocks(1) as ptr<CowBlock>;
        memcpy(copy_node as ptr<u8>, curr_block as ptr<u8>, sizeof(CowBlock) as u64);
        (*copy_node).next = (*snap).blocks;
        (*snap).blocks = copy_node;
        
        curr_block = (*curr_block).next;
    }
    
    (*snap).next = global_snapshots;
    global_snapshots = snap;
    return (*snap).snap_id;
}

fn cow_rollback_snapshot(snap_id: u32) -> bool {
    let mut snap = global_snapshots;
    while snap != 0 as ptr<CowSnapshot> {
        if (*snap).snap_id == snap_id {
            let mut old_mapping = global_cow_mapping;
            while old_mapping != 0 as ptr<CowBlock> {
                let next = (*old_mapping).next;
                pmm_free_blocks(old_mapping as u64, 1);
                old_mapping = next;
            }
            
            global_cow_mapping = 0 as ptr<CowBlock>;
            let mut snap_block = (*snap).blocks;
            while snap_block != 0 as ptr<CowBlock> {
                let new_node = pmm_alloc_blocks(1) as ptr<CowBlock>;
                memcpy(new_node as ptr<u8>, snap_block as ptr<u8>, sizeof(CowBlock) as u64);
                (*new_node).next = global_cow_mapping;
                global_cow_mapping = new_node;
                snap_block = (*snap_block).next;
            }
            return true;
        }
        snap = (*snap).next;
    }
    return false;
}

struct FacsHeader {
    signature: [u8; 4],
    length: u32,
    hardware_signature: u32,
    firmware_waking_vector: u32,
    global_lock: u32,
    flags: u32,
    x_firmware_waking_vector: u64,
    version: u8,
    reserved: [u8; 3],
    ospm_flags: u32,
}

fn acpi_enter_s3_sleep() {
    if acpi_fadt == 0 as ptr<FADTHeader> { return; }
    let facs = (*acpi_fadt).firmware_ctrl as u64 as ptr<FacsHeader>;
    
    (*facs).firmware_waking_vector = 0x8000; 
    
    let pm1a = (*acpi_fadt).pm1a_control_block;
    let pm1b = (*acpi_fadt).pm1b_control_block;
    
    let slp_typ_a = 5; 
    let slp_en = 1 << 13;
    
    if pm1a != 0 { outw(pm1a as u16, (slp_typ_a << 10) | slp_en); }
    if pm1b != 0 { outw(pm1b as u16, (slp_typ_a << 10) | slp_en); }
    
    cpu_cli();
    loop { cpu_hlt(); }
}

struct TlsRecordHeader {
    content_type: u8,
    version_major: u8,
    version_minor: u8,
    length: u16,
}

struct TlsHandshakeHeader {
    msg_type: u8,
    length: [u8; 3],
}

const TLS_TYPE_CHANGE_CIPHER_SPEC: u8 = 20;
const TLS_TYPE_ALERT: u8 = 21;
const TLS_TYPE_HANDSHAKE: u8 = 22;
const TLS_TYPE_APPLICATION_DATA: u8 = 23;

const TLS_HS_CLIENT_HELLO: u8 = 1;
const TLS_HS_SERVER_HELLO: u8 = 2;
const TLS_HS_CERTIFICATE: u8 = 11;
const TLS_HS_SERVER_KEY_EXCHANGE: u8 = 12;
const TLS_HS_SERVER_HELLO_DONE: u8 = 14;
const TLS_HS_CLIENT_KEY_EXCHANGE: u8 = 16;
const TLS_HS_FINISHED: u8 = 20;

struct TlsSession {
    sock: ptr<TcpSocket>,
    master_secret: [u8; 48],
    client_random: [u8; 32],
    server_random: [u8; 32],
    is_handshake_complete: bool,
    cipher_suite: u16,
    tx_sequence: u64,
    rx_sequence: u64,
}

let mut global_tls_sessions: [TlsSession; 128];
let mut tls_session_count: u32 = 0;

fn tls_init() {
    for i in 0..128 {
        global_tls_sessions[i].is_handshake_complete = false;
        global_tls_sessions[i].tx_sequence = 0;
        global_tls_sessions[i].rx_sequence = 0;
    }
}

fn tls_send_client_hello(session: ptr<TlsSession>) {
    let buf = pmm_alloc_blocks(1) as ptr<u8>;
    let rec = buf as ptr<TlsRecordHeader>;
    (*rec).content_type = TLS_TYPE_HANDSHAKE;
    (*rec).version_major = 3;
    (*rec).version_minor = 3; 
    
    let hs = (buf as u64 + sizeof(TlsRecordHeader) as u64) as ptr<TlsHandshakeHeader>;
    (*hs).msg_type = TLS_HS_CLIENT_HELLO;
    
    let hello_data = (buf as u64 + sizeof(TlsRecordHeader) as u64 + sizeof(TlsHandshakeHeader) as u64) as ptr<u8>;
    *(hello_data) = 3; *(hello_data as u64 + 1) as ptr<u8> = 3; 
    
    for i in 0..32 {
        (*session).client_random[i] = (rand_next() & 0xFF) as u8;
        *(hello_data as u64 + 2 + i as u64) as ptr<u8> = (*session).client_random[i];
    }
    
    *(hello_data as u64 + 34) as ptr<u8> = 0; 
    
    *(hello_data as u64 + 35) as ptr<u16> = htons(4); 
    *(hello_data as u64 + 37) as ptr<u16> = htons(0xC02F); 
    *(hello_data as u64 + 39) as ptr<u16> = htons(0xC02B); 
    
    *(hello_data as u64 + 41) as ptr<u8> = 1; 
    *(hello_data as u64 + 42) as ptr<u8> = 0; 
    
    let hs_len = 43;
    (*hs).length[0] = 0;
    (*hs).length[1] = (hs_len >> 8) as u8;
    (*hs).length[2] = (hs_len & 0xFF) as u8;
    
    (*rec).length = htons(sizeof(TlsHandshakeHeader) as u16 + hs_len as u16);
    
    tcp_send_data((*session).sock, buf, sizeof(TlsRecordHeader) as u32 + sizeof(TlsHandshakeHeader) as u32 + hs_len);
    pmm_free_blocks(buf as u64, 1);
}

fn tls_connect(sock: ptr<TcpSocket>) -> ptr<TlsSession> {
    if tls_session_count >= 128 { return 0 as ptr<TlsSession>; }
    let session = &global_tls_sessions[tls_session_count as usize];
    tls_session_count = tls_session_count + 1;
    
    (*session).sock = sock;
    (*session).is_handshake_complete = false;
    tls_send_client_hello(session);
    
    return session;
}

struct LivePatchHeader {
    magic: u32,
    patch_version: u32,
    num_funcs: u32,
}

struct LivePatchFunc {
    old_addr: u64,
    new_addr: u64,
    size: u32,
}

fn livepatch_apply(patch_data: ptr<u8>) -> bool {
    let hdr = patch_data as ptr<LivePatchHeader>;
    if (*hdr).magic != 0x4B4C5058 { return false; } 
    
    let funcs = (patch_data as u64 + sizeof(LivePatchHeader) as u64) as ptr<LivePatchFunc>;
    
    cpu_cli();
    
    let cr0 = rdmsr(0); 
    asm { "mov rax, cr0\n and rax, 0xFFFEFFFF\n mov cr0, rax" }
    
    for i in 0..(*hdr).num_funcs {
        let f = (funcs as u64 + i as u64 * sizeof(LivePatchFunc) as u64) as ptr<LivePatchFunc>;
        let target = (*f).old_addr as ptr<u8>;
        let dest = (*f).new_addr;
        
        *target = 0xE9; 
        let rel_offset = (dest as i64 - ((*f).old_addr as i64 + 5)) as i32;
        *((target as u64 + 1) as ptr<i32>) = rel_offset;
    }
    
    asm { "mov rax, cr0\n or rax, 0x00010000\n mov cr0, rax" }
    
    cpu_sti();
    return true;
}

fn rsod_dump_registers(ctx: ptr<CpuContext>) {
    comp_draw_rect(comp_root_window, 0, 0, comp_width, comp_height, 0xAA0000); 
    
    let mut y = 50;
    (*global_shell).win = comp_root_window;
    (*global_shell).fg_color = 0xFFFFFF;
    
    shell_print_string("====================================================\n" as ptr<u8>);
    shell_print_string("   AEGIS-X KERNEL PANIC - RED SCREEN OF DEATH       \n" as ptr<u8>);
    shell_print_string("====================================================\n" as ptr<u8>);
    shell_print_string("A critical system error has occurred. System halted.\n\n" as ptr<u8>);
    
    let mut buf: [u8; 32];
    shell_print_string("RIP: 0x" as ptr<u8>); itoa((*ctx).rip as i32, 16, &buf[0] as ptr<u8>); shell_print_string(&buf[0] as ptr<u8>); shell_print_string("\n" as ptr<u8>);
    shell_print_string("RAX: 0x" as ptr<u8>); itoa((*ctx).rax as i32, 16, &buf[0] as ptr<u8>); shell_print_string(&buf[0] as ptr<u8>); shell_print_string("  " as ptr<u8>);
    shell_print_string("RBX: 0x" as ptr<u8>); itoa((*ctx).rbx as i32, 16, &buf[0] as ptr<u8>); shell_print_string(&buf[0] as ptr<u8>); shell_print_string("\n" as ptr<u8>);
    shell_print_string("RCX: 0x" as ptr<u8>); itoa((*ctx).rcx as i32, 16, &buf[0] as ptr<u8>); shell_print_string(&buf[0] as ptr<u8>); shell_print_string("  " as ptr<u8>);
    shell_print_string("RDX: 0x" as ptr<u8>); itoa((*ctx).rdx as i32, 16, &buf[0] as ptr<u8>); shell_print_string(&buf[0] as ptr<u8>); shell_print_string("\n" as ptr<u8>);
    shell_print_string("RSI: 0x" as ptr<u8>); itoa((*ctx).rsi as i32, 16, &buf[0] as ptr<u8>); shell_print_string(&buf[0] as ptr<u8>); shell_print_string("  " as ptr<u8>);
    shell_print_string("RDI: 0x" as ptr<u8>); itoa((*ctx).rdi as i32, 16, &buf[0] as ptr<u8>); shell_print_string(&buf[0] as ptr<u8>); shell_print_string("\n" as ptr<u8>);
    shell_print_string("RSP: 0x" as ptr<u8>); itoa((*ctx).rsp as i32, 16, &buf[0] as ptr<u8>); shell_print_string(&buf[0] as ptr<u8>); shell_print_string("  " as ptr<u8>);
    shell_print_string("RBP: 0x" as ptr<u8>); itoa((*ctx).rbp as i32, 16, &buf[0] as ptr<u8>); shell_print_string(&buf[0] as ptr<u8>); shell_print_string("\n\n" as ptr<u8>);
    
    let cr2: u64; asm { "mov %0, cr2" out cr2 = cr2; }
    shell_print_string("CR2 (Fault Addr): 0x" as ptr<u8>); itoa(cr2 as i32, 16, &buf[0] as ptr<u8>); shell_print_string(&buf[0] as ptr<u8>); shell_print_string("\n" as ptr<u8>);
    
    shell_print_string("\nStack Trace:\n" as ptr<u8>);
    let mut rbp_ptr = (*ctx).rbp as ptr<u64>;
    for i in 0..8 {
        if rbp_ptr as u64 == 0 { break; }
        let ret_addr = *(rbp_ptr as u64 + 8) as ptr<u64>;
        shell_print_string("[<0x" as ptr<u8>); itoa(*ret_addr as i32, 16, &buf[0] as ptr<u8>); shell_print_string(&buf[0] as ptr<u8>); shell_print_string(">]\n" as ptr<u8>);
        rbp_ptr = *rbp_ptr as ptr<u64>;
    }
    
    shell_print_string("\nPlease restart your computer. (System Halted)" as ptr<u8>);
}

fn kernel_panic(ctx: ptr<CpuContext>) -> ! {
    cpu_cli();
    rsod_dump_registers(ctx);
    loop { cpu_hlt(); }
}

fn exc_page_fault(ctx: ptr<CpuContext>) {
    let cr2: u64; asm { "mov %0, cr2" out cr2 = cr2; }
    let err_code = (*ctx).r15; 
    
    let is_handled = false; 
    
    if !is_handled {
        kernel_panic(ctx);
    }
}

fn syscall_handler_master() {
    let mut rax: u64; let mut rdi: u64; let mut rsi: u64;
    let mut rdx: u64; let mut r10: u64; let mut r8: u64; let mut r9: u64;
    
    asm { "mov %0, rax" out rax = rax; }
    asm { "mov %0, rdi" out rdi = rdi; }
    asm { "mov %0, rsi" out rsi = rsi; }
    asm { "mov %0, rdx" out rdx = rdx; }
    asm { "mov %0, r10" out r10 = r10; }
    asm { "mov %0, r8" out r8 = r8; }
    asm { "mov %0, r9" out r9 = r9; }

    if rax == 0 { asm { "mov rax, %0" in rax = sys_read_wrap(rdi, rsi, rdx); } }
    else if rax == 1 { asm { "mov rax, %0" in rax = sys_write_wrap(rdi, rsi, rdx); } }
    else if rax == 2 { asm { "mov rax, %0" in rax = sys_open_wrap(rdi, rsi); } }
    else if rax == 3 { pmm_free_blocks(rdi, 1); asm { "mov rax, 0" } }
    else if rax == 9 { asm { "mov rax, %0" in rax = sys_mmap(rdi, rsi, rdx, r10, r8, r9); } }
    else if rax == 59 { asm { "mov rax, %0" in rax = execve_ring3(rdi as ptr<u8>, rsi as u32, rdx as u32); } }
    else if rax == 60 { (*current_process).state = 0; scheduler_tick(); }
    else if rax == 100 { comp_draw_rect(rdi as ptr<CompositorWindow>, rsi as u32, rdx as u32, r10 as u32, r8 as u32, r9 as u32); asm { "mov rax, 0" } }
    else if rax == 101 { gui_draw_string(rdi as ptr<CompositorWindow>, rsi as ptr<u8>, rdx as u32, r10 as u32, r8 as u32, r9 as u32); asm { "mov rax, 0" } }
    else if rax == 200 { sha256_init(rdi as ptr<Sha256Ctx>); sha256_transform(rdi as ptr<Sha256Ctx>, rsi as ptr<u8>); asm { "mov rax, 0" } }
    else if rax == 300 { asm { "mov rax, %0" in rax = ipc_send_message(rdi, rsi, rdx as u32, r10 as ptr<u8>, r8 as u32) as u64; } }
    else if rax == 301 { asm { "mov rax, %0" in rax = ipc_receive_message(rdi, rsi as ptr<IpcMessage>) as u64; } }
    else if rax == 400 { asm { "mov rax, %0" in rax = tcp_create_socket() as u64; } }
    else if rax == 401 { tcp_connect(rdi as ptr<TcpSocket>, *(rsi as ptr<Ipv4Addr>), rdx as u16); asm { "mov rax, 0" } }
    else if rax == 402 { tcp_send_data(rdi as ptr<TcpSocket>, rsi as ptr<u8>, rdx as u32); asm { "mov rax, 0" } }
    else if rax == 500 { asm { "mov rax, %0" in rax = shm_create(rdi as u32, rsi, rdx as u32, r10) as u64; } }
    else if rax == 501 { asm { "mov rax, %0" in rax = shm_attach(rdi, rsi, rdx) as u64; } }
    else if rax == 600 { asm { "mov rax, %0" in rax = ptrace_attach(rdi, rsi) as u64; } }
    else if rax == 700 { asm { "mov rax, %0" in rax = display_srv_create_surface(rdi) as u64; } }
    else if rax == 800 { asm { "mov rax, %0" in rax = tensor_create(rdi as u32, rsi as u32) as u64; } }
    else { asm { "mov rax, -1" } }
}

const MULTIBOOT_MAGIC: u32 = 0x2BADB002;

struct MultibootInfo {
    flags: u32,
    mem_lower: u32,
    mem_upper: u32,
    boot_device: u32,
    cmdline: u32,
    mods_count: u32,
    mods_addr: u32,
    syms: [u32; 4],
    mmap_length: u32,
    mmap_addr: u32,
    drives_length: u32,
    drives_addr: u32,
    config_table: u32,
    boot_loader_name: u32,
    apm_table: u32,
    vbe_control_info: u32,
    vbe_mode_info: u32,
    vbe_mode: u16,
    vbe_interface_seg: u16,
    vbe_interface_off: u16,
    vbe_interface_len: u16,
    framebuffer_addr: u64,
    framebuffer_pitch: u32,
    framebuffer_width: u32,
    framebuffer_height: u32,
    framebuffer_bpp: u8,
    framebuffer_type: u8,
}

#[no_mangle]
pub fn kmain(magic: u32, mb_info: ptr<MultibootInfo>) -> ! {
    cpu_cli();
    
    if magic != MULTIBOOT_MAGIC {
        loop { cpu_hlt(); }
    }
    
    init_gdt_smp();
    init_idt_smp();
    
    let total_mem_kb = (*mb_info).mem_lower + (*mb_info).mem_upper;
    pmm_init(total_mem_kb as u64);
    
    vmm_init();
    
    acpi_init();
    
    smp_init_all();
    smp_balancer_init();
    
    let w = (*mb_info).framebuffer_width;
    let h = (*mb_info).framebuffer_height;
    let fb_base = (*mb_info).framebuffer_addr;
    comp_init(fb_base, w, h);
    vt_init();
    render_init_3d(w, h);
    
    pcie_init();
    
    if global_ahci_hba != 0 as ptr<AHCIHBARegs> {
        raid_init_system();
        for i in 0..32 {
            let port = &((*global_ahci_hba).ports[i as usize]) as ptr<AHCIPortRegs>;
            if ((*port).ssts & 0x0F) == 3 {
                raid_add_disk(port, 100000000); 
            }
        }
    }
    
    vfs_init_system();
    if global_raid_sys.disk_count > 0 {
        ext2_init(0);
        jbd2_init(2000000, 2100000); 
    }
    cow_init();
    
    if (*mb_info).mods_count > 0 {
        let mod_addr = (*mb_info).mods_addr as ptr<u32>;
        let initramfs_start = *mod_addr;
        let initramfs_end = *(mod_addr as u64 + 4) as ptr<u32>;
        tar_extract_initramfs(initramfs_start as u64, (*initramfs_end - initramfs_start) as u64);
    }
    
    loopback_init();
    fw_init();
    nat_init();
    tls_init();
    
    auth_init_system();
    registry_init();
    db_init();
    av_init();
    
    pmu_init();
    acpi_update_battery_state();
    
    vmx_init();
    
    let shell_pid = execve_ring3("/bin/aegis_shell" as ptr<u8>, 0, 0);
    if shell_pid == 0 {
        let proc = create_process(shell_task as u64, true);
    }
    
    let http_proc = create_process(http_server_task as u64, true);
    
    init_set_runlevel(3);
    
    cpu_sti();
    
    loop {
        scheduler_tick();
        smp_balance_load();
        display_srv_composite();
        usb_hub_poll_ports();
        cpu_pause();
    }
}

struct YbgTransaction {
    sender_pubkey: [u8; 64],
    receiver_pubkey: [u8; 64],
    amount: u64,
    signature: [u8; 64],
    timestamp: u64,
}

struct YbgBlockHeader {
    index: u64,
    prev_hash: [u8; 32],
    merkle_root: [u8; 32],
    timestamp: u64,
    difficulty: u32,
    nonce: u64,
}

struct YbgBlock {
    header: YbgBlockHeader,
    transactions: ptr<YbgTransaction>,
    tx_count: u32,
    block_hash: [u8; 32],
    next: ptr<YbgBlock>,
}

let mut blockchain_head: ptr<YbgBlock>;
let mut current_difficulty: u32 = 4; 

fn ybg_chain_init() {
    blockchain_head = pmm_alloc_blocks(1) as ptr<YbgBlock>;
    memset(blockchain_head as ptr<u8>, 0, sizeof(YbgBlock) as u64);
    (*blockchain_head).header.index = 0;
    strcpy(&((*blockchain_head).header.prev_hash[0]) as ptr<u8>, "YBG13_GENESIS_BLOCK_00000000000" as ptr<u8>);
    (*blockchain_head).header.timestamp = current_time_tick;
    (*blockchain_head).header.difficulty = current_difficulty;
    (*blockchain_head).header.nonce = 0;
    (*blockchain_head).tx_count = 0;
}

fn ybg_check_hash_difficulty(hash: ptr<u8>, difficulty: u32) -> bool {
    let mut zero_count = 0;
    for i in 0..32 {
        let byte = *(hash as u64 + i as u64) as ptr<u8>;
        if *byte == 0 {
            zero_count = zero_count + 2;
        } else if (*byte & 0xF0) == 0 {
            zero_count = zero_count + 1;
            break;
        } else {
            break;
        }
        if zero_count >= difficulty { return true; }
    }
    return zero_count >= difficulty;
}

fn ybg_mine_block(target_block: ptr<YbgBlock>) {
    let mut attempt_hash: [u8; 32];
    let mut ctx: Sha256Ctx;
    
    shell_print_string("CHT-Miner: YBG13 Token kazimi basladi...\n" as ptr<u8>);
    
    loop {
        sha256_init(&ctx);
        sha256_transform(&ctx, &((*target_block).header) as ptr<YbgBlockHeader> as ptr<u8>);
        
        let state_ptr = &ctx.state[0] as ptr<u32> as ptr<u8>;
        for i in 0..32 { attempt_hash[i] = *(state_ptr + i); }
        
        if ybg_check_hash_difficulty(&attempt_hash[0] as ptr<u8>, (*target_block).header.difficulty) {
            for i in 0..32 { (*target_block).block_hash[i] = attempt_hash[i]; }
            shell_print_string("CHT-Miner: Blok Bulundu! Nonce: " as ptr<u8>);
            let mut buf: [u8; 32]; itoa((*target_block).header.nonce as i32, 10, &buf[0] as ptr<u8>);
            shell_print_string(&buf[0] as ptr<u8>); shell_print_string("\n" as ptr<u8>);
            break;
        }
        
        (*target_block).header.nonce = (*target_block).header.nonce + 1;
        if ((*target_block).header.nonce % 10000) == 0 { scheduler_tick(); } 
    }
}

struct ChtScanTarget {
    ip: Ipv4Addr,
    port_start: u16,
    port_end: u16,
    open_ports: [u16; 1024],
    open_count: u32,
}

fn cht_stealth_syn_scan(target: ptr<ChtScanTarget>) {
    shell_print_string("CHT-Sec: Stealth SYN Scan baslatiliyor...\n" as ptr<u8>);
    
    let sock = tcp_create_socket();
    if sock == 0 as ptr<TcpSocket> { return; }
    
    (*target).open_count = 0;
    
    for port in (*target).port_start..=(*target).port_end {
        tcp_bind(sock, 45000 + (port % 10000));
        (*sock).remote_ip = (*target).ip;
        (*sock).remote_port = port;
        (*sock).seq_num = hw_rdrand_64() as u32;
        
        tcp_send_segment(sock, 0x0002, 0 as ptr<u8>, 0); 
        
        let mut timeout = 5000;
        let mut port_open = false;
        
        while timeout > 0 {
            if (*sock).state == TCP_STATE_SYN_RCVD || (*sock).state == TCP_STATE_ESTABLISHED {
                port_open = true;
                break;
            }
            if (*sock).state == TCP_STATE_CLOSED { break; } 
            timeout = timeout - 1;
            cpu_pause();
        }
        
        if port_open {
            if (*target).open_count < 1024 {
                (*target).open_ports[(*target).open_count as usize] = port;
                (*target).open_count = (*target).open_count + 1;
                
                shell_print_string("CHT-Sec: Port Acik -> " as ptr<u8>);
                let mut pbuf: [u8; 16]; itoa(port as i32, 10, &pbuf[0] as ptr<u8>);
                shell_print_string(&pbuf[0] as ptr<u8>); shell_print_string("\n" as ptr<u8>);
            }
            tcp_send_segment(sock, 0x0004, 0 as ptr<u8>, 0); 
        }
        
        (*sock).state = TCP_STATE_CLOSED;
        (*sock).rx_head = 0; (*sock).rx_tail = 0;
    }
    
    global_tcp_sockets[(*sock).id as usize - 1].is_active = false;
    shell_print_string("CHT-Sec: Tarama Tamamlandi.\n" as ptr<u8>);
}

struct UavTelemetryPacket {
    magic: u32,
    device_id: u8,
    timestamp: u64,
    accel_x: f32,
    accel_y: f32,
    accel_z: f32,
    gyro_x: f32,
    gyro_y: f32,
    gyro_z: f32,
    depth_pressure: f32,
    motor_rpm: [u16; 4],
    battery_voltage: f32,
    checksum: u16,
}

let mut uav_last_telemetry: UavTelemetryPacket;

fn uav_parse_telemetry(udp_payload: ptr<u8>, length: u32) {
    if length != sizeof(UavTelemetryPacket) as u32 { return; }
    
    let pkt = udp_payload as ptr<UavTelemetryPacket>;
    if (*pkt).magic != 0x414E4B41 { return; } // 'ANKA'
    
    let mut csum: u32 = 0;
    let ptr16 = udp_payload as ptr<u16>;
    for i in 0..((length - 2) / 2) {
        csum = csum + *(ptr16 as u64 + i as u64 * 2) as ptr<u16> as u32;
    }
    while (csum >> 16) != 0 { csum = (csum & 0xFFFF) + (csum >> 16); }
    let calc_csum = (!csum) as u16;
    
    if calc_csum == (*pkt).checksum {
        memcpy(&uav_last_telemetry as ptr<UavTelemetryPacket> as ptr<u8>, udp_payload, length as u64);
    }
}

const TK_EOF: u8 = 0;
const TK_IDENTIFIER: u8 = 1;
const TK_NUMBER: u8 = 2;
const TK_PLUS: u8 = 3;
const TK_MINUS: u8 = 4;
const TK_ASSIGN: u8 = 5;
const TK_PRINT: u8 = 6;
const TK_SEMI: u8 = 7;

struct ScriptToken {
    type_: u8,
    value_int: i64,
    name: [u8; 32],
}

struct ScriptLexer {
    src: ptr<u8>,
    pos: u32,
    len: u32,
}

fn script_is_alpha(c: u8) -> bool { return (c >= 'a' as u8 && c <= 'z' as u8) || (c >= 'A' as u8 && c <= 'Z' as u8) || c == '_' as u8; }
fn script_is_digit(c: u8) -> bool { return c >= '0' as u8 && c <= '9' as u8; }

fn script_next_token(lex: ptr<ScriptLexer>, out_tok: ptr<ScriptToken>) {
    while (*lex).pos < (*lex).len {
        let c = *((*lex).src as u64 + (*lex).pos as u64) as ptr<u8>;
        if c == ' ' as u8 || c == 10 || c == 13 || c == 9 {
            (*lex).pos = (*lex).pos + 1;
            continue;
        }
        
        if script_is_digit(c) {
            (*out_tok).type_ = TK_NUMBER;
            (*out_tok).value_int = 0;
            while (*lex).pos < (*lex).len && script_is_digit(*((*lex).src as u64 + (*lex).pos as u64) as ptr<u8>) {
                (*out_tok).value_int = (*out_tok).value_int * 10 + (*((*lex).src as u64 + (*lex).pos as u64) as ptr<u8> - '0' as u8) as i64;
                (*lex).pos = (*lex).pos + 1;
            }
            return;
        }
        
        if script_is_alpha(c) {
            let mut i = 0;
            while (*lex).pos < (*lex).len && (script_is_alpha(*((*lex).src as u64 + (*lex).pos as u64) as ptr<u8>) || script_is_digit(*((*lex).src as u64 + (*lex).pos as u64) as ptr<u8>)) && i < 31 {
                (*out_tok).name[i] = *((*lex).src as u64 + (*lex).pos as u64) as ptr<u8>;
                (*lex).pos = (*lex).pos + 1;
                i = i + 1;
            }
            (*out_tok).name[i] = 0;
            
            if strcmp(&((*out_tok).name[0]) as ptr<u8>, "print" as ptr<u8>) == 0 {
                (*out_tok).type_ = TK_PRINT;
            } else {
                (*out_tok).type_ = TK_IDENTIFIER;
            }
            return;
        }
        
        if c == '+' as u8 { (*out_tok).type_ = TK_PLUS; (*lex).pos = (*lex).pos + 1; return; }
        if c == '-' as u8 { (*out_tok).type_ = TK_MINUS; (*lex).pos = (*lex).pos + 1; return; }
        if c == '=' as u8 { (*out_tok).type_ = TK_ASSIGN; (*lex).pos = (*lex).pos + 1; return; }
        if c == ';' as u8 { (*out_tok).type_ = TK_SEMI; (*lex).pos = (*lex).pos + 1; return; }
        
        (*lex).pos = (*lex).pos + 1;
    }
    (*out_tok).type_ = TK_EOF;
}

struct ScriptVar {
    name: [u8; 32],
    value: i64,
    is_active: bool,
}

let mut global_script_env: [ScriptVar; 64];

fn script_set_var(name: ptr<u8>, val: i64) {
    for i in 0..64 {
        if global_script_env[i].is_active && strcmp(&(global_script_env[i].name[0]) as ptr<u8>, name) == 0 {
            global_script_env[i].value = val;
            return;
        }
    }
    for i in 0..64 {
        if !global_script_env[i].is_active {
            strcpy(&(global_script_env[i].name[0]) as ptr<u8>, name);
            global_script_env[i].value = val;
            global_script_env[i].is_active = true;
            return;
        }
    }
}

fn script_get_var(name: ptr<u8>) -> i64 {
    for i in 0..64 {
        if global_script_env[i].is_active && strcmp(&(global_script_env[i].name[0]) as ptr<u8>, name) == 0 {
            return global_script_env[i].value;
        }
    }
    return 0;
}

fn aegis_script_run(source_code: ptr<u8>) {
    let mut lex: ScriptLexer;
    lex.src = source_code;
    lex.pos = 0;
    lex.len = strlen(source_code) as u32;
    
    for i in 0..64 { global_script_env[i].is_active = false; }
    
    let mut tok: ScriptToken;
    script_next_token(&mut lex, &mut tok);
    
    while tok.type_ != TK_EOF {
        if tok.type_ == TK_IDENTIFIER {
            let var_name = tok.name;
            script_next_token(&mut lex, &mut tok);
            if tok.type_ == TK_ASSIGN {
                script_next_token(&mut lex, &mut tok);
                let mut val: i64 = 0;
                if tok.type_ == TK_NUMBER { val = tok.value_int; }
                else if tok.type_ == TK_IDENTIFIER { val = script_get_var(&tok.name[0] as ptr<u8>); }
                script_set_var(&var_name[0] as ptr<u8>, val);
                script_next_token(&mut lex, &mut tok); 
            }
        } else if tok.type_ == TK_PRINT {
            script_next_token(&mut lex, &mut tok);
            let mut val: i64 = 0;
            if tok.type_ == TK_NUMBER { val = tok.value_int; }
            else if tok.type_ == TK_IDENTIFIER { val = script_get_var(&tok.name[0] as ptr<u8>); }
            
            shell_print_string("Aegis-Script Out: " as ptr<u8>);
            let mut buf: [u8; 32]; itoa(val as i32, 10, &buf[0] as ptr<u8>);
            shell_print_string(&buf[0] as ptr<u8>); shell_print_string("\n" as ptr<u8>);
            script_next_token(&mut lex, &mut tok); 
        } else {
            script_next_token(&mut lex, &mut tok);
        }
    }
}

const MB_MAGIC: u32 = 0x1BADB002;
const MB_FLAGS: u32 = 0x00000003;
const MB_CKSUM: u32 = -(MB_MAGIC + MB_FLAGS);
struct Multiboot { magic: u32, flags: u32, checksum: u32 }
const HEADER: Multiboot = Multiboot { magic: MB_MAGIC, flags: MB_FLAGS, checksum: MB_CKSUM };

fn outb(p: u16, d: u8) { asm { "out dx, al" in dx = p; in al = d; } }
fn outw(p: u16, d: u16) { asm { "out dx, ax" in dx = p; in ax = d; } }
fn outl(p: u16, d: u32) { asm { "out dx, eax" in dx = p; in eax = d; } }
fn inb(p: u16) -> u8 { let mut d: u8; asm { "in al, dx" in dx = p; out al = d; } return d; }
fn inw(p: u16) -> u16 { let mut d: u16; asm { "in ax, dx" in dx = p; out ax = d; } return d; }
fn inl(p: u16) -> u32 { let mut d: u32; asm { "in eax, dx" in dx = p; out eax = d; } return d; }

struct CpuContext {
    r15: u64, r14: u64, r13: u64, r12: u64,
    r11: u64, r10: u64, r9: u64, r8: u64,
    rbp: u64, rdi: u64, rsi: u64, rdx: u64,
    rcx: u64, rbx: u64, rax: u64,
    rip: u64, cs: u64, rflags: u64, rsp: u64, ss: u64,
}

struct ProcessControlBlock {
    pid: u64,
    state: u8,
    cr3_phys: u64,
    context: ptr<CpuContext>,
    time_slice: u64,
    privilege_level: u8,
    next: ptr<ProcessControlBlock>,
}

let mut current_process: ptr<ProcessControlBlock> = 0 as ptr<ProcessControlBlock>;
let mut process_queue: ptr<ProcessControlBlock> = 0 as ptr<ProcessControlBlock>;

fn sched() {
    if current_process == 0 as ptr<ProcessControlBlock> { return; }
    let mut next_proc = (*current_process).next;
    if next_proc == 0 as ptr<ProcessControlBlock> {
        next_proc = process_queue;
    }
    while (*next_proc).state != 1 {
        next_proc = (*next_proc).next;
        if next_proc == 0 as ptr<ProcessControlBlock> { next_proc = process_queue; }
    }
    current_process = next_proc;
}

struct AegisCap {
    uid: u32,
    net_access: bool,
    fs_access: bool,
    hw_access: bool,
}

fn aegis_verify(proc: ptr<ProcessControlBlock>, req_cap: u8) -> bool {
    if (*proc).privilege_level == 0 { return true; } 
    return false; 
}

fn syscall_handler() {
    let mut eax: u32; let mut ebx: u32; let mut ecx: u32; let mut edx: u32;
    asm { "mov %0, eax" out eax = eax; }
    asm { "mov %0, ebx" out ebx = ebx; }
    asm { "mov %0, ecx" out ecx = ecx; }
    asm { "mov %0, edx" out edx = edx; }
    
    if eax == 1 { asm { "mov eax, %0" in eax = kmalloc(ebx) as u32; } }
    else if eax == 2 { kfree(ebx as ptr<u8>); asm { "mov eax, 0" } }
    else if eax == 3 { wm_crt(ebx, ecx); asm { "mov eax, 0" } }
    else if eax == 4 { tcp_syn(0, ebx as u16, ecx as u16); asm { "mov eax, 0" } }
    else if eax == 5 { crypto_init(); asm { "mov eax, 0" } }
    else { asm { "mov eax, -1" } }
}

fn idle_t() { loop { cpu_hlt(); sched(); } }
fn gui_t() { loop { wm_cmp(); sched(); } }
fn net_t() { loop { arp_req(0); sched(); } }

#[no_mangle]
pub fn _start() -> ! {
    cpu_cli();
    init_gdt_smp();
    init_idt_smp();
    pmm_init();
    vmm_init();
    init_apic_smp();
    
    crypto_init();
    vfs_init();
    
    create_process(idle_t as u64, 0);
    create_process(gui_t as u64, 0);
    create_process(net_t as u64, 0);
    
    cpu_sti();
    loop {
        sched();
        cpu_pause();
    }
}
const DRIVER_TYPE_NETWORK: u8 = 1;
const DRIVER_TYPE_STORAGE: u8 = 2;
const DRIVER_TYPE_DISPLAY: u8 = 3;
const DRIVER_TYPE_AUDIO: u8   = 4;
const DRIVER_TYPE_INPUT: u8   = 5;
const DRIVER_TYPE_USB_HC: u8  = 6;

struct DeviceDriver {
    name: [u8; 32],
    drv_type: u8,
    init_func: u64,
    read_func: u64,
    write_func: u64,
    irq_handler: u64,
    is_loaded: bool,
}

let mut global_driver_registry: [DeviceDriver; 1024];
let mut registered_driver_count: u32 = 0;

fn register_driver(name: ptr<u8>, d_type: u8, init: u64, read: u64, write: u64, irq: u64) {
    if registered_driver_count >= 1024 { return; }
    let drv = &global_driver_registry[registered_driver_count as usize];
    strcpy(&(drv.name[0]) as ptr<u8>, name);
    drv.drv_type = d_type;
    drv.init_func = init;
    drv.read_func = read;
    drv.write_func = write;
    drv.irq_handler = irq;
    drv.is_loaded = false;
    registered_driver_count = registered_driver_count + 1;
}


fn drv_e1000_init() -> bool { shell_print_string("Loading Intel PRO/1000...\n" as ptr<u8>); return true; }
fn drv_e1000e_init() -> bool { shell_print_string("Loading Intel PCIe Gigabit...\n" as ptr<u8>); return true; }
fn drv_ixgbe_init() -> bool { shell_print_string("Loading Intel 10GbE...\n" as ptr<u8>); return true; }
fn drv_rtl8139_init() -> bool { shell_print_string("Loading Realtek 8139...\n" as ptr<u8>); return true; }
fn drv_rtl8168_init() -> bool { shell_print_string("Loading Realtek 8168/8111...\n" as ptr<u8>); return true; }
fn drv_virtio_net_init() -> bool { shell_print_string("Loading VirtIO Network...\n" as ptr<u8>); return true; }
fn drv_broadcom_net_init() -> bool { shell_print_string("Loading Broadcom NetXtreme...\n" as ptr<u8>); return true; }
fn drv_atheros_wifi_init() -> bool { shell_print_string("Loading Atheros 802.11...\n" as ptr<u8>); return true; }
fn drv_intel_wifi_init() -> bool { shell_print_string("Loading Intel Wireless WiFi...\n" as ptr<u8>); return true; }

fn drv_ahci_init() -> bool { shell_print_string("Loading AHCI SATA Controller...\n" as ptr<u8>); return true; }
fn drv_nvme_init() -> bool { shell_print_string("Loading NVMe Controller...\n" as ptr<u8>); return true; }
fn drv_ide_init() -> bool { shell_print_string("Loading Legacy IDE Controller...\n" as ptr<u8>); return true; }
fn drv_virtio_blk_init() -> bool { shell_print_string("Loading VirtIO Block...\n" as ptr<u8>); return true; }
fn drv_sdhci_init() -> bool { shell_print_string("Loading SD Host Controller...\n" as ptr<u8>); return true; }
fn drv_lsi_sas_init() -> bool { shell_print_string("Loading LSI SAS Controller...\n" as ptr<u8>); return true; }


fn drv_xhci_init() -> bool { shell_print_string("Loading USB 3.0 xHCI...\n" as ptr<u8>); return true; }
fn drv_ehci_init() -> bool { shell_print_string("Loading USB 2.0 EHCI...\n" as ptr<u8>); return true; }
fn drv_uhci_init() -> bool { shell_print_string("Loading USB 1.1 UHCI...\n" as ptr<u8>); return true; }
fn drv_ohci_init() -> bool { shell_print_string("Loading USB 1.0 OHCI...\n" as ptr<u8>); return true; }


fn drv_intel_gma_init() -> bool { shell_print_string("Loading Intel GMA/HD Graphics...\n" as ptr<u8>); return true; }
fn drv_amd_radeon_init() -> bool { shell_print_string("Loading AMD Radeon Graphics...\n" as ptr<u8>); return true; }
fn drv_nvidia_nouveau_init() -> bool { shell_print_string("Loading Nvidia (Nouveau) Graphics...\n" as ptr<u8>); return true; }
fn drv_virtio_gpu_init() -> bool { shell_print_string("Loading VirtIO GPU...\n" as ptr<u8>); return true; }
fn drv_vbox_video_init() -> bool { shell_print_string("Loading VirtualBox Video...\n" as ptr<u8>); return true; }
fn drv_vmware_svga_init() -> bool { shell_print_string("Loading VMware SVGA II...\n" as ptr<u8>); return true; }
fn drv_bochs_vbe_init() -> bool { shell_print_string("Loading Bochs VBE Display...\n" as ptr<u8>); return true; }
fn drv_intel_hda_init() -> bool { shell_print_string("Loading Intel High Definition Audio...\n" as ptr<u8>); return true; }
fn drv_ac97_init() -> bool { shell_print_string("Loading AC97 Audio...\n" as ptr<u8>); return true; }
fn drv_sb16_init() -> bool { shell_print_string("Loading Sound Blaster 16...\n" as ptr<u8>); return true; }
fn drv_ps2_kbd_init() -> bool { shell_print_string("Loading PS/2 Keyboard...\n" as ptr<u8>); return true; }
fn drv_ps2_mouse_init() -> bool { shell_print_string("Loading PS/2 Mouse...\n" as ptr<u8>); return true; }
fn drv_usb_hid_init() -> bool { shell_print_string("Loading USB HID (Kbd/Mouse)...\n" as ptr<u8>); return true; }
fn drv_i2c_hid_init() -> bool { shell_print_string("Loading I2C HID Touchpad...\n" as ptr<u8>); return true; }
fn uda_register_all_drivers() {
    register_driver("e1000" as ptr<u8>, DRIVER_TYPE_NETWORK, drv_e1000_init as u64, 0, 0, 0);
    register_driver("e1000e" as ptr<u8>, DRIVER_TYPE_NETWORK, drv_e1000e_init as u64, 0, 0, 0);
    register_driver("ixgbe" as ptr<u8>, DRIVER_TYPE_NETWORK, drv_ixgbe_init as u64, 0, 0, 0);
    register_driver("rtl8139" as ptr<u8>, DRIVER_TYPE_NETWORK, drv_rtl8139_init as u64, 0, 0, 0);
    register_driver("rtl8168" as ptr<u8>, DRIVER_TYPE_NETWORK, drv_rtl8168_init as u64, 0, 0, 0);
    register_driver("virtio-net" as ptr<u8>, DRIVER_TYPE_NETWORK, drv_virtio_net_init as u64, 0, 0, 0);
    register_driver("bcm-net" as ptr<u8>, DRIVER_TYPE_NETWORK, drv_broadcom_net_init as u64, 0, 0, 0);
    register_driver("ath-wifi" as ptr<u8>, DRIVER_TYPE_NETWORK, drv_atheros_wifi_init as u64, 0, 0, 0);
    register_driver("iwlwifi" as ptr<u8>, DRIVER_TYPE_NETWORK, drv_intel_wifi_init as u64, 0, 0, 0);
    
    register_driver("ahci" as ptr<u8>, DRIVER_TYPE_STORAGE, drv_ahci_init as u64, 0, 0, 0);
    register_driver("nvme" as ptr<u8>, DRIVER_TYPE_STORAGE, drv_nvme_init as u64, 0, 0, 0);
    register_driver("ide" as ptr<u8>, DRIVER_TYPE_STORAGE, drv_ide_init as u64, 0, 0, 0);
    register_driver("virtio-blk" as ptr<u8>, DRIVER_TYPE_STORAGE, drv_virtio_blk_init as u64, 0, 0, 0);
    register_driver("sdhci" as ptr<u8>, DRIVER_TYPE_STORAGE, drv_sdhci_init as u64, 0, 0, 0);
    register_driver("lsi-sas" as ptr<u8>, DRIVER_TYPE_STORAGE, drv_lsi_sas_init as u64, 0, 0, 0);
    
    register_driver("xhci" as ptr<u8>, DRIVER_TYPE_USB_HC, drv_xhci_init as u64, 0, 0, 0);
    register_driver("ehci" as ptr<u8>, DRIVER_TYPE_USB_HC, drv_ehci_init as u64, 0, 0, 0);
    register_driver("uhci" as ptr<u8>, DRIVER_TYPE_USB_HC, drv_uhci_init as u64, 0, 0, 0);
    register_driver("ohci" as ptr<u8>, DRIVER_TYPE_USB_HC, drv_ohci_init as u64, 0, 0, 0);
    
    register_driver("intel-gma" as ptr<u8>, DRIVER_TYPE_DISPLAY, drv_intel_gma_init as u64, 0, 0, 0);
    register_driver("amd-radeon" as ptr<u8>, DRIVER_TYPE_DISPLAY, drv_amd_radeon_init as u64, 0, 0, 0);
    register_driver("nvidia" as ptr<u8>, DRIVER_TYPE_DISPLAY, drv_nvidia_nouveau_init as u64, 0, 0, 0);
    register_driver("virtio-gpu" as ptr<u8>, DRIVER_TYPE_DISPLAY, drv_virtio_gpu_init as u64, 0, 0, 0);
    register_driver("vbox-video" as ptr<u8>, DRIVER_TYPE_DISPLAY, drv_vbox_video_init as u64, 0, 0, 0);
    register_driver("vmware-svga" as ptr<u8>, DRIVER_TYPE_DISPLAY, drv_vmware_svga_init as u64, 0, 0, 0);
    register_driver("bochs-vbe" as ptr<u8>, DRIVER_TYPE_DISPLAY, drv_bochs_vbe_init as u64, 0, 0, 0);
    
    register_driver("intel-hda" as ptr<u8>, DRIVER_TYPE_AUDIO, drv_intel_hda_init as u64, 0, 0, 0);
    register_driver("ac97" as ptr<u8>, DRIVER_TYPE_AUDIO, drv_ac97_init as u64, 0, 0, 0);
    register_driver("sb16" as ptr<u8>, DRIVER_TYPE_AUDIO, drv_sb16_init as u64, 0, 0, 0);
    
    register_driver("ps2-kbd" as ptr<u8>, DRIVER_TYPE_INPUT, drv_ps2_kbd_init as u64, 0, 0, 0);
    register_driver("ps2-mouse" as ptr<u8>, DRIVER_TYPE_INPUT, drv_ps2_mouse_init as u64, 0, 0, 0);
    register_driver("usb-hid" as ptr<u8>, DRIVER_TYPE_INPUT, drv_usb_hid_init as u64, 0, 0, 0);
    register_driver("i2c-hid" as ptr<u8>, DRIVER_TYPE_INPUT, drv_i2c_hid_init as u64, 0, 0, 0);
}


fn get_pci_vendor_name(vendor_id: u16) -> ptr<u8> {
    if vendor_id == 0x8086 { return "Intel Corporation" as ptr<u8>; }
    if vendor_id == 0x1002 { return "Advanced Micro Devices (AMD)" as ptr<u8>; }
    if vendor_id == 0x10DE { return "NVIDIA Corporation" as ptr<u8>; }
    if vendor_id == 0x10EC { return "Realtek Semiconductor Co., Ltd." as ptr<u8>; }
    if vendor_id == 0x14E4 { return "Broadcom Inc. and subsidiaries" as ptr<u8>; }
    if vendor_id == 0x1AF4 { return "Red Hat, Inc. (Virtio)" as ptr<u8>; }
    if vendor_id == 0x15AD { return "VMware" as ptr<u8>; }
    if vendor_id == 0x80EE { return "InnoTek Systemberatung GmbH (VirtualBox)" as ptr<u8>; }
    if vendor_id == 0x1022 { return "AMD (Legacy)" as ptr<u8>; }
    if vendor_id == 0x104C { return "Texas Instruments" as ptr<u8>; }
    if vendor_id == 0x11AB { return "Marvell Technology Group Ltd." as ptr<u8>; }
    if vendor_id == 0x197B { return "JMicron Technology Corp." as ptr<u8>; }
    if vendor_id == 0x1014 { return "IBM" as ptr<u8>; }
    if vendor_id == 0x0E11 { return "Compaq Computer Corporation" as ptr<u8>; }
    if vendor_id == 0x103C { return "Hewlett-Packard Company" as ptr<u8>; }
    if vendor_id == 0x1028 { return "Dell" as ptr<u8>; }
    if vendor_id == 0x1043 { return "ASUSTeK Computer Inc." as ptr<u8>; }
    if vendor_id == 0x1458 { return "Gigabyte Technology Co., Ltd" as ptr<u8>; }
    if vendor_id == 0x1462 { return "Micro-Star International Co., Ltd. [MSI]" as ptr<u8>; }
    if vendor_id == 0x15B3 { return "Mellanox Technologies" as ptr<u8>; }
    if vendor_id == 0x1B36 { return "Red Hat, Inc. (QEMU)" as ptr<u8>; }
    if vendor_id == 0x1C58 { return "HGST, Inc." as ptr<u8>; }
    if vendor_id == 0x144D { return "Samsung Electronics Co Ltd" as ptr<u8>; }
    if vendor_id == 0x152D { return "JMicron Technology Corp. (NVMe)" as ptr<u8>; }
    if vendor_id == 0x1D0F { return "Amazon.com, Inc." as ptr<u8>; }
    if vendor_id == 0x1AE0 { return "Google, Inc." as ptr<u8>; }
    if vendor_id == 0x106B { return "Apple Inc." as ptr<u8>; }
    if vendor_id == 0x105A { return "Promise Technology, Inc." as ptr<u8>; }
    if vendor_id == 0x10B5 { return "PLX Technology, Inc." as ptr<u8>; }
    if vendor_id == 0x10DF { return "Emulex Corporation" as ptr<u8>; }
    if vendor_id == 0x1106 { return "VIA Technologies, Inc." as ptr<u8>; }
    if vendor_id == 0x1179 { return "Toshiba Corporation" as ptr<u8>; }
    if vendor_id == 0x1186 { return "D-Link System Inc" as ptr<u8>; }
    if vendor_id == 0x13F0 { return "Sundance Technology Inc / IC Plus Corp" as ptr<u8>; }
    if vendor_id == 0x168C { return "Qualcomm Atheros" as ptr<u8>; }
    if vendor_id == 0x1814 { return "Ralink corp." as ptr<u8>; }
    if vendor_id == 0x1B21 { return "ASMedia Technology Inc." as ptr<u8>; }
    if vendor_id == 0x8087 { return "Intel Corporation (Wireless)" as ptr<u8>; }
    return "Unknown Vendor" as ptr<u8>;
}

fn get_pci_device_name(vendor_id: u16, device_id: u16) -> ptr<u8> {
    // --- INTEL DEVICES ---
    if vendor_id == 0x8086 {
        if device_id == 0x100E { return "Gigabit Ethernet Controller (e1000)" as ptr<u8>; }
        if device_id == 0x100F { return "Gigabit Ethernet Controller (e1000)" as ptr<u8>; }
        if device_id == 0x10D3 { return "82574L Gigabit Network Connection" as ptr<u8>; }
        if device_id == 0x10EA { return "82577LM Gigabit Network Connection" as ptr<u8>; }
        if device_id == 0x1502 { return "82579LM Gigabit Network Connection" as ptr<u8>; }
        if device_id == 0x1503 { return "82579V Gigabit Network Connection" as ptr<u8>; }
        if device_id == 0x153A { return "I217-LM Gigabit Network Connection" as ptr<u8>; }
        if device_id == 0x153B { return "I217-V Gigabit Network Connection" as ptr<u8>; }
        if device_id == 0x15B7 { return "I219-LM Gigabit Network Connection" as ptr<u8>; }
        if device_id == 0x15B8 { return "I219-V Gigabit Network Connection" as ptr<u8>; }
        if device_id == 0x10FB { return "82599ES 10-Gigabit SFI/SFP+ Network Connection" as ptr<u8>; }
        if device_id == 0x1528 { return "Ethernet Controller 10-Gigabit X540-AT2" as ptr<u8>; }
        if device_id == 0x2922 { return "82801IR/IO/P (ICH9) 6 port SATA Controller [AHCI mode]" as ptr<u8>; }
        if device_id == 0x1C02 { return "6 Series/C200 Series Chipset Family 6 port SATA AHCI" as ptr<u8>; }
        if device_id == 0x1E02 { return "7 Series/C210 Series Chipset Family 6-port SATA Controller" as ptr<u8>; }
        if device_id == 0x8C02 { return "8 Series/C220 Series Chipset Family 6-port SATA Controller" as ptr<u8>; }
        if device_id == 0xA102 { return "100 Series/C230 Series Chipset Family SATA AHCI" as ptr<u8>; }
        if device_id == 0xA282 { return "200 Series/Z370 Chipset Family SATA AHCI Controller" as ptr<u8>; }
        if device_id == 0x0116 { return "3rd Gen Core processor Graphics Controller" as ptr<u8>; }
        if device_id == 0x0166 { return "3rd Gen Core processor Graphics Controller" as ptr<u8>; }
        if device_id == 0x0412 { return "4th Gen Core Processor Integrated Graphics Controller" as ptr<u8>; }
        if device_id == 0x1912 { return "HD Graphics 530" as ptr<u8>; }
        if device_id == 0x3E92 { return "UHD Graphics 630 (Desktop)" as ptr<u8>; }
        if device_id == 0x9BC5 { return "CometLake-S GT2 [UHD Graphics 630]" as ptr<u8>; }
        if device_id == 0x2668 { return "82801FB/FBM/FR/FW/FRW (ICH6 Family) High Definition Audio" as ptr<u8>; }
        if device_id == 0x284B { return "82801H (ICH8 Family) High Definition Audio Controller" as ptr<u8>; }
        if device_id == 0x293E { return "82801I (ICH9 Family) High Definition Audio Controller" as ptr<u8>; }
        if device_id == 0x1E20 { return "7 Series/C210 Series Chipset Family High Definition Audio" as ptr<u8>; }
        if device_id == 0xA170 { return "100 Series/C230 Series Chipset Family HD Audio Controller" as ptr<u8>; }
        if device_id == 0x8C31 { return "8 Series/C220 Series Chipset Family USB xHCI" as ptr<u8>; }
        if device_id == 0xA12F { return "100 Series/C230 Series Chipset Family USB 3.0 xHCI" as ptr<u8>; }
        if device_id == 0x1E2D { return "7 Series/C210 Series Chipset Family USB Enhanced Host Controller" as ptr<u8>; }
        if device_id == 0x24C2 { return "82801DB/DBM (ICH4/ICH4-M) USB UHCI Controller" as ptr<u8>; }
        if device_id == 0xF1A5 { return "NVMe SSD Controller (Optane/760p)" as ptr<u8>; }
        if device_id == 0x4220 { return "PRO/Wireless 2200BG [Calexico2] Network Connection" as ptr<u8>; }
        if device_id == 0x4229 { return "PRO/Wireless 4965 AG or AGN [Kedron] Network Connection" as ptr<u8>; }
        if device_id == 0x0085 { return "Centrino Advanced-N 6205 [Taylor Peak]" as ptr<u8>; }
        if device_id == 0x08B1 { return "Wireless 7260" as ptr<u8>; }
        if device_id == 0x24FB { return "Dual Band Wireless-AC 3160" as ptr<u8>; }
        if device_id == 0x24FD { return "Dual Band Wireless-AC 8265" as ptr<u8>; }
        if device_id == 0x2723 { return "Wi-Fi 6 AX200" as ptr<u8>; }
        return "Intel Unknown Device" as ptr<u8>;
    }
    
    // --- REALTEK DEVICES ---
    if vendor_id == 0x10EC {
        if device_id == 0x8139 { return "RTL-8100/8101L/8139 PCI Fast Ethernet Adapter" as ptr<u8>; }
        if device_id == 0x8168 { return "RTL8111/8168/8411 PCI Express Gigabit Ethernet" as ptr<u8>; }
        if device_id == 0x8169 { return "RTL8169 PCI Gigabit Ethernet Controller" as ptr<u8>; }
        if device_id == 0x8125 { return "RTL8125 2.5GbE Controller" as ptr<u8>; }
        if device_id == 0x818B { return "RTL8192EE PCIe Wireless Network Adapter" as ptr<u8>; }
        if device_id == 0x8821 { return "RTL8821AE 802.11ac PCIe Wireless Network Adapter" as ptr<u8>; }
        if device_id == 0x8822 { return "RTL8822BE 802.11a/b/g/n/ac WiFi adapter" as ptr<u8>; }
        if device_id == 0x522A { return "RTS522A PCI Express Card Reader" as ptr<u8>; }
        if device_id == 0x0282 { return "RTL8188EE Wireless Network Adapter" as ptr<u8>; }
        return "Realtek Unknown Device" as ptr<u8>;
    }
    
    // --- NVIDIA DEVICES ---
    if vendor_id == 0x10DE {
        if device_id == 0x0402 { return "GeForce 8600 GT" as ptr<u8>; }
        if device_id == 0x0611 { return "GeForce 8800 GT" as ptr<u8>; }
        if device_id == 0x0A20 { return "GeForce GT 220" as ptr<u8>; }
        if device_id == 0x06C0 { return "GeForce GTX 480" as ptr<u8>; }
        if device_id == 0x1080 { return "GeForce GTX 580" as ptr<u8>; }
        if device_id == 0x1180 { return "GeForce GTX 680" as ptr<u8>; }
        if device_id == 0x13C2 { return "GeForce GTX 970" as ptr<u8>; }
        if device_id == 0x13C0 { return "GeForce GTX 980" as ptr<u8>; }
        if device_id == 0x1C03 { return "GeForce GTX 1060 6GB" as ptr<u8>; }
        if device_id == 0x1B81 { return "GeForce GTX 1070" as ptr<u8>; }
        if device_id == 0x1B06 { return "GeForce GTX 1080 Ti" as ptr<u8>; }
        if device_id == 0x1E84 { return "GeForce RTX 2070" as ptr<u8>; }
        if device_id == 0x1E07 { return "GeForce RTX 2080 Ti" as ptr<u8>; }
        if device_id == 0x2204 { return "GeForce RTX 3090" as ptr<u8>; }
        if device_id == 0x2484 { return "GeForce RTX 3070" as ptr<u8>; }
        if device_id == 0x2684 { return "GeForce RTX 4090" as ptr<u8>; }
        if device_id == 0x28E0 { return "GeForce RTX 4050 Laptop GPU" as ptr<u8>; } // YBG13's PC!
        if device_id == 0x0E0A { return "GF119 HDMI Audio Controller" as ptr<u8>; }
        if device_id == 0x0FB0 { return "GM200 High Definition Audio" as ptr<u8>; }
        if device_id == 0x10F0 { return "GP104 High Definition Audio Controller" as ptr<u8>; }
        if device_id == 0x10FA { return "TU104 HD Audio Controller" as ptr<u8>; }
        return "NVIDIA Unknown Device" as ptr<u8>;
    }
    
    // --- AMD/ATI DEVICES ---
    if vendor_id == 0x1002 {
        if device_id == 0x6738 { return "Radeon HD 6870" as ptr<u8>; }
        if device_id == 0x6798 { return "Radeon HD 7970 / R9 280X" as ptr<u8>; }
        if device_id == 0x67B1 { return "Radeon R9 290 / 390" as ptr<u8>; }
        if device_id == 0x67DF { return "Radeon RX 470/480/570/580/590" as ptr<u8>; }
        if device_id == 0x687F { return "Radeon RX Vega 56/64" as ptr<u8>; }
        if device_id == 0x731F { return "Radeon RX 5700 XT" as ptr<u8>; }
        if device_id == 0x73BF { return "Radeon RX 6800 XT / 6900 XT" as ptr<u8>; }
        if device_id == 0x744C { return "Radeon RX 7900 XTX" as ptr<u8>; }
        if device_id == 0x4383 { return "SB7x0/SB8x0/SB9x0 High Definition Audio Controller" as ptr<u8>; }
        if device_id == 0x1457 { return "Family 17h (Models 00h-0fh) HD Audio Controller" as ptr<u8>; }
        if device_id == 0x4391 { return "SB7x0/SB8x0/SB9x0 SATA Controller [AHCI mode]" as ptr<u8>; }
        if device_id == 0x7901 { return "FCH SATA Controller [AHCI mode]" as ptr<u8>; }
        return "AMD/ATI Unknown Device" as ptr<u8>;
    }
    
    // --- VIRTUALIZATION DEVICES (VIRTIO, VMWARE, VBOX) ---
    if vendor_id == 0x1AF4 {
        if device_id == 0x1000 { return "VirtIO Network Device" as ptr<u8>; }
        if device_id == 0x1001 { return "VirtIO Block Device" as ptr<u8>; }
        if device_id == 0x1002 { return "VirtIO Memory Balloon" as ptr<u8>; }
        if device_id == 0x1003 { return "VirtIO Console" as ptr<u8>; }
        if device_id == 0x1004 { return "VirtIO SCSI" as ptr<u8>; }
        if device_id == 0x1005 { return "VirtIO RNG" as ptr<u8>; }
        if device_id == 0x1041 { return "VirtIO Network Device (Modern)" as ptr<u8>; }
        if device_id == 0x1042 { return "VirtIO Block Device (Modern)" as ptr<u8>; }
        if device_id == 0x1050 { return "VirtIO GPU" as ptr<u8>; }
        return "VirtIO Unknown Device" as ptr<u8>;
    }
    if vendor_id == 0x15AD {
        if device_id == 0x0405 { return "VMware SVGA II Adapter" as ptr<u8>; }
        if device_id == 0x07B0 { return "VMware VMXNET3 Ethernet Controller" as ptr<u8>; }
        if device_id == 0x07A0 { return "VMware PVSCSI SCSI Controller" as ptr<u8>; }
        return "VMware Unknown Device" as ptr<u8>;
    }
    if vendor_id == 0x80EE {
        if device_id == 0xBEEF { return "VirtualBox Graphics Adapter" as ptr<u8>; }
        if device_id == 0xCAFE { return "VirtualBox Guest Service" as ptr<u8>; }
        return "VirtualBox Unknown Device" as ptr<u8>;
    }
    
    // --- STORAGE/SAMSUNG/BROADCOM AND OTHERS ---
    if vendor_id == 0x144D {
        if device_id == 0xA802 { return "Samsung SM951 NVMe" as ptr<u8>; }
        if device_id == 0xA804 { return "Samsung 960 EVO/PRO NVMe" as ptr<u8>; }
        if device_id == 0xA808 { return "Samsung 970 EVO/PRO NVMe" as ptr<u8>; }
        if device_id == 0xA80A { return "Samsung 980 PRO NVMe" as ptr<u8>; }
        if device_id == 0xA80C { return "Samsung 990 PRO NVMe" as ptr<u8>; }
        return "Samsung NVMe Unknown" as ptr<u8>;
    }
    if vendor_id == 0x14E4 {
        if device_id == 0x1659 { return "NetXtreme BCM5721 Gigabit Ethernet" as ptr<u8>; }
        if device_id == 0x1677 { return "NetXtreme BCM5751 Gigabit Ethernet" as ptr<u8>; }
        if device_id == 0x4311 { return "BCM4311 802.11b/g WLAN" as ptr<u8>; }
        if device_id == 0x4322 { return "BCM4322 802.11a/b/g/n Wireless LAN" as ptr<u8>; }
        if device_id == 0x4360 { return "BCM4360 802.11ac Wireless Network Adapter" as ptr<u8>; }
        return "Broadcom Unknown Device" as ptr<u8>;
    }
    if vendor_id == 0x168C {
        if device_id == 0x002B { return "AR9285 Wireless Network Adapter" as ptr<u8>; }
        if device_id == 0x002E { return "AR9287 Wireless Network Adapter" as ptr<u8>; }
        if device_id == 0x0032 { return "AR9485 Wireless Network Adapter" as ptr<u8>; }
        if device_id == 0x003C { return "QCA986x/988x 802.11ac Wireless Network Adapter" as ptr<u8>; }
        return "Atheros Unknown Device" as ptr<u8>;
    }

    return "Generic Unknown PCI Device" as ptr<u8>;
}

struct PciDeviceInfo {
    bus: u8,
    slot: u8,
    func: u8,
    vendor_id: u16,
    device_id: u16,
    class_code: u8,
    subclass: u8,
    prog_if: u8,
    irq: u8,
    bar0: u32,
    bar1: u32,
    bar2: u32,
    bar3: u32,
    bar4: u32,
    bar5: u32,
    is_active: bool,
}

let mut pci_device_tree: [PciDeviceInfo; 256];
let mut pci_device_count: u32 = 0;

fn pci_config_read_word(bus: u8, slot: u8, func: u8, offset: u8) -> u16 {
    let address: u32 = ((bus as u32) << 16) | ((slot as u32) << 11) | ((func as u32) << 8) | (offset as u32 & 0xFC) | 0x80000000;
    outl(0xCF8, address);
    let tmp = inl(0xCFC);
    return ((tmp >> ((offset & 2) * 8)) & 0xFFFF) as u16;
}

fn pci_config_read_dword(bus: u8, slot: u8, func: u8, offset: u8) -> u32 {
    let address: u32 = ((bus as u32) << 16) | ((slot as u32) << 11) | ((func as u32) << 8) | (offset as u32 & 0xFC) | 0x80000000;
    outl(0xCF8, address);
    return inl(0xCFC);
}

fn uda_probe_pci_bus() {
    shell_print_string("UDA: Probing PCI/PCIe Busses...\n" as ptr<u8>);
    for bus in 0..=255 {
        for slot in 0..32 {
            let vendor_id = pci_config_read_word(bus as u8, slot as u8, 0, 0);
            if vendor_id != 0xFFFF {
                let device_id = pci_config_read_word(bus as u8, slot as u8, 0, 2);
                let class_subclass = pci_config_read_word(bus as u8, slot as u8, 0, 0x0A);
                let class_code = (class_subclass >> 8) as u8;
                let subclass = (class_subclass & 0xFF) as u8;
                let prog_if = (pci_config_read_word(bus as u8, slot as u8, 0, 0x08) >> 8) as u8;
                
                if pci_device_count < 256 {
                    let dev = &pci_device_tree[pci_device_count as usize];
                    dev.bus = bus as u8;
                    dev.slot = slot as u8;
                    dev.func = 0;
                    dev.vendor_id = vendor_id;
                    dev.device_id = device_id;
                    dev.class_code = class_code;
                    dev.subclass = subclass;
                    dev.prog_if = prog_if;
                    dev.is_active = true;
                    
                    dev.bar0 = pci_config_read_dword(bus as u8, slot as u8, 0, 0x10);
                    dev.bar1 = pci_config_read_dword(bus as u8, slot as u8, 0, 0x14);
                    dev.bar2 = pci_config_read_dword(bus as u8, slot as u8, 0, 0x18);
                    dev.bar3 = pci_config_read_dword(bus as u8, slot as u8, 0, 0x1C);
                    dev.bar4 = pci_config_read_dword(bus as u8, slot as u8, 0, 0x20);
                    dev.bar5 = pci_config_read_dword(bus as u8, slot as u8, 0, 0x24);
                    dev.irq  = (pci_config_read_word(bus as u8, slot as u8, 0, 0x3C) & 0xFF) as u8;
                    
                    pci_device_count = pci_device_count + 1;
                    
                    uda_match_and_load_driver(dev);
                }
            }
        }
    }
    shell_print_string("UDA: PCI Scan Complete. Found devices: " as ptr<u8>);
    let mut buf: [u8; 16];
    itoa(pci_device_count as i32, 10, &buf[0] as ptr<u8>);
    shell_print_string(&buf[0] as ptr<u8>);
    shell_print_string("\n" as ptr<u8>);
}

fn uda_match_and_load_driver(dev: ptr<PciDeviceInfo>) {
    let vid = (*dev).vendor_id;
    let did = (*dev).device_id;
    let cls = (*dev).class_code;
    let sub = (*dev).subclass;
    let p_if = (*dev).prog_if;

    // --- Mass Storage Controllers ---
    if cls == 0x01 {
        if sub == 0x01 {
            drv_ide_init();
        } else if sub == 0x06 && p_if == 0x01 {
            drv_ahci_init();
        } else if sub == 0x08 && p_if == 0x02 {
            drv_nvme_init();
        }
    }
    else if cls == 0x02 {
        if sub == 0x00 { // Ethernet
            if vid == 0x8086 {
                if did == 0x100E || did == 0x100F { drv_e1000_init(); }
                else if did == 0x153A || did == 0x153B { drv_e1000e_init(); }
                else { drv_e1000e_init(); } // Generic fallback for intel network
            } else if vid == 0x10EC {
                if did == 0x8139 { drv_rtl8139_init(); }
                else if did == 0x8168 { drv_rtl8168_init(); }
            } else if vid == 0x1AF4 && did == 0x1000 {
                drv_virtio_net_init();
            }
        } else if sub == 0x80 { // Network controller (often WiFi)
            if vid == 0x8086 || vid == 0x8087 { drv_intel_wifi_init(); }
            else if vid == 0x168C { drv_atheros_wifi_init(); }
        }
    }
    else if cls == 0x03 {
        if vid == 0x8086 { drv_intel_gma_init(); }
        else if vid == 0x1002 { drv_amd_radeon_init(); }
        else if vid == 0x10DE { drv_nvidia_nouveau_init(); }
        else if vid == 0x15AD { drv_vmware_svga_init(); }
        else if vid == 0x80EE { drv_vbox_video_init(); }
        else if vid == 0x1AF4 { drv_virtio_gpu_init(); }
        else { drv_bochs_vbe_init(); }
    }

    else if cls == 0x04 {
        if sub == 0x01 { drv_ac97_init(); }
        else if sub == 0x03 { drv_intel_hda_init(); }
    }
    else if cls == 0x0C && sub == 0x03 {
        if p_if == 0x00 { drv_uhci_init(); }
        else if p_if == 0x10 { drv_ohci_init(); }
        else if p_if == 0x20 { drv_ehci_init(); }
        else if p_if == 0x30 { drv_xhci_init(); }
    }
}

fn uda_dump_device_tree() {
    shell_print_string("\n--- UDA DEVICE TREE DUMP ---\n" as ptr<u8>);
    for i in 0..pci_device_count {
        let dev = &pci_device_tree[i as usize];
        let v_name = get_pci_vendor_name(dev.vendor_id);
        let d_name = get_pci_device_name(dev.vendor_id, dev.device_id);
        
        shell_print_string("BUS: " as ptr<u8>);
        let mut bbuf: [u8; 8]; itoa(dev.bus as i32, 10, &bbuf[0] as ptr<u8>); shell_print_string(&bbuf[0] as ptr<u8>);
        
        shell_print_string(" | VID: 0x" as ptr<u8>);
        itoa(dev.vendor_id as i32, 16, &bbuf[0] as ptr<u8>); shell_print_string(&bbuf[0] as ptr<u8>);
        
        shell_print_string(" | DID: 0x" as ptr<u8>);
        itoa(dev.device_id as i32, 16, &bbuf[0] as ptr<u8>); shell_print_string(&bbuf[0] as ptr<u8>);
        
        shell_print_string("\n    -> " as ptr<u8>);
        shell_print_string(v_name); shell_print_string(" - " as ptr<u8>); shell_print_string(d_name);
        shell_print_string("\n" as ptr<u8>);
    }
    shell_print_string("----------------------------\n" as ptr<u8>);
}

fn uda_thread() {
    uda_register_all_drivers();
    uda_probe_pci_bus();
    uda_dump_device_tree();
    
    // UDA Daemon loop
    loop {
        // Here we would handle Hot-Plug events (PCIe Hotplug, USB Hotplug)
        cpu_pause();
        sched();
    }
}

fn drv_lsi_megaraid_init() -> bool { shell_print_string("Loading LSI MegaRAID SAS...\n" as ptr<u8>); return true; }
fn drv_adaptec_raid_init() -> bool { shell_print_string("Loading Adaptec AACRAID...\n" as ptr<u8>); return true; }
fn drv_promise_fasttrak_init() -> bool { shell_print_string("Loading Promise FastTrak RAID...\n" as ptr<u8>); return true; }
fn drv_highpoint_rocketraid_init() -> bool { shell_print_string("Loading HighPoint RocketRAID...\n" as ptr<u8>); return true; }
fn drv_via_sata_init() -> bool { shell_print_string("Loading VIA SATA Controller...\n" as ptr<u8>); return true; }
fn drv_sis_sata_init() -> bool { shell_print_string("Loading SiS SATA Controller...\n" as ptr<u8>); return true; }
fn drv_uli_sata_init() -> bool { shell_print_string("Loading ULi SATA Controller...\n" as ptr<u8>); return true; }
fn drv_marvell_sata_init() -> bool { shell_print_string("Loading Marvell 88SE SATA...\n" as ptr<u8>); return true; }
fn drv_jmicron_sata_init() -> bool { shell_print_string("Loading JMicron JMB36x SATA...\n" as ptr<u8>); return true; }
fn drv_asmedia_sata_init() -> bool { shell_print_string("Loading ASMedia ASM106x SATA...\n" as ptr<u8>); return true; }
fn drv_mellanox_cx_init() -> bool { shell_print_string("Loading Mellanox ConnectX 10/40/100GbE...\n" as ptr<u8>); return true; }
fn drv_3com_3c905_init() -> bool { shell_print_string("Loading 3Com 3c905B Fast EtherLink...\n" as ptr<u8>); return true; }
fn drv_dec_tulip_init() -> bool { shell_print_string("Loading DEC Tulip Ethernet...\n" as ptr<u8>); return true; }
fn drv_sis_900_init() -> bool { shell_print_string("Loading SiS 900 PCI Fast Ethernet...\n" as ptr<u8>); return true; }
fn drv_via_rhine_init() -> bool { shell_print_string("Loading VIA Rhine II Fast Ethernet...\n" as ptr<u8>); return true; }
fn drv_via_velocity_init() -> bool { shell_print_string("Loading VIA Velocity Gigabit...\n" as ptr<u8>); return true; }
fn drv_marvell_yukon_init() -> bool { shell_print_string("Loading Marvell Yukon Gigabit...\n" as ptr<u8>); return true; }
fn drv_broadcom_tg3_init() -> bool { shell_print_string("Loading Broadcom Tigon3 Gigabit...\n" as ptr<u8>); return true; }
fn drv_intel_10gbe_vf_init() -> bool { shell_print_string("Loading Intel 10GbE Virtual Function...\n" as ptr<u8>); return true; }
fn drv_solarflare_init() -> bool { shell_print_string("Loading Solarflare 10/40GbE...\n" as ptr<u8>); return true; }
fn drv_qlogic_net_init() -> bool { shell_print_string("Loading QLogic 10/25GbE...\n" as ptr<u8>); return true; }
fn drv_matrox_g400_init() -> bool { shell_print_string("Loading Matrox G400/G450/G550...\n" as ptr<u8>); return true; }
fn drv_3dfx_voodoo_init() -> bool { shell_print_string("Loading 3dfx Voodoo Graphics...\n" as ptr<u8>); return true; }
fn drv_cirrus_logic_init() -> bool { shell_print_string("Loading Cirrus Logic GD5446...\n" as ptr<u8>); return true; }
fn drv_s3_trio_init() -> bool { shell_print_string("Loading S3 Trio32/64...\n" as ptr<u8>); return true; }
fn drv_s3_savage_init() -> bool { shell_print_string("Loading S3 Savage 3D...\n" as ptr<u8>); return true; }
fn drv_via_chrome_init() -> bool { shell_print_string("Loading VIA UniChrome Graphics...\n" as ptr<u8>); return true; }
fn drv_creative_emu10k1_init() -> bool { shell_print_string("Loading Creative Sound Blaster Live!...\n" as ptr<u8>); return true; }
fn drv_creative_xifi_init() -> bool { shell_print_string("Loading Creative X-Fi Audio...\n" as ptr<u8>); return true; }
fn drv_via_envy24_init() -> bool { shell_print_string("Loading VIA Envy24 Audio...\n" as ptr<u8>); return true; }
fn drv_cmedia_cmi8738_init() -> bool { shell_print_string("Loading C-Media CMI8738 Audio...\n" as ptr<u8>); return true; }
fn drv_cmedia_oxygen_init() -> bool { shell_print_string("Loading C-Media Oxygen HD Audio...\n" as ptr<u8>); return true; }
fn drv_ess_solo1_init() -> bool { shell_print_string("Loading ESS Solo-1 Audio...\n" as ptr<u8>); return true; }
fn drv_yamaha_ymf724_init() -> bool { shell_print_string("Loading Yamaha YMF724 Audio...\n" as ptr<u8>); return true; }
fn drv_fresco_logic_xhci_init() -> bool { shell_print_string("Loading Fresco Logic xHCI USB 3.0...\n" as ptr<u8>); return true; }
fn drv_renesas_xhci_init() -> bool { shell_print_string("Loading Renesas xHCI USB 3.0...\n" as ptr<u8>); return true; }
fn drv_asmedia_xhci_init() -> bool { shell_print_string("Loading ASMedia xHCI USB 3.0/3.1...\n" as ptr<u8>); return true; }
fn drv_via_xhci_init() -> bool { shell_print_string("Loading VIA xHCI USB 3.0...\n" as ptr<u8>); return true; }
fn drv_ti_xhci_init() -> bool { shell_print_string("Loading Texas Instruments xHCI USB 3.0...\n" as ptr<u8>); return true; }
fn drv_ti_firewire_init() -> bool { shell_print_string("Loading Texas Instruments IEEE 1394...\n" as ptr<u8>); return true; }
fn drv_via_firewire_init() -> bool { shell_print_string("Loading VIA IEEE 1394 Firewire...\n" as ptr<u8>); return true; }
fn drv_ricoh_firewire_init() -> bool { shell_print_string("Loading Ricoh IEEE 1394 Firewire...\n" as ptr<u8>); return true; }
fn drv_ricoh_sd_init() -> bool { shell_print_string("Loading Ricoh SD/MMC Host Controller...\n" as ptr<u8>); return true; }
fn drv_o2micro_sd_init() -> bool { shell_print_string("Loading O2Micro SD/MMC Host Controller...\n" as ptr<u8>); return true; }
fn drv_ene_sd_init() -> bool { shell_print_string("Loading ENE Technology SD Host Controller...\n" as ptr<u8>); return true; }

fn uda_register_extended_drivers() {
    register_driver("lsi_megaraid" as ptr<u8>, 2, drv_lsi_megaraid_init as u64, 0, 0, 0);
    register_driver("adaptec_raid" as ptr<u8>, 2, drv_adaptec_raid_init as u64, 0, 0, 0);
    register_driver("promise_raid" as ptr<u8>, 2, drv_promise_fasttrak_init as u64, 0, 0, 0);
    register_driver("highpoint_raid" as ptr<u8>, 2, drv_highpoint_rocketraid_init as u64, 0, 0, 0);
    register_driver("via_sata" as ptr<u8>, 2, drv_via_sata_init as u64, 0, 0, 0);
    register_driver("sis_sata" as ptr<u8>, 2, drv_sis_sata_init as u64, 0, 0, 0);
    register_driver("uli_sata" as ptr<u8>, 2, drv_uli_sata_init as u64, 0, 0, 0);
    register_driver("marvell_sata" as ptr<u8>, 2, drv_marvell_sata_init as u64, 0, 0, 0);
    register_driver("jmicron_sata" as ptr<u8>, 2, drv_jmicron_sata_init as u64, 0, 0, 0);
    register_driver("asmedia_sata" as ptr<u8>, 2, drv_asmedia_sata_init as u64, 0, 0, 0);
    register_driver("mellanox_cx" as ptr<u8>, 1, drv_mellanox_cx_init as u64, 0, 0, 0);
    register_driver("3com_3c905" as ptr<u8>, 1, drv_3com_3c905_init as u64, 0, 0, 0);
    register_driver("dec_tulip" as ptr<u8>, 1, drv_dec_tulip_init as u64, 0, 0, 0);
    register_driver("sis_900" as ptr<u8>, 1, drv_sis_900_init as u64, 0, 0, 0);
    register_driver("via_rhine" as ptr<u8>, 1, drv_via_rhine_init as u64, 0, 0, 0);
    register_driver("via_velocity" as ptr<u8>, 1, drv_via_velocity_init as u64, 0, 0, 0);
    register_driver("marvell_yukon" as ptr<u8>, 1, drv_marvell_yukon_init as u64, 0, 0, 0);
    register_driver("bcm_tg3" as ptr<u8>, 1, drv_broadcom_tg3_init as u64, 0, 0, 0);
    register_driver("intel_10gbe_vf" as ptr<u8>, 1, drv_intel_10gbe_vf_init as u64, 0, 0, 0);
    register_driver("solarflare" as ptr<u8>, 1, drv_solarflare_init as u64, 0, 0, 0);
    register_driver("qlogic_net" as ptr<u8>, 1, drv_qlogic_net_init as u64, 0, 0, 0);
    register_driver("matrox_g400" as ptr<u8>, 3, drv_matrox_g400_init as u64, 0, 0, 0);
    register_driver("3dfx_voodoo" as ptr<u8>, 3, drv_3dfx_voodoo_init as u64, 0, 0, 0);
    register_driver("cirrus_logic" as ptr<u8>, 3, drv_cirrus_logic_init as u64, 0, 0, 0);
    register_driver("s3_trio" as ptr<u8>, 3, drv_s3_trio_init as u64, 0, 0, 0);
    register_driver("s3_savage" as ptr<u8>, 3, drv_s3_savage_init as u64, 0, 0, 0);
    register_driver("via_chrome" as ptr<u8>, 3, drv_via_chrome_init as u64, 0, 0, 0);
    register_driver("sb_live" as ptr<u8>, 4, drv_creative_emu10k1_init as u64, 0, 0, 0);
    register_driver("sb_xifi" as ptr<u8>, 4, drv_creative_xifi_init as u64, 0, 0, 0);
    register_driver("via_envy24" as ptr<u8>, 4, drv_via_envy24_init as u64, 0, 0, 0);
    register_driver("cmi8738" as ptr<u8>, 4, drv_cmedia_cmi8738_init as u64, 0, 0, 0);
    register_driver("cmedia_oxygen" as ptr<u8>, 4, drv_cmedia_oxygen_init as u64, 0, 0, 0);
    register_driver("ess_solo1" as ptr<u8>, 4, drv_ess_solo1_init as u64, 0, 0, 0);
    register_driver("ymf724" as ptr<u8>, 4, drv_yamaha_ymf724_init as u64, 0, 0, 0);
    register_driver("fresco_xhci" as ptr<u8>, 6, drv_fresco_logic_xhci_init as u64, 0, 0, 0);
    register_driver("renesas_xhci" as ptr<u8>, 6, drv_renesas_xhci_init as u64, 0, 0, 0);
    register_driver("asmedia_xhci" as ptr<u8>, 6, drv_asmedia_xhci_init as u64, 0, 0, 0);
    register_driver("via_xhci" as ptr<u8>, 6, drv_via_xhci_init as u64, 0, 0, 0);
    register_driver("ti_xhci" as ptr<u8>, 6, drv_ti_xhci_init as u64, 0, 0, 0);
    register_driver("ti_firewire" as ptr<u8>, 2, drv_ti_firewire_init as u64, 0, 0, 0);
    register_driver("via_firewire" as ptr<u8>, 2, drv_via_firewire_init as u64, 0, 0, 0);
    register_driver("ricoh_firewire" as ptr<u8>, 2, drv_ricoh_firewire_init as u64, 0, 0, 0);
    register_driver("ricoh_sd" as ptr<u8>, 2, drv_ricoh_sd_init as u64, 0, 0, 0);
    register_driver("o2micro_sd" as ptr<u8>, 2, drv_o2micro_sd_init as u64, 0, 0, 0);
    register_driver("ene_sd" as ptr<u8>, 2, drv_ene_sd_init as u64, 0, 0, 0);
}

fn get_pci_vendor_name_ext(vendor_id: u16) -> ptr<u8> {
    if vendor_id == 0x8086 { return "Intel Corporation" as ptr<u8>; }
    if vendor_id == 0x1002 { return "Advanced Micro Devices, Inc. [AMD/ATI]" as ptr<u8>; }
    if vendor_id == 0x10DE { return "NVIDIA Corporation" as ptr<u8>; }
    if vendor_id == 0x10EC { return "Realtek Semiconductor Co., Ltd." as ptr<u8>; }
    if vendor_id == 0x14E4 { return "Broadcom Inc. and subsidiaries" as ptr<u8>; }
    if vendor_id == 0x1AF4 { return "Red Hat, Inc. [Virtio]" as ptr<u8>; }
    if vendor_id == 0x15AD { return "VMware" as ptr<u8>; }
    if vendor_id == 0x80EE { return "InnoTek Systemberatung GmbH [VirtualBox]" as ptr<u8>; }
    if vendor_id == 0x1022 { return "Advanced Micro Devices, Inc. [AMD]" as ptr<u8>; }
    if vendor_id == 0x104C { return "Texas Instruments" as ptr<u8>; }
    if vendor_id == 0x11AB { return "Marvell Technology Group Ltd." as ptr<u8>; }
    if vendor_id == 0x197B { return "JMicron Technology Corp." as ptr<u8>; }
    if vendor_id == 0x1014 { return "IBM Corporation" as ptr<u8>; }
    if vendor_id == 0x103C { return "Hewlett-Packard Company" as ptr<u8>; }
    if vendor_id == 0x1028 { return "Dell" as ptr<u8>; }
    if vendor_id == 0x1043 { return "ASUSTeK Computer Inc." as ptr<u8>; }
    if vendor_id == 0x1458 { return "Gigabyte Technology Co., Ltd" as ptr<u8>; }
    if vendor_id == 0x1462 { return "Micro-Star International Co., Ltd. [MSI]" as ptr<u8>; }
    if vendor_id == 0x15B3 { return "Mellanox Technologies" as ptr<u8>; }
    if vendor_id == 0x1B36 { return "Red Hat, Inc. [QEMU]" as ptr<u8>; }
    if vendor_id == 0x144D { return "Samsung Electronics Co Ltd" as ptr<u8>; }
    if vendor_id == 0x152D { return "JMicron Technology Corp. [NVMe]" as ptr<u8>; }
    if vendor_id == 0x1D0F { return "Amazon.com, Inc." as ptr<u8>; }
    if vendor_id == 0x1AE0 { return "Google, Inc." as ptr<u8>; }
    if vendor_id == 0x106B { return "Apple Inc." as ptr<u8>; }
    if vendor_id == 0x105A { return "Promise Technology, Inc." as ptr<u8>; }
    if vendor_id == 0x10B5 { return "PLX Technology, Inc." as ptr<u8>; }
    if vendor_id == 0x10DF { return "Emulex Corporation" as ptr<u8>; }
    if vendor_id == 0x1106 { return "VIA Technologies, Inc." as ptr<u8>; }
    if vendor_id == 0x1179 { return "Toshiba Corporation" as ptr<u8>; }
    if vendor_id == 0x1186 { return "D-Link System Inc" as ptr<u8>; }
    if vendor_id == 0x13F0 { return "Sundance Technology Inc / IC Plus Corp" as ptr<u8>; }
    if vendor_id == 0x168C { return "Qualcomm Atheros" as ptr<u8>; }
    if vendor_id == 0x1814 { return "Ralink corp." as ptr<u8>; }
    if vendor_id == 0x1B21 { return "ASMedia Technology Inc." as ptr<u8>; }
    if vendor_id == 0x8087 { return "Intel Corporation [Wireless]" as ptr<u8>; }
    if vendor_id == 0x1000 { return "LSI Logic / Symbios Logic" as ptr<u8>; }
    if vendor_id == 0x9005 { return "Adaptec" as ptr<u8>; }
    if vendor_id == 0x102B { return "Matrox Electronics Systems Ltd." as ptr<u8>; }
    if vendor_id == 0x121A { return "3Dfx Interactive, Inc." as ptr<u8>; }
    if vendor_id == 0x1013 { return "Cirrus Logic" as ptr<u8>; }
    if vendor_id == 0x104B { return "BusLogic" as ptr<u8>; }
    if vendor_id == 0x10EA { return "Intergraphics" as ptr<u8>; }
    if vendor_id == 0x108E { return "Sun Microsystems Computer Corp." as ptr<u8>; }
    if vendor_id == 0x1011 { return "Digital Equipment Corporation" as ptr<u8>; }
    if vendor_id == 0x10B7 { return "3Com Corporation" as ptr<u8>; }
    if vendor_id == 0x10D9 { return "Macronix, Inc. [MXIC]" as ptr<u8>; }
    if vendor_id == 0x1113 { return "Accton Technology Corporation" as ptr<u8>; }
    if vendor_id == 0x11AD { return "Lite-On Communications Inc" as ptr<u8>; }
    if vendor_id == 0x1259 { return "Allied Telesyn International" as ptr<u8>; }
    if vendor_id == 0x1371 { return "Creative Labs" as ptr<u8>; }
    if vendor_id == 0x1102 { return "Creative Labs [Audio]" as ptr<u8>; }
    if vendor_id == 0x13F6 { return "C-Media Electronics Inc" as ptr<u8>; }
    if vendor_id == 0x109E { return "Brooktree Corporation" as ptr<u8>; }
    if vendor_id == 0x10CC { return "Ericsson Microelectronics" as ptr<u8>; }
    if vendor_id == 0x12D8 { return "Pericom Semiconductor" as ptr<u8>; }
    if vendor_id == 0x1B73 { return "Fresco Logic" as ptr<u8>; }
    if vendor_id == 0x1912 { return "Renesas Technology Corp." as ptr<u8>; }
    if vendor_id == 0x1180 { return "Ricoh Co Ltd" as ptr<u8>; }
    if vendor_id == 0x1217 { return "O2 Micro, Inc." as ptr<u8>; }
    if vendor_id == 0x1524 { return "ENE Technology Inc" as ptr<u8>; }
    if vendor_id == 0x125D { return "ESS Technology" as ptr<u8>; }
    if vendor_id == 0x1073 { return "Yamaha Corporation" as ptr<u8>; }
    if vendor_id == 0x1039 { return "Silicon Integrated Systems [SiS]" as ptr<u8>; }
    if vendor_id == 0x10B9 { return "ULi Electronics Inc." as ptr<u8>; }
    if vendor_id == 0x5333 { return "S3 Graphics Ltd." as ptr<u8>; }
    return "Unknown Device Vendor" as ptr<u8>;
}

fn get_pci_device_name_ext(vendor_id: u16, device_id: u16) -> ptr<u8> {
    if vendor_id == 0x8086 {
        if device_id == 0x100E { return "82540EM Gigabit Ethernet Controller" as ptr<u8>; }
        if device_id == 0x100F { return "82545EM Gigabit Ethernet Controller" as ptr<u8>; }
        if device_id == 0x10D3 { return "82574L Gigabit Network Connection" as ptr<u8>; }
        if device_id == 0x10EA { return "82577LM Gigabit Network Connection" as ptr<u8>; }
        if device_id == 0x1502 { return "82579LM Gigabit Network Connection" as ptr<u8>; }
        if device_id == 0x1503 { return "82579V Gigabit Network Connection" as ptr<u8>; }
        if device_id == 0x153A { return "I217-LM Gigabit Network Connection" as ptr<u8>; }
        if device_id == 0x153B { return "I217-V Gigabit Network Connection" as ptr<u8>; }
        if device_id == 0x15B7 { return "I219-LM Gigabit Network Connection" as ptr<u8>; }
        if device_id == 0x15B8 { return "I219-V Gigabit Network Connection" as ptr<u8>; }
        if device_id == 0x10FB { return "82599ES 10-Gigabit SFI/SFP+ Network Connection" as ptr<u8>; }
        if device_id == 0x1528 { return "Ethernet Controller 10-Gigabit X540-AT2" as ptr<u8>; }
        if device_id == 0x2922 { return "82801IR/IO/P (ICH9) 6 port SATA Controller" as ptr<u8>; }
        if device_id == 0x1C02 { return "6 Series/C200 Series Chipset Family 6 port SATA" as ptr<u8>; }
        if device_id == 0x1E02 { return "7 Series/C210 Series Chipset Family 6-port SATA" as ptr<u8>; }
        if device_id == 0x8C02 { return "8 Series/C220 Series Chipset Family 6-port SATA" as ptr<u8>; }
        if device_id == 0xA102 { return "100 Series/C230 Series Chipset Family SATA" as ptr<u8>; }
        if device_id == 0xA282 { return "200 Series/Z370 Chipset Family SATA AHCI" as ptr<u8>; }
        if device_id == 0x0116 { return "3rd Gen Core processor Graphics Controller" as ptr<u8>; }
        if device_id == 0x0166 { return "3rd Gen Core processor Graphics Controller" as ptr<u8>; }
        if device_id == 0x0412 { return "4th Gen Core Processor Integrated Graphics" as ptr<u8>; }
        if device_id == 0x1912 { return "HD Graphics 530" as ptr<u8>; }
        if device_id == 0x3E92 { return "UHD Graphics 630 (Desktop)" as ptr<u8>; }
        if device_id == 0x9BC5 { return "CometLake-S GT2 [UHD Graphics 630]" as ptr<u8>; }
        if device_id == 0x2668 { return "82801FB/FBM/FR/FW/FRW High Definition Audio" as ptr<u8>; }
        if device_id == 0x284B { return "82801H (ICH8 Family) High Definition Audio" as ptr<u8>; }
        if device_id == 0x293E { return "82801I (ICH9 Family) High Definition Audio" as ptr<u8>; }
        if device_id == 0x1E20 { return "7 Series/C210 Series Chipset High Definition Audio" as ptr<u8>; }
        if device_id == 0xA170 { return "100 Series/C230 Series Chipset HD Audio" as ptr<u8>; }
        if device_id == 0x8C31 { return "8 Series/C220 Series Chipset Family USB xHCI" as ptr<u8>; }
        if device_id == 0xA12F { return "100 Series/C230 Series Chipset USB 3.0 xHCI" as ptr<u8>; }
        if device_id == 0x1E2D { return "7 Series/C210 Series Chipset USB Enhanced" as ptr<u8>; }
        if device_id == 0x24C2 { return "82801DB/DBM (ICH4/ICH4-M) USB UHCI" as ptr<u8>; }
        if device_id == 0xF1A5 { return "NVMe SSD Controller (Optane/760p)" as ptr<u8>; }
        if device_id == 0x4220 { return "PRO/Wireless 2200BG Network Connection" as ptr<u8>; }
        if device_id == 0x4229 { return "PRO/Wireless 4965 AG or AGN Network Connection" as ptr<u8>; }
        if device_id == 0x0085 { return "Centrino Advanced-N 6205 [Taylor Peak]" as ptr<u8>; }
        if device_id == 0x08B1 { return "Wireless 7260" as ptr<u8>; }
        if device_id == 0x24FB { return "Dual Band Wireless-AC 3160" as ptr<u8>; }
        if device_id == 0x24FD { return "Dual Band Wireless-AC 8265" as ptr<u8>; }
        if device_id == 0x2723 { return "Wi-Fi 6 AX200" as ptr<u8>; }
        if device_id == 0x2725 { return "Wi-Fi 6 AX210/AX1675 2x2" as ptr<u8>; }
        if device_id == 0x7113 { return "PIIX4/4E/4M IDE Controller" as ptr<u8>; }
        if device_id == 0x1237 { return "440FX - 82441FX PMC" as ptr<u8>; }
        if device_id == 0x7000 { return "82371SB PIIX3 ISA" as ptr<u8>; }
        if device_id == 0x7110 { return "82371AB/EB/MB PIIX4 ISA" as ptr<u8>; }
        if device_id == 0x7111 { return "82371AB/EB/MB PIIX4 IDE" as ptr<u8>; }
        if device_id == 0x7112 { return "82371AB/EB/MB PIIX4 USB" as ptr<u8>; }
        return "Intel Controller" as ptr<u8>;
    }
    if vendor_id == 0x10EC {
        if device_id == 0x8139 { return "RTL-8100/8101L/8139 PCI Fast Ethernet" as ptr<u8>; }
        if device_id == 0x8168 { return "RTL8111/8168/8411 PCI Express Gigabit" as ptr<u8>; }
        if device_id == 0x8169 { return "RTL8169 PCI Gigabit Ethernet" as ptr<u8>; }
        if device_id == 0x8125 { return "RTL8125 2.5GbE Controller" as ptr<u8>; }
        if device_id == 0x818B { return "RTL8192EE PCIe Wireless Network Adapter" as ptr<u8>; }
        if device_id == 0x8821 { return "RTL8821AE 802.11ac PCIe Wireless" as ptr<u8>; }
        if device_id == 0x8822 { return "RTL8822BE 802.11a/b/g/n/ac WiFi" as ptr<u8>; }
        if device_id == 0x522A { return "RTS522A PCI Express Card Reader" as ptr<u8>; }
        if device_id == 0x0282 { return "RTL8188EE Wireless Network Adapter" as ptr<u8>; }
        if device_id == 0x8161 { return "RTL8162 Fast Ethernet" as ptr<u8>; }
        if device_id == 0x8167 { return "RTL8167 Gigabit Ethernet" as ptr<u8>; }
        if device_id == 0x5209 { return "RTS5209 PCI Express Card Reader" as ptr<u8>; }
        if device_id == 0x5227 { return "RTS5227 PCI Express Card Reader" as ptr<u8>; }
        if device_id == 0x5289 { return "RTL8411B PCI Express Card Reader" as ptr<u8>; }
        return "Realtek Device" as ptr<u8>;
    }
    if vendor_id == 0x10DE {
        if device_id == 0x0402 { return "GeForce 8600 GT" as ptr<u8>; }
        if device_id == 0x0611 { return "GeForce 8800 GT" as ptr<u8>; }
        if device_id == 0x0A20 { return "GeForce GT 220" as ptr<u8>; }
        if device_id == 0x06C0 { return "GeForce GTX 480" as ptr<u8>; }
        if device_id == 0x1080 { return "GeForce GTX 580" as ptr<u8>; }
        if device_id == 0x1180 { return "GeForce GTX 680" as ptr<u8>; }
        if device_id == 0x13C2 { return "GeForce GTX 970" as ptr<u8>; }
        if device_id == 0x13C0 { return "GeForce GTX 980" as ptr<u8>; }
        if device_id == 0x1C03 { return "GeForce GTX 1060 6GB" as ptr<u8>; }
        if device_id == 0x1B81 { return "GeForce GTX 1070" as ptr<u8>; }
        if device_id == 0x1B06 { return "GeForce GTX 1080 Ti" as ptr<u8>; }
        if device_id == 0x1E84 { return "GeForce RTX 2070" as ptr<u8>; }
        if device_id == 0x1E07 { return "GeForce RTX 2080 Ti" as ptr<u8>; }
        if device_id == 0x2204 { return "GeForce RTX 3090" as ptr<u8>; }
        if device_id == 0x2484 { return "GeForce RTX 3070" as ptr<u8>; }
        if device_id == 0x2684 { return "GeForce RTX 4090" as ptr<u8>; }
        if device_id == 0x28E0 { return "GeForce RTX 4050 Laptop GPU" as ptr<u8>; }
        if device_id == 0x0E0A { return "GF119 HDMI Audio Controller" as ptr<u8>; }
        if device_id == 0x0FB0 { return "GM200 High Definition Audio" as ptr<u8>; }
        if device_id == 0x10F0 { return "GP104 High Definition Audio" as ptr<u8>; }
        if device_id == 0x10FA { return "TU104 HD Audio Controller" as ptr<u8>; }
        if device_id == 0x0059 { return "CK804 Serial ATA Controller" as ptr<u8>; }
        if device_id == 0x0054 { return "CK804 Memory Controller" as ptr<u8>; }
        if device_id == 0x0055 { return "CK804 IDE" as ptr<u8>; }
        if device_id == 0x03EF { return "MCP61 Ethernet" as ptr<u8>; }
        if device_id == 0x0DF4 { return "GeForce GT 540M" as ptr<u8>; }
        if device_id == 0x0FC6 { return "GeForce GTX 650" as ptr<u8>; }
        if device_id == 0x1140 { return "GF117M [GeForce 610M/710M]" as ptr<u8>; }
        if device_id == 0x139A { return "GM107M [GeForce GTX 950M]" as ptr<u8>; }
        if device_id == 0x1C20 { return "GP106M [GeForce GTX 1060 Mobile]" as ptr<u8>; }
        if device_id == 0x1F11 { return "TU106M [GeForce RTX 2060 Mobile]" as ptr<u8>; }
        if device_id == 0x2520 { return "GA106M [GeForce RTX 3060 Mobile]" as ptr<u8>; }
        return "NVIDIA Graphics / Multimedia" as ptr<u8>;
    }
    if vendor_id == 0x1002 {
        if device_id == 0x6738 { return "Radeon HD 6870" as ptr<u8>; }
        if device_id == 0x6798 { return "Radeon HD 7970 / R9 280X" as ptr<u8>; }
        if device_id == 0x67B1 { return "Radeon R9 290 / 390" as ptr<u8>; }
        if device_id == 0x67DF { return "Radeon RX 470/480/570/580/590" as ptr<u8>; }
        if device_id == 0x687F { return "Radeon RX Vega 56/64" as ptr<u8>; }
        if device_id == 0x731F { return "Radeon RX 5700 XT" as ptr<u8>; }
        if device_id == 0x73BF { return "Radeon RX 6800 XT / 6900 XT" as ptr<u8>; }
        if device_id == 0x744C { return "Radeon RX 7900 XTX" as ptr<u8>; }
        if device_id == 0x4383 { return "SB7x0/SB8x0/SB9x0 High Definition Audio" as ptr<u8>; }
        if device_id == 0x1457 { return "Family 17h HD Audio Controller" as ptr<u8>; }
        if device_id == 0x4391 { return "SB7x0/SB8x0/SB9x0 SATA [AHCI]" as ptr<u8>; }
        if device_id == 0x7901 { return "FCH SATA Controller [AHCI]" as ptr<u8>; }
        if device_id == 0x515E { return "Radeon X1300/X1550" as ptr<u8>; }
        if device_id == 0x9540 { return "Radeon HD 4350/4550" as ptr<u8>; }
        if device_id == 0x68B8 { return "Radeon HD 5770" as ptr<u8>; }
        if device_id == 0x6819 { return "Radeon HD 7870" as ptr<u8>; }
        if device_id == 0x15D8 { return "Raven Ridge [Radeon Vega Series]" as ptr<u8>; }
        if device_id == 0x1636 { return "Renoir [Radeon Vega Series]" as ptr<u8>; }
        if device_id == 0x73A5 { return "Navi 22 [Radeon RX 6700/6700 XT]" as ptr<u8>; }
        if device_id == 0x7480 { return "Navi 31 [Radeon RX 7900 XT]" as ptr<u8>; }
        return "AMD/ATI Display / Multimedia" as ptr<u8>;
    }
    if vendor_id == 0x1AF4 {
        if device_id == 0x1000 { return "VirtIO Network Device" as ptr<u8>; }
        if device_id == 0x1001 { return "VirtIO Block Device" as ptr<u8>; }
        if device_id == 0x1002 { return "VirtIO Memory Balloon" as ptr<u8>; }
        if device_id == 0x1003 { return "VirtIO Console" as ptr<u8>; }
        if device_id == 0x1004 { return "VirtIO SCSI" as ptr<u8>; }
        if device_id == 0x1005 { return "VirtIO RNG" as ptr<u8>; }
        if device_id == 0x1041 { return "VirtIO Network Device (Modern)" as ptr<u8>; }
        if device_id == 0x1042 { return "VirtIO Block Device (Modern)" as ptr<u8>; }
        if device_id == 0x1050 { return "VirtIO GPU" as ptr<u8>; }
        if device_id == 0x1052 { return "VirtIO Input Device" as ptr<u8>; }
        if device_id == 0x1053 { return "VirtIO Socket Device" as ptr<u8>; }
        return "VirtIO Standard Device" as ptr<u8>;
    }
    if vendor_id == 0x15AD {
        if device_id == 0x0405 { return "VMware SVGA II Adapter" as ptr<u8>; }
        if device_id == 0x07B0 { return "VMware VMXNET3 Ethernet" as ptr<u8>; }
        if device_id == 0x07A0 { return "VMware PVSCSI SCSI" as ptr<u8>; }
        if device_id == 0x0770 { return "VMware USB2 EHCI" as ptr<u8>; }
        if device_id == 0x0774 { return "VMware USB1 UHCI" as ptr<u8>; }
        return "VMware Virtual Device" as ptr<u8>;
    }
    if vendor_id == 0x80EE {
        if device_id == 0xBEEF { return "VirtualBox Graphics Adapter" as ptr<u8>; }
        if device_id == 0xCAFE { return "VirtualBox Guest Service" as ptr<u8>; }
        return "VirtualBox Virtual Device" as ptr<u8>;
    }
    if vendor_id == 0x144D {
        if device_id == 0xA802 { return "Samsung SM951 NVMe" as ptr<u8>; }
        if device_id == 0xA804 { return "Samsung 960 EVO/PRO NVMe" as ptr<u8>; }
        if device_id == 0xA808 { return "Samsung 970 EVO/PRO NVMe" as ptr<u8>; }
        if device_id == 0xA80A { return "Samsung 980 PRO NVMe" as ptr<u8>; }
        if device_id == 0xA80C { return "Samsung 990 PRO NVMe" as ptr<u8>; }
        if device_id == 0xA809 { return "Samsung PM9A1 NVMe" as ptr<u8>; }
        return "Samsung NVMe Controller" as ptr<u8>;
    }
    if vendor_id == 0x14E4 {
        if device_id == 0x1659 { return "NetXtreme BCM5721 Gigabit" as ptr<u8>; }
        if device_id == 0x1677 { return "NetXtreme BCM5751 Gigabit" as ptr<u8>; }
        if device_id == 0x4311 { return "BCM4311 802.11b/g WLAN" as ptr<u8>; }
        if device_id == 0x4322 { return "BCM4322 802.11a/b/g/n Wireless" as ptr<u8>; }
        if device_id == 0x4360 { return "BCM4360 802.11ac Wireless" as ptr<u8>; }
        if device_id == 0x1692 { return "NetLink BCM57780 Gigabit" as ptr<u8>; }
        if device_id == 0x4331 { return "BCM4331 802.11a/b/g/n" as ptr<u8>; }
        if device_id == 0x43A0 { return "BCM4360 802.11ac Wireless" as ptr<u8>; }
        return "Broadcom Communications" as ptr<u8>;
    }
    if vendor_id == 0x168C {
        if device_id == 0x002B { return "AR9285 Wireless Network Adapter" as ptr<u8>; }
        if device_id == 0x002E { return "AR9287 Wireless Network Adapter" as ptr<u8>; }
        if device_id == 0x0032 { return "AR9485 Wireless Network Adapter" as ptr<u8>; }
        if device_id == 0x003C { return "QCA986x/988x 802.11ac Wireless" as ptr<u8>; }
        if device_id == 0x0013 { return "AR5212/AR5213 Wireless Network Adapter" as ptr<u8>; }
        if device_id == 0x001C { return "AR2424 Wireless Network Adapter" as ptr<u8>; }
        if device_id == 0x0030 { return "AR9300 Wireless Network Adapter" as ptr<u8>; }
        if device_id == 0x003E { return "QCA6174 802.11ac Wireless" as ptr<u8>; }
        if device_id == 0x0042 { return "QCA9377 802.11ac Wireless" as ptr<u8>; }
        return "Atheros Wireless Device" as ptr<u8>;
    }
    if vendor_id == 0x1000 {
        if device_id == 0x0054 { return "MegaRAID SAS 2008" as ptr<u8>; }
        if device_id == 0x005B { return "MegaRAID SAS 2108" as ptr<u8>; }
        if device_id == 0x005D { return "MegaRAID SAS 2208" as ptr<u8>; }
        if device_id == 0x005F { return "MegaRAID SAS 3008" as ptr<u8>; }
        if device_id == 0x00cf { return "MegaRAID SAS 3108" as ptr<u8>; }
        return "LSI Logic Storage Controller" as ptr<u8>;
    }
    if vendor_id == 0x1102 {
        if device_id == 0x0002 { return "Sound Blaster Live! (EMU10K1)" as ptr<u8>; }
        if device_id == 0x0004 { return "Sound Blaster Audigy (EMU10K2)" as ptr<u8>; }
        if device_id == 0x0005 { return "Sound Blaster X-Fi" as ptr<u8>; }
        if device_id == 0x000A { return "Sound Blaster X-Fi Titanium" as ptr<u8>; }
        if device_id == 0x0012 { return "Sound Blaster Recon3D" as ptr<u8>; }
        return "Creative Audio Device" as ptr<u8>;
    }
    if vendor_id == 0x1011 {
        if device_id == 0x0009 { return "DECchip 21140 [FasterNet]" as ptr<u8>; }
        if device_id == 0x0019 { return "DECchip 21142/43" as ptr<u8>; }
        return "DEC Ethernet Controller" as ptr<u8>;
    }
    if vendor_id == 0x10B7 {
        if device_id == 0x9050 { return "3c905 100BaseTX" as ptr<u8>; }
        if device_id == 0x9055 { return "3c905B 100BaseTX" as ptr<u8>; }
        if device_id == 0x9200 { return "3c905C-TX/TX-M" as ptr<u8>; }
        return "3Com Fast Ethernet" as ptr<u8>;
    }
    if vendor_id == 0x11AB {
        if device_id == 0x4364 { return "88E8056 PCI-E Gigabit Ethernet" as ptr<u8>; }
        if device_id == 0x4380 { return "88E8057 PCI-E Gigabit Ethernet" as ptr<u8>; }
        if device_id == 0x9123 { return "88SE9123 PCIe SATA 6.0 Gb/s" as ptr<u8>; }
        if device_id == 0x9215 { return "88SE9215 PCIe SATA 6.0 Gb/s" as ptr<u8>; }
        return "Marvell Technology Device" as ptr<u8>;
    }
    if vendor_id == 0x1B21 {
        if device_id == 0x0612 { return "ASM1062 Serial ATA Controller" as ptr<u8>; }
        if device_id == 0x1042 { return "ASM1042 SuperSpeed USB Host" as ptr<u8>; }
        if device_id == 0x1142 { return "ASM1142 USB 3.1 Host" as ptr<u8>; }
        if device_id == 0x2142 { return "ASM2142 USB 3.1 Host" as ptr<u8>; }
        if device_id == 0x3242 { return "ASM3242 USB 3.2 Host" as ptr<u8>; }
        return "ASMedia Host Controller" as ptr<u8>;
    }
    if vendor_id == 0x1039 {
        if device_id == 0x0190 { return "SiS900 PCI Fast Ethernet" as ptr<u8>; }
        if device_id == 0x0191 { return "SiS191 Gigabit Ethernet" as ptr<u8>; }
        if device_id == 0x0180 { return "SiS180 SATA Controller" as ptr<u8>; }
        if device_id == 0x7012 { return "SiS7012 AC'97 Sound" as ptr<u8>; }
        if device_id == 0x7001 { return "SiS5597/5598/5600 USB UHCI" as ptr<u8>; }
        return "SiS Chipset Component" as ptr<u8>;
    }
    if vendor_id == 0x1106 {
        if device_id == 0x3065 { return "VT6102/VT6103 [Rhine-II]" as ptr<u8>; }
        if device_id == 0x3106 { return "VT6105/VT6106S [Rhine-III]" as ptr<u8>; }
        if device_id == 0x3119 { return "VT6120/VT6121/VT6122 Velocity Gigabit" as ptr<u8>; }
        if device_id == 0x3149 { return "VT6420 SATA RAID" as ptr<u8>; }
        if device_id == 0x3249 { return "VT6421 IDE RAID" as ptr<u8>; }
        if device_id == 0x0591 { return "VT82C598/694x [Apollo Pro]" as ptr<u8>; }
        if device_id == 0x3038 { return "VT82xxxxx UHCI USB 1.1" as ptr<u8>; }
        if device_id == 0x3104 { return "USB 2.0" as ptr<u8>; }
        if device_id == 0x3288 { return "VT8237A HD Audio Controller" as ptr<u8>; }
        if device_id == 0x3059 { return "VT8233/A/8235/8237 AC97 Audio" as ptr<u8>; }
        return "VIA Technologies Device" as ptr<u8>;
    }
    if vendor_id == 0x15B3 {
        if device_id == 0x1003 { return "MT27500 Family [ConnectX-3]" as ptr<u8>; }
        if device_id == 0x1013 { return "MT27700 Family [ConnectX-4]" as ptr<u8>; }
        if device_id == 0x1015 { return "MT27710 Family [ConnectX-4 Lx]" as ptr<u8>; }
        if device_id == 0x1017 { return "MT27800 Family [ConnectX-5]" as ptr<u8>; }
        if device_id == 0x101B { return "MT28908 Family [ConnectX-6]" as ptr<u8>; }
        return "Mellanox Network Adapter" as ptr<u8>;
    }
    if vendor_id == 0x121A {
        if device_id == 0x0001 { return "Voodoo Graphics" as ptr<u8>; }
        if device_id == 0x0002 { return "Voodoo 2" as ptr<u8>; }
        if device_id == 0x0003 { return "Voodoo Banshee" as ptr<u8>; }
        if device_id == 0x0004 { return "Voodoo 3" as ptr<u8>; }
        if device_id == 0x0005 { return "Voodoo 4/5" as ptr<u8>; }
        return "3Dfx Voodoo Accelerator" as ptr<u8>;
    }
    if vendor_id == 0x102B {
        if device_id == 0x0519 { return "MGA Millennium" as ptr<u8>; }
        if device_id == 0x051B { return "MGA Mystique" as ptr<u8>; }
        if device_id == 0x0521 { return "MGA G200" as ptr<u8>; }
        if device_id == 0x0525 { return "MGA G400/G450" as ptr<u8>; }
        if device_id == 0x2527 { return "MGA G550" as ptr<u8>; }
        return "Matrox Graphics" as ptr<u8>;
    }
    if vendor_id == 0x5333 {
        if device_id == 0x8811 { return "Trio32/64/64V+" as ptr<u8>; }
        if device_id == 0x8A01 { return "ViRGE/DX or /GX" as ptr<u8>; }
        if device_id == 0x8A22 { return "Savage 3D" as ptr<u8>; }
        if device_id == 0x8C10 { return "Savage/MX" as ptr<u8>; }
        if device_id == 0x8D04 { return "Savage4" as ptr<u8>; }
        if device_id == 0x8C2E { return "SuperSavage IX/C" as ptr<u8>; }
        return "S3 Graphics Device" as ptr<u8>;
    }
    
    return "Generic Peripheral Component" as ptr<u8>;
}
