
## Melomys OS

Melomys OS is an educational and hobby x86-64 operating system, designed not to be the fastest or the smallest, but to serve as a learning resource for newcomers and a point of reference for more experienced developers.

### Features

- Memory Management and Paging  
- Symmetric Multiprocessing (SMP)  
- ACPI Parsing (RSDP/XSDT, MADT)  
- Local APIC  
- HPET Initialization  
- GDT and IDT  
- Linear Framebuffer Graphics  

---

## Build Instructions

### Prerequisites

Before building Melomys OS, you need a few basic tools to assemble code and package a UEFI-compliant ISO:

- NASM (assembler)  
- QEMU (emulator for testing)  
- xorriso and mtools (for creating EFI System Partitions and ISOs)  
- git (to clone the repository)  

**On Arch Linux**, install the required packages with:

```bash
sudo pacman -S git nasm qemu-desktop xorriso mtools
````

**On Debian, Ubuntu, or Linux Mint**, update your package lists and install the tools:

```bash
sudo apt update
sudo apt install git nasm qemu-system-x86 xorriso mtools
```

---

### Clone the Repository

Clone the project to your local machine and enter the folder:

```bash
git clone https://github.com/OGOSDev/melomys.git
cd melomys
```

---

### Building and Running

* To build and run the OS in QEMU:

```bash
make all
```

* To build only :

```bash
make build
```

* To run an existing iso in QEMU:

```bash
make run
```

* To clean all generated binaries and start fresh:

```bash
make clean
```

The build system is simple, fast, and fully transparent, making it easy to follow each step from raw assembly to a bootable operating system.

```


