"""Developer signatures for .nxvapp packages: ECDSA on NIST P-256 with SHA-256, in pure Python (no extra packages).

Used by tools/nxvapp_keygen.py and tools/nxvapp_pack.py (--sign / --verify). Format (docs/NXVAPP_FORMAT.md, "Signing"):

    manifest.sig = {"alg": "ECDSA-P256-SHA256",
                    "key": "<base64 of the 65-byte uncompressed public key 04||X||Y>",
                    "sig": "<base64 of the DER signature over SHA-256(manifest.sha256)>"}

The fingerprint shown by Nexvyn OS ("Signed by AB12:CD34:EF56:7890") is the first 8 bytes of SHA-256(public key).
Keys are PEM files: "EC PRIVATE KEY" (SEC1, what `openssl ecparam -genkey -name prime256v1` writes) or "PRIVATE KEY"
(PKCS#8, `openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256`).
"""
import base64
import hashlib
import hmac
import json
import secrets

# NIST P-256 (secp256r1)
P = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF
A = P - 3
B = 0x5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B
N = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551
G = (0x6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296,
     0x4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5)
OID_EC_PUBLIC_KEY = bytes.fromhex("2a8648ce3d0201")
OID_P256 = bytes.fromhex("2a8648ce3d030107")
ALG = "ECDSA-P256-SHA256"


# ---------------------------------------------------------------- curve arithmetic (Jacobian coordinates)
def _to_jac(pt):
    return None if pt is None else (pt[0], pt[1], 1)


def _from_jac(j):
    if j is None or j[2] == 0:
        return None
    zi = pow(j[2], -1, P)
    zi2 = zi * zi % P
    return (j[0] * zi2 % P, j[1] * zi2 * zi % P)


def _jdouble(j):
    if j is None:
        return None
    x, y, z = j
    if y == 0:
        return None
    ysq = y * y % P
    s = 4 * x * ysq % P
    zz = z * z % P
    m = (3 * x * x + A * zz * zz) % P
    nx = (m * m - 2 * s) % P
    ny = (m * (s - nx) - 8 * ysq * ysq) % P
    nz = 2 * y * z % P
    return (nx, ny, nz)


def _jadd(p, q):
    if p is None:
        return q
    if q is None:
        return p
    x1, y1, z1 = p
    x2, y2, z2 = q
    z1z1 = z1 * z1 % P
    z2z2 = z2 * z2 % P
    u1 = x1 * z2z2 % P
    u2 = x2 * z1z1 % P
    s1 = y1 * z2 * z2z2 % P
    s2 = y2 * z1 * z1z1 % P
    if u1 == u2:
        return _jdouble(p) if s1 == s2 else None
    h = (u2 - u1) % P
    r = (s2 - s1) % P
    hh = h * h % P
    hhh = h * hh % P
    v = u1 * hh % P
    nx = (r * r - hhh - 2 * v) % P
    ny = (r * (v - nx) - s1 * hhh) % P
    nz = h * z1 * z2 % P
    return (nx, ny, nz)


def mul(k, pt=G):
    acc = None
    add = _to_jac(pt)
    while k > 0:
        if k & 1:
            acc = _jadd(acc, add)
        add = _jdouble(add)
        k >>= 1
    return _from_jac(acc)


def on_curve(pt):
    x, y = pt
    return 0 <= x < P and 0 <= y < P and (y * y - (x * x * x + A * x + B)) % P == 0


# ---------------------------------------------------------------- encodings
def pub_bytes(pt):
    return b"\x04" + pt[0].to_bytes(32, "big") + pt[1].to_bytes(32, "big")


def pub_from_bytes(b):
    if len(b) != 65 or b[0] != 4:
        raise ValueError("public key must be 65 bytes, uncompressed (04||X||Y)")
    pt = (int.from_bytes(b[1:33], "big"), int.from_bytes(b[33:], "big"))
    if not on_curve(pt):
        raise ValueError("public key is not on P-256")
    return pt


def fingerprint(pub):
    h = hashlib.sha256(pub).hexdigest()[:16].upper()
    return ":".join(h[i:i + 4] for i in range(0, 16, 4))


