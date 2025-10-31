# Linux System Menu

Interactive **Bash** script for managing, diagnosing, and installing Linux systems — supporting multiple distributions and an automatic installation mode for **Arch Linux**.

Developed by **Rx4n**, this project aims to offer a simple and fast interface to facilitate system administration, driver installation, and maintenance tasks.

---

## 🚀 Main Features

### 🧩 Main Menu
- Update system (`apt`, `pacman`, `dnf`, `zypper`)
- Clear cache and orphaned packages
- Hardware and system reports (`lscpu`, `lsblk`, `sensors`, etc.)
- View storage usage
- Automatically install drivers (AMD, Intel, NVIDIA)
- Check and install necessary packages
- Automatically install **Arch Linux**

---

## ⚙️ Compatibility

The script automatically detects the **package manager** (pacman, apt, dnf, zypper) and executes the correct commands according to the system.

---

## 🧠 Installation and Use

### 1️⃣ Clone the repository
```bash
git clone https://github.com/<seu-usuario>/linux-system-menu.git
cd linux-system-menu
```
### 2️⃣ Grant execute permission
```bash
chmod +x linux_system_menu.sh
```
### 3️⃣ Run the menu
```bash
./linux_system_menu.sh
```
---

## 🖥️ Extra Option – Arch Auto Installer (NOT TESTED!)
Automatic and complete Arch Linux installer, including:
Automatic partitioning and formatting (root, swap, home)
Base installation with pacstrap
Locale, timezone, network, and GRUB configuration
User creation with configured sudo
Complete installation log in /logs/

## ⚠️ Use only in Arch Linux live environments, as the installer erases the selected disk. ⚠️

---

### 📜 License
This project is licensed under the MIT License — you may freely use, modify, and distribute it with proper attribution.

---

## 👤 Author | **Rx4n**
💻 Full Stack Developer & Linux Systems Enthusiast
- 📧 **Email:** [rx4n.rx4n@gmail.com](mailto:rx4n.rx4n@gmail.com)  
- 🌐 **Portfolio:** [rian-batista-rx4n.github.io/rian-batista](https://rian-batista-rx4n.github.io/rian-batista/)  
- 🧑‍💻 **GitHub:** [github.com/Rian-Batista-Rx4n](https://github.com/Rian-Batista-Rx4n)  
- 💼 **LinkedIn:** [linkedin.com/in/rian-batista](https://www.linkedin.com/in/rian-batista/) 
