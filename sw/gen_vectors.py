#!/usr/bin/env python3
"""Generate test vectors for the Keccak-512 core (original Keccak padding, 0x01)."""
import random
import sys

M64 = (1 << 64) - 1

RC = [
    0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000,
    0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
    0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
    0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
    0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
    0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
]
R = [  # rotation offsets R[x][y]
    [0, 36, 3, 41, 18], [1, 44, 10, 45, 2], [62, 6, 43, 15, 61],
    [28, 55, 25, 21, 56], [27, 20, 39, 8, 14],
]

def rol(v, n):
    n %= 64
    return ((v << n) | (v >> (64 - n))) & M64 if n else v

def keccak_f(A):  # A: 25 lanes, index x + 5*y
    for rc in RC:
        C = [A[x] ^ A[x+5] ^ A[x+10] ^ A[x+15] ^ A[x+20] for x in range(5)]
        D = [C[(x-1) % 5] ^ rol(C[(x+1) % 5], 1) for x in range(5)]
        A = [A[i] ^ D[i % 5] for i in range(25)]
        B = [0] * 25
        for x in range(5):
            for y in range(5):
                B[y + 5*((2*x + 3*y) % 5)] = rol(A[x + 5*y], R[x][y])
        A = [B[x + 5*y] ^ ((~B[(x+1) % 5 + 5*y]) & B[(x+2) % 5 + 5*y] & M64)
             for y in range(5) for x in range(5)]
        A[0] ^= rc
    return A

def keccak512(msg, pad=0x01):
    """pad=0x01: original Keccak (this core). pad=0x06: FIPS 202 SHA3-512."""
    rate = 72
    m = bytearray(msg); m.append(pad)
    while len(m) % rate: m.append(0)
    m[-1] |= 0x80
    A = [0] * 25
    for off in range(0, len(m), rate):
        for i in range(rate // 8):
            A[i] ^= int.from_bytes(m[off+8*i: off+8*i+8], "little")
        A = keccak_f(A)
    return b"".join(A[i].to_bytes(8, "little") for i in range(8))

def self_check():
    import hashlib
    fox = b"The quick brown fox jumps over the lazy dog"
    assert keccak512(fox).hex().startswith("d135bb84d0439dba")
    assert keccak512(fox + b".").hex().startswith("ab7192d2b11f51c7")
    assert keccak512(b"").hex().startswith("0eab42de4c3ceb92")
    rng = random.Random(0)
    for n in list(range(0, 200)) + [rng.randrange(0, 1000) for _ in range(50)]:
        d = rng.randbytes(n)
        assert keccak512(d, 0x06) == hashlib.sha3_512(d).digest(), n

def main():
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    self_check()
    rng = random.Random(seed)
    lengths = list(range(0, 301)) + [rng.randrange(301, 700) for _ in range(150)]
    msgs = [rng.randbytes(n) for n in lengths]
    with open("lens.hex", "w") as f:           # line 0 = count, then one length per line
        f.write(f"{len(lengths):x}\n")
        for n in lengths: f.write(f"{n:x}\n")
    with open("msgs.hex", "w") as f:           # all bytes back to back
        for m in msgs:
            for b in m: f.write(f"{b:02x}\n")
    with open("digests.hex", "w") as f:        # 128 hex chars per line
        for m in msgs: f.write(keccak512(m).hex() + "\n")
    print(f"wrote {len(lengths)} vectors, {sum(lengths)} bytes (seed {seed})")

if __name__ == "__main__":
    main()