// Host-only libnx shim for deterministic account state-machine tests.
// This is NOT a cryptographic implementation or a test of libnx cryptography.
#pragma once
#include <cstddef>
#include <cstdint>
#include <cstring>
inline void randomGet(void* out,size_t n) {
 static uint8_t counter=0;auto* p=(uint8_t*)out;for(size_t i=0;i<n;++i)p[i]=++counter;
}
inline void hmacSha256CalculateMac(void* out,const void* key,size_t kn,const void* data,size_t n) {
 auto* p=(uint8_t*)out;memset(p,0x93,32);
 for(size_t i=0;i<kn;++i)p[i%32]^=((const uint8_t*)key)[i];
 for(size_t i=0;i<n;++i)p[i%32]=(uint8_t)((p[i%32]*33)^((const uint8_t*)data)[i]);
}
struct Aes256CtrContext { uint8_t key[32],iv[16]; };
inline void aes256CtrContextCreate(Aes256CtrContext* c,const void* key,const void* iv) { memcpy(c->key,key,32);memcpy(c->iv,iv,16); }
inline void aes256CtrCrypt(Aes256CtrContext* c,void* out,const void* data,size_t n) {
 for(size_t i=0;i<n;++i)((uint8_t*)out)[i]=((const uint8_t*)data)[i]^c->key[i%32]^c->iv[i%16];
}
