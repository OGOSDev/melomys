
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
  
Using assembly gives insight into exactly how a CPU, memory and hardware interact. Even if higher level languages can accomplish the same tasks more easily, writing in assembly exposes the mechanics behind every instruction—essential for understanding low-level systems.
</details>

<details>
  <summary>Who is this project for?</summary>
  
Beginners who want to see how modern PCs boot and execute code, and intermediate developers who want a transparent, inspectable reference for low-level x86-64 programming.
</details>

<details>
  <summary>Do I need a specific environment to run this OS?</summary>
  
No special hardware is required. You can build and run Melomys OS on any Linux system using standard tools like NASM, QEMU, and ISO utilities.
</details>

<details>
  <summary>Can I use this OS for real-world applications?</summary>
  
Not really. Melomys OS is an educational platform. It demonstrates concepts, but it is not optimized or secure enough for production use.
</details>

<details>
  <summary>How does this help me learn OS development?</summary>
  
By reading the heavily commented source, following the step-by-step architecture, and experimenting with the code, you gain practical understanding of UEFI booting, 64-bit kernels, paging, SMP, and hardware initialization—all concepts that most tutorials skip or oversimplify.
</details>

<details>
  <summary>Do you continue developing it?</summary>
  
Yes, development is ongoing. The OS will continue to evolve as a learning resource and reference.
</details>

<details>
  <summary>Any future ideas?</summary>
  
The goal is to take Melomys OS to the next level of being a full OS. While I can't list all planned features right now, I aim to continue the documentation that I paused earlier—explaining the system as if developing it from scratch, to make it clear and understandable for everyone.
</details>
