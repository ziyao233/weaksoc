// SPDX-License-Identifier: MPL-2.0
/*
 *	Blink BROM for weaksoc
 *	Copyright (c) 2025 Yao Zi <ziyao@disroot.org>
 */

	.global	_start
_start:
	li		s0,		0x80000000
	sw		zero,		0(s0)
	li		s1,		1
.loop:
	li		t0,		6000000

.wait:
	addi		t0,		t0,		-1
	bnez		t0,		.wait

	not		s1,		s1
	sw		s1,		0(s0)

	j		.loop
