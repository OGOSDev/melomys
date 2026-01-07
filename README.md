
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



## Build Instructions

### Prerequisites

Before building Melomys OS, you need a few basic tools to assemble code and package a UEFI-compliant ISO:

- NASM (assembler)  
- QEMU (emulator)  
- xorriso and mtools (for creating EFI system partitions and iso)  
- git (to clone repo)  

**On arch linux**:

```bash
sudo pacman -S git nasm qemu-desktop xorriso mtools
````

**On debian, ubuntu or linux mint**:

```bash
sudo apt update
sudo apt install git nasm qemu-system-x86 xorriso mtools
```



### Clone the Repository

Clone the project to your local machine and enter the folder:

```bash
git clone https://github.com/OGOSDev/melomys.git
cd melomys
```



### Building and Running

* To build and run the OS:

```bash
make all
```

* To build only :

```bash
make build
```

* To run an existing iso:

```bash
make run
```

* To clean all generated binaries:

```bash
make clean
```
