// SPDX-License-Identifier: MPL-2.0
/*
 *	Blink BROM for weaksoc
 *	Copyright (c) 2025 Yao Zi <ziyao@disroot.org>
 */

	.global	_start
_start:
	li		t0,		0x90000008
	li		t1,		325
	sw		t1,		0(t0)

	lla		a0,		msg
	call		print_log

	li		s0,		0x90000000

.loop:
	lw		t0,		0xc(s0)
	andi		t0,		t0,		0x2
	beqz		t0,		.loop

	lw		t1,		0x4(s0)

.wait_idle_1:
	lw		t0,		0xc(s0)
	andi		t0,		t0,		0x1
	beqz		t0,		.wait_idle_1

	sw		t1,		0x0(s0)

	j		.loop

print_log:
	li		t0,		0x90000000
.write:
	lb		t1,		0(a0)
	beqz		t1,		done

.wait_idle:
	lb		t2,		0xc(t0)
	andi		t2,		t2,		0x1
	beqz		t2,		.wait_idle

	sw		t1,		0(t0)

	addi		a0,		a0,		1
	j		.write
done:
	ret

msg:	.asciz		"Booting...\n\r"
