#!/usr/bin/env python3
"""
ZeroFox attestation roundtrip test.

Replicates the ZeroFox browser's ECIES token generation (patch 006) and
validates the full path: test client → HAProxy (Lua verifier) → httpd.

Requirements:
    pip install cryptography requests

Usage (from repo root):
    scripts/gen-attest-key.sh
    docker compose -f test/attestation/docker-compose.yml up --build -d
    python3 test/attestation/test_roundtrip.py
"""

import base64
import os
import sys
import time

import requests
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric.ec import (
    ECDH,
    SECP256R1,
    generate_private_key,
)
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.x963kdf import X963KDF

HAPROXY_URL     = os.environ.get("HAPROXY_URL",     "http://localhost:8080")
PUBLIC_KEY_PATH = os.environ.get("PUBLIC_KEY_PATH", "build/haproxy-public.pem")


def _load_public_key(path):
    with open(path, "rb") as f:
        return serialization.load_pem_public_key(f.read())


def _make_token(pub_key, ts_str, host):
    """Mirror ZeroFoxAttest.cpp AddAttestHeaders() — ECIES encrypt."""
    ephem_priv = generate_private_key(SECP256R1())
    Z          = ephem_priv.exchange(ECDH(), pub_key)
    aes_key    = X963KDF(algorithm=hashes.SHA256(), length=16, sharedinfo=None).derive(Z)
    iv         = os.urandom(12)
    plaintext  = f"zerofox-attest:{ts_str}:{host}".encode()
    ct_tag     = AESGCM(aes_key).encrypt(iv, plaintext, None)
    ephem_pub_bytes = ephem_priv.public_key().public_bytes(
        serialization.Encoding.X962,
        serialization.PublicFormat.UncompressedPoint,
    )
    return base64.b64encode(ephem_pub_bytes + iv + ct_tag).decode()


def _run(pub_key):
    host   = "localhost"
    passed = failed = 0

    def check(label, *, headers, expect):
        nonlocal passed, failed
        try:
            r = requests.get(HAPROXY_URL, headers=headers, timeout=5)
            if r.status_code == expect:
                print(f"  PASS  {label}  (HTTP {r.status_code})")
                passed += 1
            else:
                print(f"  FAIL  {label}  (expected {expect}, got {r.status_code})")
                failed += 1
        except Exception as exc:
            print(f"  ERROR {label}: {exc}")
            failed += 1

    ts = str(int(time.time()))

    check("Valid token",
          headers={"Host": host, "X-ZeroFox-Ts": ts,
                   "X-ZeroFox-Token": _make_token(pub_key, ts, host)},
          expect=200)

    check("Missing both attestation headers",
          headers={"Host": host},
          expect=403)

    check("Missing X-ZeroFox-Token",
          headers={"Host": host, "X-ZeroFox-Ts": ts},
          expect=403)

    check("Random (invalid) token bytes",
          headers={"Host": host, "X-ZeroFox-Ts": ts,
                   "X-ZeroFox-Token": base64.b64encode(os.urandom(93)).decode()},
          expect=403)

    stale = str(int(time.time()) - 90)
    check("Stale timestamp (90s ago, window is 30s)",
          headers={"Host": host, "X-ZeroFox-Ts": stale,
                   "X-ZeroFox-Token": _make_token(pub_key, stale, host)},
          expect=403)

    check("Token encrypted for wrong host",
          headers={"Host": host, "X-ZeroFox-Ts": ts,
                   "X-ZeroFox-Token": _make_token(pub_key, ts, "evil.example.com")},
          expect=403)

    ahead = str(int(time.time()) + 10)
    check("Future timestamp within 30s window",
          headers={"Host": host, "X-ZeroFox-Ts": ahead,
                   "X-ZeroFox-Token": _make_token(pub_key, ahead, host)},
          expect=200)

    print(f"\n  {passed} passed, {failed} failed")
    return failed == 0


if __name__ == "__main__":
    if not os.path.exists(PUBLIC_KEY_PATH):
        print(f"ERROR: public key not found at {PUBLIC_KEY_PATH}")
        print("Run scripts/gen-attest-key.sh first.")
        sys.exit(1)

    pub_key = _load_public_key(PUBLIC_KEY_PATH)
    print(f"Public key : {PUBLIC_KEY_PATH}")
    print(f"HAProxy    : {HAPROXY_URL}\n")

    sys.exit(0 if _run(pub_key) else 1)
