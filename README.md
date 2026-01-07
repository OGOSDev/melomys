
## Melomys OS

Melomys OS is an educational and hobby x86-64 operating system, designed not to be the fastest or the smallest, but to serve as a learning resource for newcomers and a point of reference for more experienced developers.

Copyright (C) 2007-2017 Return Infinity
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
## Questions

<details>
  <summary>What makes Melomys OS different from other operating systems?</summary>
  
Melomys OS is primarily for learning. Every single chunk/line of code is explained in detail with **heavily** commented. The goal is make it everything clear that you don't have to ask LLM and use your brain for once.
</details>

<details>
  <summary>Is it worth making an OS in assembly?</summary>
  
No. modern compilers and languages handle most tasks more efficiently and safely than handwritten assembly. More on doc.
</details>

<details>
  <summary>Why use assembly at all?</summary>
  
Learning assembly gives you a better understanding of how computers work. This knowledge makes it easier to work with mid and higher level languages and the understanding you gain are valuable for any developer, not just those writing lowlevel code.
</details>


<details>
  <summary>Can I use this OS for real-world applications?</summary>
  
Not really(at least for now). Melomys OS is an educational project designed to demonstrate low level concepts, but it is far from being a fully usable operating system.
</details>

<details>
  <summary>How does this help me learn OS development?</summary>
  
By reading the heavily commented source and experimenting with the code, you will gain practical understanding of UEFI, 64 bit kernels, paging, SMP and hardware initialization all concepts that most tutorials skip or oversimplify.
</details>

<details>
  <summary>Do you continue developing it?</summary>
  
Yes
</details>

<details>
  <summary>Any future ideas?</summary>
  
The goal is to take Melomys OS to the next level of being a full OS. While I can't list all planned features right now, I aim to continue the documentation that I paused earlier explaining the system as if developing it from scratch, to make it clear and understandable for everyone.
</details>
