## Melomys OS

Melomys OS is an educational and hobby x86-64 operating system, designed not to be the fastest or the smallest, but to serve as a learning resource for newcomers and a point of reference for more experienced devs.

### Features

- **Memory Management and Paging**
- **Symmetric Multiprocessing (SMP)**
- **ACPI Parsing (RSDP/XSDT, MADT)**
- **Local APIC**
- **HPET Initialization**
- **GDT and IDT**
- **Linear Framebuffer Graphics**

  

````md
## Build 


---

### Prerequisites

Melomys OS requires the following tools:

- NASM – assembler  
- QEMU – emulator  
- xorriso and mtools – ISO and EFI system partition utils  
- git – to clone the repo  

#### Arch Linux

```bash
sudo pacman -S git nasm qemu-desktop xorriso mtools
````

#### Debian / Ubuntu / Linux Mint

```bash
sudo apt update
sudo apt install git nasm qemu-system-x86 xorriso mtools
```

---

### Clone


```bash
git clone https://github.com/OGOSDev/melomys.git
cd melomys
```

---

### Build

#### Common Commands

| Command         | Action                      |
| --------------- | --------------------------- |
| `./build all`   | Build and run               |
| `./build build` | Build only                  |
| `./build run`   | Only run                    |
| `./build clean` | Removes all binary files    |

---

The build system is intentionally simple, fast, and fully inspectable, making it easy to understand how raw assembly becomes a bootable operating system.

```

If you want, the next logical upgrade is a **“Project Layout”** section that explains what each `.asm` file does without drowning the reader.
```
