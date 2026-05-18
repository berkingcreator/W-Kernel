# 🚀 W Kernel

Sıfırdan geliştirilmiş, donanım seviyesi kontrol ve yerleşik siber güvenlik odaklı yenilikçi bir işletim sistemi çekirdeği (Kernel).

![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Version](https://img.shields.io/badge/Version-0.0.1--beta-orange.svg)
![Architecture](https://img.shields.io/badge/Architecture-x86__64-green.svg)

**W Kernel**, modern işletim sistemi teorilerini güvenli bir mimariyle birleştiren, bellek yönetiminden ağ yığınına, gelişmiş grafik sürücülerinden donanımsal yapay zeka hızlandırmaya kadar geniş yeteneklere sahip bir projedir.

---

## 🛡️ Öne Çıkan Özellikler

### 1. Aegis-X Güvenlik Motoru (Core Security)
Çekirdeğin tam kalbine entegre edilmiş proaktif bir koruma sistemidir:
* **Bellek Haritalama Taraması:** `av_monitor_process` fonksiyonu ile çalışan süreçlerin bellek uzaylarını canlı olarak analiz eder.
* **Anında Müdahale (SIGKILL):** Şüpheli ve zararlı aktiviteleri tespit ettiği anda `AEGIS-AV ALERT` üreterek süreci kernel seviyesinde kalıcı olarak sonlandırır.

### 2. Bellek Mimarisi & Yönetimi
* **Temel Yapı Taşları:** PMM (Physical Memory Manager), GDT (Global Descriptor Table) ve IDT (Interrupt Descriptor Table) yapılandırmaları sıfırdan kurgulanmıştır.
* **CowBlock Teknolojisi:** Bellek verimliliğini maksimuma çıkarmak için referans sayacı (reference counting) destekli Copy-on-Write mimarisi.

### 3. Zengin Sürücü ve Donanım Katmanı
Geniş bir donanım yelpazesiyle doğrudan satır içi assembly (`asm`) blokları, `cpuid` ve `rdmsr` komutları üzerinden haberleşme:
* **USB Kontrolü:** Modern sistemler için XHCI USB kuyruk yönetimi.
* **Grafik Kartları:** 3dfx Voodoo (Graphics, 2, Banshee, 3, 4/5), Matrox MGA (Millennium, Mystique, G200, G400/G450, G550) ve Cirrus Logic desteği.
* **Ağ ve Ses:** Mellanox Network Adaptörleri ile eski ve modern ses kartı yongaları için entegre sürücüler.

### 4. Gelişmiş Kernel Yetenekleri
* **Matematik Çekirdeği:** Kernel seviyesinde veri işleme için optimize edilmiş `tensor_matmul` matris çarpım motoru.
* **Ağ Yığını:** Veri paketlerinin güvenli iletimi için özelleştirilmiş dahili TCP/IP yığını (`tcp_send_segment`).
* **Veri Ayrıştırma:** Çekirdek düzeyinde yapılandırılmış yerleşik DOM Parser.

---

## 🛠️ Derleme ve Çalıştırma

Projeyi yerel ortamınızda derlemek ve test etmek için aşağıdaki adımları takip edebilirsiniz:

### Gereksinimler
* `x86_64-elf-gcc` veya uyumlu derleme araçları
* `nasm` (Assembly derleyicisi için)
* `QEMU` (Emülasyon için)

### Çalıştırma Komutları
```bash
# Projeyi derleyin
make build

# Çekirdeği QEMU üzerinde test edin
qemu-system-x86_64 -kernel kernel.w -m 512M
```

---

## 🤝 Katkıda Bulunma (Contributing)

W Kernel, geliştirici topluluğunun katkılarına açıktır! Eğer projeye katkı sağlamak, yeni bir sürücü eklemek veya Aegis-X motorunu geliştirmek isterseniz:
1. Bu repoyu **Fork** edin.
2. Yeni bir özellik dalı açın (`git checkout -b feature/yeniozellık`).
3. Değişikliklerinizi commit edin (`git commit -m 'feat: yeni sürücü eklendi'`).
4. Dalınızı push edin (`git push origin feature/yeniozellık`).
5. Bir **Pull Request** oluşturun.

---

## 📜 Lisans

Bu proje **GNU GPLv3 (General Public License v3)** altında lisanslanmıştır. Bu lisans uyarınca, projenin kodlarını kullanan, değiştiren veya dağıtan her projenin de kaynak kodlarını **açık kaynaklı** olarak paylaşması zorunludur. Detaylar için `LICENSE` dosyasına göz atabilirsiniz.

---

<p align="center">YBG13™ Teknolojisi ile geliştirilmiştir.</p>
