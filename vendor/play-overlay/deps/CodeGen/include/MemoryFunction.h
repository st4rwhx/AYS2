#pragma once

#include "Types.h"

#if defined(__EMSCRIPTEN__)
#include <emscripten/bind.h>
#endif

// AYS2: eager TXM pool prepare + diagnostics (seam) — see MemoryFunction.cpp.
// Triggers the one-time TXM brk-handshake pool setup synchronously and
// reports the real outcome, instead of it happening silently the first time
// a JIT'd block is compiled deep inside VM boot. PlayBridge exposes these to
// Swift so the app can show the real state on screen — on-device testing
// showed this failure mode produces neither a crash log nor any way to read
// the app's own stderr, so this is the only way to see what's happening.
bool AYS2PrepareJIT();
const char* AYS2JITStatus();

class CMemoryFunction
{
public:
	CMemoryFunction();
	CMemoryFunction(const void*, size_t);
	CMemoryFunction(const CMemoryFunction&) = delete;
	CMemoryFunction(CMemoryFunction&&);

	virtual ~CMemoryFunction();

	bool IsEmpty() const;

	CMemoryFunction& operator=(const CMemoryFunction&) = delete;

	CMemoryFunction& operator=(CMemoryFunction&&);
	void operator()(void*);

	void* GetCode() const;
	size_t GetSize() const;

	// AYS2: iOS 26 TXM dual-mapping (seam) — see MemoryFunction.cpp. GetCode()
	// keeps returning the executable (RX) address, since that's what every
	// caller in this codebase treats as "the real address of this code"
	// (jump/call targets, other blocks' patch values). Callers that need to
	// WRITE into an already-allocated function's buffer (block linking) must
	// go through this instead — on non-dual-mapped builds it's identical to
	// GetCode().
	void* GetWritableCode() const;

	void BeginModify();
	void EndModify();

	CMemoryFunction CreateInstance();

private:
	void ClearCache();
	void Reset();

	void* m_code;
	size_t m_size;
	// AYS2: iOS 26 TXM dual-mapping (seam) — RW alias of m_code's pages when
	// dual-mapped, nullptr otherwise. Always declared (not just under
	// TARGET_OS_IPHONE) so the class layout and GetWritableCode()'s fallback
	// logic don't need per-platform special-casing.
	void* m_rwAlias = nullptr;
	// AYS2: iOS 26 TXM dual-mapping (seam) — true when m_code/m_rwAlias are a
	// sub-range of the shared TXM pool (see MemoryFunction.cpp), not an
	// independent vm_allocate/mmap of their own. Reset() must never
	// vm_deallocate/munmap a pooled sub-range — that would unmap the whole
	// pool out from under every other still-live CMemoryFunction.
	bool m_pooled = false;
#if defined(__EMSCRIPTEN__)
	emscripten::val m_wasmModule;
#endif
};
