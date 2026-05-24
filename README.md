# 🌐 DNS Master Pro

**Advanced DNS Management Tool for Ubuntu 20+ & Modern Linux Distributions**

[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%2B-E95420?style=flat-square&logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Bash](https://img.shields.io/badge/Bash-5.0%2B-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)
[![Author](https://img.shields.io/badge/Author-Hossein_Shourgashti-purple?style=flat-square)](https://github.com/hosseinit1988)

---

## ✨ Features | ویژگی‌ها

🎨 Beautiful Interactive Menu with colorful interface
🚀 30+ Pre-configured DNS Providers (Shecan, Radar, Electro, Google, Cloudflare, AdGuard & more)
➕ Add Custom DNS permanently from the menu without editing script code
🔐 DNS-over-TLS (DoT) toggle support for encrypted DNS queries
🔄 One-Click Reset to default DHCP settings
💾 Automatic Backup before any DNS changes
🔍 Auto-Detect Network Interface (no manual configuration needed)
📊 Live Status Display of current DNS and DoT configuration
📁 Persistent Settings using systemd-resolved (survives reboots)

---

## 🆚 Why DNS Master Pro? | چرا DNS Master Pro؟

| Feature | DNS Master Pro | Typical Scripts |
|---------|:------------:|:---------------:|
| Method | resolvectl (systemd) | Direct file edit |
| Persistence | Survives reboots | May revert |
| Ubuntu 20+ | Fully optimized | Not optimized |
| DoT Support | Built-in toggle | Not available |
| Add Custom DNS | From menu | Edit source code |
| Auto Interface | Automatic | Manual |
| Backup | Automatic | Usually manual |
| Status Display | DNS + DoT live | Limited |

---

## 📋 Requirements | نیازمندی‌ها

Ubuntu 20.04, 22.04, 24.04 or later (primary target)
Any systemd-based Linux (Debian 11+, Fedora 33+, Arch)
Root privileges (sudo access required)
systemd-resolved service enabled (default on Ubuntu)
Bash 5.0+ (default on modern distributions)

---

## 🚀 Quick Start | شروع سریع

git clone https://github.com/hosseinit1988/DNS-Master-Pro.git
cd DNS-Master-Pro
chmod +x dns-master.sh
sudo ./dns-master.sh

wget https://raw.githubusercontent.com/hosseinit1988/DNS-Master-Pro/main/dns-master.sh
chmod +x dns-master.sh
sudo ./dns-master.sh

bash <(curl -s https://raw.githubusercontent.com/hosseinit1988/DNS-Master-Pro/main/dns-master.sh)

---

## 📖 Usage Guide | راهنمای استفاده

Press 1-30+ to select a pre-configured DNS provider
Press A to add your own custom DNS permanently
Press T to toggle DNS-over-TLS ON/OFF
Press R to reset to default DHCP settings
Press 0 to exit the program

---

## 🌍 DNS Providers | سرویس‌های DNS

Shecan, Radar, Electro, Begzar, DNS Pro, 403, MCI, MTN-Irancel, Rightel
Google, Cloudflare, Quad9, OpenDNS, AdGuard, Verisign, NTT, DNS-XBOX

---

## 👨‍💻 Author | نویسنده

**Hossein Shourgashti**
GitHub: github.com/hosseinit1988
Website: hetzner.com
Live In Linux | WebDesigner | SQL Administrator | Network Security

---

## 📝 License | مجوز

MIT License - see LICENSE file for details

---

Made with ❤️ by Hossein Shourgashti
