# W Kernel: An Experimental Bare-Metal x86_64 Kernel

W Kernel, modern işletim sistemi teorilerini, mikromimari düzeyde donanım kontrolünü ve çekirdek seviyesinde (Ring 0) proaktif güvenliği test etmek amacıyla sıfırdan geliştirilmiş deneysel bir x86_64 monolitik çekirdek (kernel) projesidir.

Projenin en ayırt edici özelliği, tip güvenliği (type-safety) ve düşük seviyeli bellek kontrolünü bir arada sunan **özelleştirilmiş "W" sistem programlama dili** ile implement edilmiş olmasıdır.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Stage](https://img.shields.io/badge/Stage-Pre--Alpha%20Beta-orange.svg)]()
[![Target](https://img.shields.io/badge/Architecture-x86__64%20%2F%20Bare--Metal-green.svg)]()

---

## 🔬 Teknik Mimari ve Çekirdek Yetenekleri

### 1. Bellek Yönetimi & Sayfalama (Memory Management)
* **Alt Yapı Katmanı:** PMM (Physical Memory Manager), GDT (Global Descriptor Table) ve IDT (Interrupt Descriptor Table) mimarileri x86_64 uzun mod (Long Mode) standartlarına tam uyumlu olarak sıfırdan haritalanmıştır.
* **CowBlock (Copy-on-Write) Mekanizması:** Bellek verimliliğini optimize etmek amacıyla, alt süreçler ve bellek blokları arasında referans sayacı (reference counting) tabanlı Copy-on-Write mimarisi entegre edilmiştir.

### 2. Aegis-X Yerleşik Güvenlik Alt Sistemi (Kernel-Space Security)
Sistem güvenliği, kullanıcı alanındaki (User-Space) bir antivirüs yazılımına bırakılmayarak doğrudan Ring 0 içerisine gömülmüştür:
* **Canlı Bellek Taraması:** `av_monitor_process` alt rutini, aktif süreçlerin (processes) bellek haritalarını (memory maps) anomali ve bilinen zararlı imzalarına karşı sürekli denetler.
* **Kernel Enforcements:** Herhangi bir imza eşleşmesi durumunda, çekirdek doğrudan `AEGIS-AV ALERT` üreterek ilgili süreci kernel seviyesinden `SIGKILL` sinyaliyle kalıcı olarak izole eder ve sonlandırır.

### 3. Donanım Soyutlama Katmanı & Sürücü Matrisi (HAL)
Çekirdek, legacy ve modern donanımlarla doğrudan satır içi assembly (`asm`) blokları, `cpuid` ve `rdmsr/wrmsr` mimari yazmaçları (MSR) üzerinden haberleşir:
* **PCI Probing:** Donanım Kimlikleri (Vendor/Device ID) üzerinden otomatik aygıt tarama ve tanımlama.
* **Grafik Sürücüleri:** Legacy ve retro donanım uyumluluğu için genişletilmiş chipset desteği:
  * *3dfx Voodoo Serisi:* Voodoo Graphics, Voodoo 2, Banshee, Voodoo 3, Voodoo 4/5 donanımsal hızlandırma hazırlığı.
  * *Matrox MGA Serisi:* Millennium, Mystique, G200, G400/G450, G550 mimari desteği.
  * *Cirrus Logic:* Standart VGA/SVGA fallback emülasyonu.
* **Giriş/Çıkış ve Ağ:** XHCI USB denetleyici kuyruk yönetimi ve Mellanox Ağ Adaptörleri için veri hattı katmanı.

### 4. İleri Düzey Çekirdek İçi Alt Sistemler
* **Tensor Matematik Çekirdeği:** Çekirdek seviyesinde matris ve tensör operasyonlarını optimize edilmiş döngülerle çalıştıran dahili `tensor_matmul` motoru.
* **Ağ Yığını:** Veri paketlerinin hatasız iletimi için donanım katmanıyla doğrudan bağlı ham TCP/IP segment yönetim mekanizması (`tcp_send_segment`).
* **Veri Ayrıştırma:** Yapılandırılmış sistem konfigürasyonlarını doğrudan Ring 0'da işlemek için yerleşik DOM Parser mimarisi.

---

## 🛠️ Toolchain ve Derleme Pipeline'ı

W Çekirdeği, çok aşamalı bir derleme hattı (pipeline) kullanır. İşlemcinin boot anındaki ilk durumunu hazırlayan assembly kodları ile üst seviye W dili nesne dosyaları seviyesinde bağlanır.

### Gereksinimler
* `nasm` (Netwide Assembler - x86_64 kesme ve boot hazırlığı için)
* `w_compiler` (Özel W Dili Derleyicisi)
* `x86_64-elf-ld` (Cross-Linker)
* `QEMU` (Emülasyon ve test ortamı)

### Otomasyon (C Build Engine)
Projeyi derlemek için `Makefile` yerine platform bağımsız çalışan, projenin kendi C tabanlı derleme motoru (`build.c`) kullanılır.

```bash
# Derleme motorunu hazır hale getirin
g++ build.c -o build

# Tüm alt sistemleri derleyin ve linkleyin
./build
```

### El ile Derleme Adımları
```bash
# 1. Boot katmanının asamble edilmesi
nasm -f elf64 boot.asm -o boot.o

# 2. W dili kaynak kodlarının nesne koduna dönüştürülmesi
w_compiler kernel.w -o kernel.o

# 3. Nesne dosyalarının linker script mimarisine göre bağlanması
x86_64-elf-ld -n -T linker.ld -o kernel.bin boot.o kernel.o

# 4. QEMU üzerinde sihirli anın başlatılması
qemu-system-x86_64 -kernel kernel.bin -m 512M
```

---

## 📜 Lisans

Bu proje **GNU General Public License v3 (GPLv3)** ile lisanslanmıştır. W Çekirdeği'nin kaynak kodlarını kullanan, değiştiren veya bu projeden türetilen tüm projelerin, türetilen yeni kodu da **GPLv3 uyarınca tamamen açık kaynaklı** ve özgür olarak paylaşması yasal bir zorunluluktur.

---
<p align="center"><i>Developed and maintained under the vision of YBG13™ Technologies.</i></p>
