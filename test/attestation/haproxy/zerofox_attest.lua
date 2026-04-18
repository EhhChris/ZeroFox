--[[
  zerofox_attest.lua — HAProxy inline attestation verifier.

  Implements the server-side of the ECIES protocol from patch 006:
    1. Decode X-ZeroFox-Token from base64.
    2. Extract: ephem_pub(65) || IV(12) || ciphertext+tag.
    3. ECDH(haproxy_priv, ephem_pub) → Z.
    4. ANSI X9.63 KDF: SHA-256(Z || 0x00000001)[0:16] → K_enc.
    5. AES-128-GCM decrypt; pass tag to final() for authentication.
    6. Assert plaintext == "zerofox-attest:<ts>:<host>".

  Sets req.attest_ok (bool) on the transaction.  haproxy.cfg denies
  requests where that variable is false or absent.
--]]

local openssl = require("openssl")
local pkey    = openssl.pkey
local cipher  = openssl.cipher
local digest  = openssl.digest

local PRIVATE_KEY_PATH = "/etc/haproxy/private.pem"
local MAX_TS_DRIFT     = 30  -- seconds

-- Constant DER prefix for a P-256 SubjectPublicKeyInfo (26 bytes).
-- Prepending this to a raw 65-byte uncompressed EC point (04 || x || y)
-- produces a DER-encoded SPKI that OpenSSL can load as a public key.
local P256_SPKI_PREFIX =
    "\x30\x59"                                          -- SEQUENCE (89 bytes total)
    .. "\x30\x13"                                       -- SEQUENCE — AlgorithmIdentifier
    ..   "\x06\x07\x2a\x86\x48\xce\x3d\x02\x01"        -- OID id-ecPublicKey
    ..   "\x06\x08\x2a\x86\x48\xce\x3d\x03\x01\x07"    -- OID prime256v1
    .. "\x03\x42\x00"                                   -- BIT STRING (66 bytes, 0 padding bits)

-- Load and cache the private key at lua-load time (once, not per-request).
local _priv_key
do
    local f, err = io.open(PRIVATE_KEY_PATH, "r")
    if not f then
        error("ZeroFoxAttest: cannot open " .. PRIVATE_KEY_PATH .. ": " .. tostring(err))
    end
    local pem = f:read("*a")
    f:close()
    _priv_key = pkey.read(pem, true, "pem")
    if not _priv_key then
        error("ZeroFoxAttest: failed to parse private key from " .. PRIVATE_KEY_PATH)
    end
    core.log(core.notice, "ZeroFoxAttest: private key loaded from " .. PRIVATE_KEY_PATH)
end


local function verify(ts_str, token_b64, host)
    -- 1. Validate timestamp window.
    local ts = tonumber(ts_str)
    if not ts then
        return false, "X-ZeroFox-Ts is not a number"
    end
    local drift = math.abs(os.time() - ts)
    if drift > MAX_TS_DRIFT then
        return false, string.format("timestamp drift %ds > %ds", drift, MAX_TS_DRIFT)
    end

    -- 2. Decode token.
    -- core.b64dec() is a HAProxy built-in; available since HAProxy 2.4.
    local raw = core.b64dec(token_b64)
    if not raw or #raw < 94 then   -- 65 ephem + 12 IV + 1 plaintext + 16 tag
        return false, "token too short or invalid base64"
    end

    -- 3. Split token fields.
    local ephem_pt = raw:sub(1, 65)    -- 0x04 || x(32) || y(32)
    local iv       = raw:sub(66, 77)   -- 12-byte GCM nonce
    local ct_body  = raw:sub(78, -17)  -- ciphertext (all but last 16 bytes)
    local tag      = raw:sub(-16)      -- 16-byte GCM authentication tag

    if ephem_pt:byte(1) ~= 0x04 then
        return false, "ephemeral key is not an uncompressed EC point (missing 0x04 prefix)"
    end

    -- 4. Reconstruct the ephemeral public key from the raw EC point.
    local ephem_pub = pkey.read(P256_SPKI_PREFIX .. ephem_pt, false, "der")
    if not ephem_pub then
        return false, "failed to parse ephemeral EC public key"
    end

    -- 5. ECDH — pkey:derive() returns the raw shared secret (x-coordinate).
    local Z = _priv_key:derive(ephem_pub)
    if not Z then
        return false, "ECDH derive failed"
    end

    -- 6. ANSI X9.63 KDF: SHA-256(Z || 0x00000001) → take first 16 bytes.
    local d = digest.new("sha256")
    d:update(Z)
    d:update("\x00\x00\x00\x01")
    local aes_key = d:final():sub(1, 16)

    -- 7. AES-128-GCM decrypt.
    --    In lua-openssl, passing the GCM authentication tag to final() sets
    --    EVP_CTRL_GCM_SET_TAG before calling EVP_DecryptFinal_ex.  final()
    --    returns (data, true) on success or (nil/data, false) if the tag
    --    does not match.
    local dec = cipher.new("aes-128-gcm")
    dec:init(aes_key, iv, false)         -- false = decrypt
    local partial   = dec:update(ct_body) or ""
    local tail, ok  = dec:final(tag)
    if not ok then
        return false, "AES-128-GCM authentication failed (wrong key or tampered token)"
    end
    local plaintext = partial .. (tail or "")

    -- 8. Verify canonical plaintext matches what the browser would have sent.
    local expected = "zerofox-attest:" .. ts_str .. ":" .. host
    if plaintext ~= expected then
        return false, string.format("plaintext mismatch: got %q", plaintext)
    end

    return true, "ok"
end


core.register_action("zerofox_attest", {"http-req"}, function(txn)
    local hdrs  = txn.http:req_get_headers()
    local ts_h  = hdrs["x-zerofox-ts"]
    local tok_h = hdrs["x-zerofox-token"]

    if not ts_h or not ts_h[0] or not tok_h or not tok_h[0] then
        txn:set_var("req.attest_ok", false)
        core.log(core.warning, "ZeroFoxAttest: missing headers from " .. (txn.f:src() or "?"))
        return
    end

    -- HAProxy lowercases header names; [0] is the first (and only expected) value.
    local ts_val    = ts_h[0]
    local token_val = tok_h[0]
    local host      = (txn.f:req_hdr("host") or ""):match("^([^:]+)") or ""

    local ok, reason = verify(ts_val, token_val, host)
    txn:set_var("req.attest_ok", ok)

    if not ok then
        core.log(core.warning,
            string.format("ZeroFoxAttest: rejected — %s (src=%s host=%s)",
                reason, txn.f:src() or "?", host))
    end
end)
