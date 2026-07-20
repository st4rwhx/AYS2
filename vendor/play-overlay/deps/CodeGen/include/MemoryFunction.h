#pragma once

#include "Types.h"

#if defined(__EMSCRIPTEN__)
#include <emscripten/bind.h>
#endif

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
	// dual-mapped (vm_remap), nullptr otherwise. Always declared (not just
	// under TARGET_OS_IPHONE) so the class layout and GetWritableCode()'s
	// fallback logic don't need per-platform special-casing.
	void* m_rwAlias = nullptr;
#if defined(__EMSCRIPTEN__)
	emscripten::val m_wasmModule;
#endif
};