def _der_len(n):
    if n < 0x80:
        return bytes([n])
    b = n.to_bytes((n.bit_length() + 7) // 8, "big")
    return bytes([0x80 | len(b)]) + b


def _der(tag, body):
    return bytes([tag]) + _der_len(len(body)) + body


def _der_int(v):
    b = v.to_bytes(max(1, (v.bit_length() + 7) // 8), "big")
    if b[0] & 0x80:
        b = b"\x00" + b
    return _der(0x02, b)


def sig_der(r, s):
    return _der(0x30, _der_int(r) + _der_int(s))


def _tlv(buf, i):
    """(tag, value bytes, next index) of the DER element at buf[i]."""
    tag = buf[i]
    ln = buf[i + 1]
    i += 2
    if ln & 0x80:
        nb = ln & 0x7F
        ln = int.from_bytes(buf[i:i + nb], "big")
        i += nb
    return tag, buf[i:i + ln], i + ln


def _children(body):
    out, i = [], 0
    while i < len(body):
        t, v, i = _tlv(body, i)
        out.append((t, v))
    return out


def sig_from_der(b):
    t, body, end = _tlv(b, 0)
    kids = _children(body)
    if t != 0x30 or end != len(b) or len(kids) != 2 or kids[0][0] != 2 or kids[1][0] != 2:
        raise ValueError("bad DER signature")
    return int.from_bytes(kids[0][1], "big"), int.from_bytes(kids[1][1], "big")


# ---------------------------------------------------------------- PEM keys
def key_to_pem(d):
    pub = pub_bytes(mul(d))
    body = (_der_int(1) + _der(0x04, d.to_bytes(32, "big")) + _der(0xA0, _der(0x06, OID_P256)) +
            _der(0xA1, _der(0x03, b"\x00" + pub)))
    b64 = base64.b64encode(_der(0x30, body)).decode()
    lines = [b64[i:i + 64] for i in range(0, len(b64), 64)]
    # Construct the PEM delimiters; the SDK contains a serializer, never a bundled key.
    return "-----BEGIN EC " + "PRIVATE KEY-----\n" + "\n".join(lines) + "\n-----END EC " + "PRIVATE KEY-----\n"


def _sec1_private(der):
    t, body, _ = _tlv(der, 0)
    kids = _children(body)
    if t != 0x30 or len(kids) < 2 or kids[1][0] != 0x04:
        raise ValueError("not an EC private key")
    for tag, v in kids[2:]:
        if tag == 0xA0:
            ct, oid, _ = _tlv(v, 0)
            if ct == 0x06 and oid != OID_P256:
                raise ValueError("the key is not on the P-256 curve (prime256v1)")
    return int.from_bytes(kids[1][1], "big")


def key_from_pem(text):
    kind = None
    for k in ("EC PRIVATE KEY", "PRIVATE KEY"):
        if "-----BEGIN %s-----" % k in text:
            kind = k
            break
    if not kind:
        raise ValueError("no EC PRIVATE KEY / PRIVATE KEY block in the PEM file")
    if "ENCRYPTED" in text or "Proc-Type" in text:
        raise ValueError("encrypted keys are not supported; export the key without a password")
    b64 = text.split("-----BEGIN %s-----" % kind)[1].split("-----END %s-----" % kind)[0]
    der = base64.b64decode("".join(b64.split()))
    if kind == "EC PRIVATE KEY":
        d = _sec1_private(der)
    else:  # PKCS#8: SEQUENCE { version, AlgorithmIdentifier { ecPublicKey, P-256 }, OCTET STRING { SEC1 key } }
        t, body, _ = _tlv(der, 0)
        kids = _children(body)
        if t != 0x30 or len(kids) < 3 or kids[2][0] != 0x04:
            raise ValueError("not a PKCS#8 private key")
        alg = _children(kids[1][1])
        if len(alg) < 2 or alg[0][1] != OID_EC_PUBLIC_KEY or alg[1][1] != OID_P256:
            raise ValueError("the key is not an EC key on P-256 (prime256v1)")
        d = _sec1_private(kids[2][1])
    if not 0 < d < N:
        raise ValueError("invalid private key")
    return d


def new_key():
    return secrets.randbelow(N - 1) + 1


# ---------------------------------------------------------------- ECDSA
def _rfc6979_k(d, h):
    x = d.to_bytes(32, "big")
    hm = (int.from_bytes(h, "big") % N).to_bytes(32, "big")
    v = b"\x01" * 32
    k = b"\x00" * 32
    k = hmac.new(k, v + b"\x00" + x + hm, hashlib.sha256).digest()
    v = hmac.new(k, v, hashlib.sha256).digest()
    k = hmac.new(k, v + b"\x01" + x + hm, hashlib.sha256).digest()
    v = hmac.new(k, v, hashlib.sha256).digest()
    while True:
        v = hmac.new(k, v, hashlib.sha256).digest()
        cand = int.from_bytes(v, "big")
        if 0 < cand < N:
            return cand
        k = hmac.new(k, v + b"\x00", hashlib.sha256).digest()
        v = hmac.new(k, v, hashlib.sha256).digest()


def sign_hash(d, h):
    z = int.from_bytes(h, "big")
    while True:
        k = _rfc6979_k(d, h)
        r = mul(k)[0] % N
        if r == 0:
            continue
        s = pow(k, -1, N) * (z + r * d) % N
        if s == 0:
            continue
        if s > N // 2:  # low-S form
            s = N - s
        return sig_der(r, s)


def verify_hash(pub, h, sig):
    try:
        q = pub_from_bytes(pub)
        r, s = sig_from_der(sig)
    except ValueError:
        return False
    if not (0 < r < N and 0 < s < N):
        return False
    z = int.from_bytes(h, "big")
    w = pow(s, -1, N)
    pt = _from_jac(_jadd(_to_jac(mul(z * w % N)), _to_jac(mul(r * w % N, q))))
    return pt is not None and pt[0] % N == r


def sign_manifest(d, manifest_bytes):
    """manifest.sig contents (JSON text) for a manifest.sha256."""
    pub = pub_bytes(mul(d))
    sig = sign_hash(d, hashlib.sha256(manifest_bytes).digest())
    return json.dumps({"alg": ALG, "key": base64.b64encode(pub).decode(), "sig": base64.b64encode(sig).decode()},
                      indent=2) + "\n"


def verify_manifest(sig_text, manifest_bytes):
    """(ok, fingerprint or reason)"""
    try:
        j = json.loads(sig_text)
        if j.get("alg") != ALG:
            return False, "unknown algorithm %r" % j.get("alg")
        pub = base64.b64decode(j["key"])
        sig = base64.b64decode(j["sig"])
    except (ValueError, KeyError, TypeError) as e:
        return False, "bad manifest.sig: %s" % e
    if not verify_hash(pub, hashlib.sha256(manifest_bytes).digest(), sig):
        return False, "signature does not match"
    return True, fingerprint(pub)
