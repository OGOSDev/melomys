#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin="${root}/bin"
src="${root}/src"
loader="${src}/loader"
kernel="${root}/kernel/kernel.asm"

# Firmware
ovmf_code="firmware/OVMF_CODE.4m.fd"
ovmf_vars="firmware/OVMF_VARS.4m.fd"

# Outputs
iso="${root}/melomys.iso"

needed_tools() {
	for tool in "$@"; do
		command -v "${tool}" >/dev/null 2>&1 || {
			echo "Missing tool: ${tool}"
			exit 1
		}
	done
}

assemble_pure64() {
	echo "Assembling second stage loader..."
	nasm -DUEFI=1 \
		-I "${src}/" \
		"${loader}/ssloader.asm" \
		-o "${bin}/ssloader.sys"
}

assemble_bootstrap() {
	echo "Assembling the bootloader..."
	nasm -I "${src}/" \
		"${loader}/bootloader.asm" \
		-o "${bin}/bootloader.sys"
}

assemble_kernel() {
	echo "Assembling kernel..."
	nasm "${kernel}" -o "${bin}/kernel.sys"
}

package_payload() {
	echo "loader + kernel..."
	cat "${bin}/ssloader.sys" \
	    "${bin}/kernel.sys" \
	    > "${bin}/payload.sys"

	cp "${bin}/bootloader.sys" "${bin}/BOOTX64.EFI"

	# Inject payload at offset 4096
	dd if="${bin}/payload.sys" \
	   of="${bin}/BOOTX64.EFI" \
	   bs=4096 seek=1 conv=notrunc status=none
}

create_iso_image() {
	echo "creating iso..."

	needed_tools mkfs.vfat mmd mcopy xorriso mktemp

	ESP_IMG="$(mktemp --suffix=.img)"
	trap 'rm -f "${ESP_IMG}"' EXIT

	truncate -s 64M "${ESP_IMG}"
	mkfs.vfat -F 32 -n "melomys" "${ESP_IMG}" >/dev/null

	mmd -i "${ESP_IMG}" ::/EFI || true
	mmd -i "${ESP_IMG}" ::/EFI/BOOT || true

	mcopy -i "${ESP_IMG}" \
		"${bin}/BOOTX64.EFI" \
		::/EFI/BOOT/BOOTX64.EFI

	mkdir -p "${bin}/iso_root"

	xorriso -as mkisofs \
		-o "${iso}" \
		-R -f \
		-e "$(basename "${ESP_IMG}")" \
		-no-emul-boot \
		"${bin}/iso_root" \
		"${ESP_IMG}"
}

prepare_ovmf_vars() {
	if [ ! -f "${ovmf_code}" ] || [ ! -f "${ovmf_vars}" ]; then
		echo "No ovmf in ${bin}"
		exit 1
	fi
}

build() {
	needed_tools nasm cat dd xorriso
	mkdir -p "${bin}"

	assemble_pure64
	assemble_bootstrap
	assemble_kernel
	package_payload
	create_iso_image

	echo "DONE: building!"
	echo "  ${iso}"
}

run_qemu() {
	prepare_ovmf_vars

	qemu-system-x86_64 \
		-machine q35 \
		-m 256 \
		-cpu qemu64 \
		-drive if=pflash,format=raw,readonly=on,file="${ovmf_code}" \
		-drive if=pflash,format=raw,file="${ovmf_vars}" \
		-serial stdio \
		-cdrom "${iso}" \
		-device VGA,edid=on
}

case "${1:-}" in
	build) build ;;
	run) run_qemu ;;
	all) build && run_qemu ;;
	clean) rm -rf "${bin}" && rm "${root}/melomys.iso" ;;
	*) echo "Usage: $0 {build|run|all|clean}" ;;
esac

