#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <algorithm>
#include <cstdint>
#include "AlignedAlloc.h"
#include "MemoryFunction.h"

// clang-format off

#define BLOCK_ALIGN 0x10

#ifdef _WIN32
	#define MEMFUNC_USE_WIN32
#elif defined(__APPLE__)
	#include "TargetConditionals.h"
	#include <libkern/OSCacheControl.h>

	#if TARGET_OS_OSX
		#define MEMFUNC_USE_MMAP
		#define MEMFUNC_MMAP_ADDITIONAL_FLAGS (MAP_JIT)
		#if TARGET_CPU_ARM64
			#define MEMFUNC_MMAP_REQUIRES_JIT_WRITE_PROTECT
		#endif
	#else
		#define MEMFUNC_USE_MACHVM
		#if TARGET_OS_IPHONE
			#define MEMFUNC_MACHVM_STRICT_PROTECTION
		#endif
	#endif
#elif defined(__EMSCRIPTEN__)
	#include <emscripten.h>
	#define MEMFUNC_USE_WASM
#else
	#define MEMFUNC_USE_MMAP
#endif

#if defined(MEMFUNC_USE_WIN32)
#include <windows.h>
#elif defined(MEMFUNC_USE_MACHVM)
#include <mach/mach_init.h>
#include <mach/vm_map.h>
#elif defined(MEMFUNC_USE_MMAP)
#include <sys/mman.h>
#include <pthread.h>
#elif defined(MEMFUNC_USE_WASM)
EM_JS_DEPS(WasmMemoryFunction, "$addFunction,$removeFunction");
EM_JS(int, WasmCreateFunction, (emscripten::EM_VAL moduleHandle),
{
	let module = Emval.toValue(moduleHandle);
	let moduleInstance = new WebAssembly.Instance(module, {
		env: {
			memory: wasmMemory,
			fctTable : Module.codeGenImportTable
		}
	});
	let fct = moduleInstance.exports.codeGenFunc;
	let fctId = addFunction(fct, 'vi');
	return fctId;
});
EM_JS(void, WasmDeleteFunction, (int fctId),
{
	removeFunction(fctId);
});
EM_JS(emscripten::EM_VAL, WasmCreateModule, (uintptr_t code, uintptr_t size),
{
	//var fs = require('fs');
	let moduleBytes = HEAP8.subarray(code, code + size);
	//fs.writeFileSync('module.wasm', moduleBytes);
	//{
	//	let bytesCopy = new Uint8Array(moduleBytes);
	//	let blob = new Blob([bytesCopy], { type: "binary/octet-stream" });
	//	let url = URL.createObjectURL(blob);
	//	console.log(url);
	//}
	let module = new WebAssembly.Module(moduleBytes);
	return Emval.toHandle(module);
});
#else
#error "No API to use for CMemoryFunction"
#endif

// AYS2: iOS 26 Trusted Execution Monitor (TXM) dual-mapping (seam).
//
// Ported from AYS2's own DarwinMisc.cpp (DetectJitMode/MmapCodeDualMap),
// battle-tested there across this project's own JIT hardening work. Same
// underlying problem: MEMFUNC_MACHVM_STRICT_PROTECTION's original strategy
// (vm_allocate once, then vm_protect-toggle the SAME page between RW and
// RX for BeginModify/EndModify) is exactly the "Legacy" approach that iOS
// 26's TXM blocks outright, even with CS_DEBUGGED set — regardless of
// which tool (StikDebug, SideStore, a classic AltServer) granted it.
//
// TXM's escape hatch is registering an RX code region with an attached
// debugger via a `brk #0xf00d` handshake (the StikDebug "Universal"
// protocol), then using vm_remap to get a separate RW alias of the same
// physical pages: writes go through the RW alias, execution/jumps go
// through the original RX pointer. No protection toggle needed afterward.
//
// AYS2: shared pool, not per-allocation (seam/fix) — a real on-device test
// confirmed the first version of this port (one brk-handshake per
// CMemoryFunction) doesn't work for Play!. The StikDebug "Universal"
// script detaches its debugger session entirely after the FIRST
// registration (the app-side handshake ends by design with a real GDB
// `D`etach packet, matching AYS2's own one-big-pool-at-startup usage).
// AYS2's own PCSX2 fork only ever calls MmapCodeDualMap once, for one big
// pool — but Play!'s CBasicBlock allocates a brand new CMemoryFunction
// PER COMPILED BASIC BLOCK, potentially thousands of times over a play
// session. Every registration after the first had no attached debugger
// left to service its brk, and the process died silently (confirmed via
// StikDebug's own connection log: one early trap forwarded, then total
// silence, then "Failed to detach from process: -1" — the app was already
// gone).
//
// Fix: allocate ONE large pool on first use (one brk-handshake, exactly
// like AYS2's own main app), then bump-allocate every individual
// CMemoryFunction's RX/RW pair as a sub-range of that pool — no further
// debugger involvement needed after the very first CMemoryFunction is
// constructed. Reset() must never vm_deallocate a pooled sub-range (see
// the m_pooled comment in MemoryFunction.h) — pooled memory is only
// reclaimed at process exit, so a very long play session could
// theoretically exhaust the pool; see TXM_POOL_SIZE below.
//
// This only changes the TARGET_OS_IPHONE (real device or simulator)
// branch below. TARGET_OS_OSX (MEMFUNC_USE_MMAP + MAP_JIT), Win32, generic
// mmap, and Wasm paths are untouched.
#if defined(MEMFUNC_MACHVM_STRICT_PROTECTION)

#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cerrno>
#include <atomic>
#include <thread>
#include <chrono>
#include <mutex>
#include <setjmp.h>
#include <sys/mman.h>
#include <sys/sysctl.h>
#include <glob.h>

namespace
{
	enum class JitMode
	{
		Legacy, // vm_protect toggle (iOS 18 and earlier, or TXM registration failed)
		LuckTXM, // brk #0xf00d + vm_remap dual-mapping (iOS 26, A15+)
	};

	bool s_jitModeDetected = false;
	JitMode s_jitMode = JitMode::Legacy;
	// AYS2: kept so the on-screen diagnostic (AYS2JITStatus) can report the
	// detected OS version + TXM probe result — the exact inputs to the mode
	// decision that just caused a real bug, so a future failure is diagnosable
	// from the device alone.
	char s_jitModeDetail[96] = "not detected yet";

#if !TARGET_OS_SIMULATOR
	bool HasTXM()
	{
		glob_t g = {};
		const int ret = glob("/System/Volumes/Preboot/*/boot/*/usr/standalone/firmware/FUD/Ap,TrustedExecutionMonitor.img4",
			GLOB_NOSORT, nullptr, &g);
		const bool found = (ret == 0 && g.gl_pathc > 0);
		globfree(&g);
		return found;
	}
#endif

	JitMode DetectJitMode()
	{
#if TARGET_OS_SIMULATOR
		s_jitMode = JitMode::Legacy;
#else
		char version[64] = {};
		size_t versionLen = sizeof(version);
		if(sysctlbyname("kern.osproductversion", version, &versionLen, nullptr, 0) != 0)
			std::snprintf(version, sizeof(version), "0");
		const int major = std::atoi(version);
		const bool hasTXM = HasTXM();
		// AYS2: CRITICAL FIX (seam) — the decision is `major >= 26` ONLY, matching
		// AYS2's own proven-working DarwinMisc::DetectJitMode() exactly. An earlier
		// version of this port added `&& hasTXM`, which was a real bug: HasTXM()
		// globs /System/Volumes/Preboot/.../TrustedExecutionMonitor.img4, a path a
		// sandboxed sideloaded app often CAN'T read — so hasTXM came back false on a
		// real iOS 26.3 device that genuinely has TXM, wrongly selecting Legacy. That
		// sent JIT through the vm_protect RW/RX toggle TXM blocks, so the brk #0xf00d
		// handshake never fired at all (confirmed by its total absence from the
		// device's StikDebug log) and the app hit a silent black-screen hang. The
		// main app never gated on hasTXM (it computes it for logging only); this now
		// matches. hasTXM stays in the log line below purely as a diagnostic.
		s_jitMode = (major >= 26) ? JitMode::LuckTXM : JitMode::Legacy;
		std::snprintf(s_jitModeDetail, sizeof(s_jitModeDetail), "iOS %s (major %d), txm_probe=%d, mode=%s",
			version, major, hasTXM ? 1 : 0, s_jitMode == JitMode::LuckTXM ? "LuckTXM" : "Legacy");
		std::fprintf(stderr, "@@PLAY_JIT_MODE@@ %s\n", s_jitModeDetail);
		std::fflush(stderr);
#endif
		s_jitModeDetected = true;
		return s_jitMode;
	}

	JitMode GetJitMode()
	{
		if(!s_jitModeDetected)
			DetectJitMode();
		return s_jitMode;
	}

#if !TARGET_OS_SIMULATOR
	__attribute__((noinline, optnone))
	void JIT26PrepareRegion(void* addr, size_t len)
	{
		asm volatile("mov x0, %0\n"
		             "mov x1, %1\n"
		             "mov x16, #1\n"
		             "brk #0xf00d\n"
		             :: "r"(addr), "r"(len) : "x0", "x1", "x16", "memory");
	}

	__attribute__((noinline, optnone))
	void JIT26Detach(void)
	{
		asm volatile("mov x16, #0\n"
		             "brk #0xf00d\n"
		             ::: "x16", "memory");
	}

	// Registers `rxPtr`/`size` with an attached JIT-enabler (StikDebug/
	// SideStore running the Universal protocol) via the brk handshake.
	// 15s worker-thread timeout (longer than AYS2's own 8s — this now only
	// ever runs ONCE per app session, registering the whole pool, so a more
	// generous margin costs nothing): the handshake can hang instead of
	// trapping on some devices/regions, and this is called from
	// CMemoryFunction's constructor — a hang there would freeze block
	// compilation, not just JIT setup.
	bool RegisterTXMRegion(void* rxPtr, size_t size)
	{
		static sigjmp_buf s_brkJmp;
		struct sigaction saBrk = {};
		struct sigaction saBrkOld = {};
		saBrk.sa_handler = +[](int) { siglongjmp(s_brkJmp, 1); };
		sigemptyset(&saBrk.sa_mask);
		sigaction(SIGTRAP, &saBrk, &saBrkOld);

		std::atomic<bool> done{false};
		std::atomic<bool> ok{false};

		std::thread worker([&]() {
			if(sigsetjmp(s_brkJmp, 1) == 0)
			{
				JIT26PrepareRegion(rxPtr, size);
				if(sigsetjmp(s_brkJmp, 1) == 0)
				{
					JIT26Detach();
					ok.store(true);
				}
			}
			done.store(true);
		});
		worker.detach();

		for(int i = 0; i < 150; i++)
		{
			if(done.load(std::memory_order_relaxed))
				break;
			std::this_thread::sleep_for(std::chrono::milliseconds(100));
		}

		// AYS2: same accepted trade-off as the ported original — if the
		// worker is still running when we restore saBrkOld below, a late
		// trap goes to the old handler instead of ours. Bounded to
		// hang + late trap, and this whole path is opt-in (only reached on
		// detected iOS 26 + TXM).
		sigaction(SIGTRAP, &saBrkOld, nullptr);

		return done.load() && ok.load();
	}

	// AYS2: shared TXM pool (seam/fix) — see the file-level comment above
	// for why this exists instead of one brk-handshake per CMemoryFunction.
	// 8MB, not the first attempt's 96MB: per-block registrations (small,
	// a few hundred bytes to a few KB each) got through the debugger's
	// prepare_memory_region native call fine before; a single 96MB
	// registration in one shot is untested and is a plausible reason a
	// second real-device attempt still failed — StikDebug's native
	// memory-preparation call may not be designed for one huge upfront
	// request the way small, incremental JIT allocations are. 8MB should
	// still comfortably hold thousands of compiled basic blocks (each
	// typically well under a few KB) for a real test session. If it's
	// ever exhausted, TXMPoolAlloc starts returning false and callers
	// fall back to the Legacy per-instance path (which will likely itself
	// fail under real TXM enforcement — a last-resort degradation, not a
	// real fix for running out of pool).
	constexpr size_t TXM_POOL_SIZE = 8 * 1024 * 1024; // 8MB

	struct TXMPool
	{
		std::mutex mutex;
		bool initAttempted = false;
		bool ready = false;
		void* rxBase = nullptr;
		void* rwBase = nullptr;
		size_t used = 0;
		// AYS2: on-device testing has no reliable way to see this app's own
		// stderr (no crash log is generated either — this whole path fails
		// as a silent hang, not a crash) — so the *last* concrete outcome
		// is kept here in plain text, for PrepareJIT()/GetStatus() to
		// surface directly in the UI instead of stderr nobody can read.
		char lastOutcome[128] = "not attempted yet";
	};

	TXMPool& GetTXMPool()
	{
		static TXMPool pool;
		return pool;
	}

	// Does the one-time pool mmap + brk-handshake registration + vm_remap,
	// if not already done. Split out from TXMPoolAlloc (seam) so callers
	// can trigger and check this eagerly/synchronously — e.g. right when
	// the user taps a game, with a visible result — instead of it firing
	// silently deep inside the first JIT'd block's compilation.
	bool EnsureTXMPoolReady()
	{
		auto& pool = GetTXMPool();
		std::lock_guard<std::mutex> lock(pool.mutex);

		if(!pool.initAttempted)
		{
			pool.initAttempted = true;
			void* rxPtr = mmap(nullptr, TXM_POOL_SIZE, PROT_READ | PROT_EXEC, MAP_ANON | MAP_PRIVATE, -1, 0);
			if(rxPtr != MAP_FAILED)
			{
				if(RegisterTXMRegion(rxPtr, TXM_POOL_SIZE))
				{
					vm_address_t rwRegion = 0;
					vm_address_t target = reinterpret_cast<vm_address_t>(rxPtr);
					vm_prot_t curProtection = 0;
					vm_prot_t maxProtection = 0;
					const kern_return_t kr = vm_remap(mach_task_self(), &rwRegion, static_cast<vm_size_t>(TXM_POOL_SIZE), 0,
						VM_FLAGS_ANYWHERE, mach_task_self(), target, false, &curProtection, &maxProtection, VM_INHERIT_DEFAULT);
					if(kr == KERN_SUCCESS && mprotect(reinterpret_cast<void*>(rwRegion), TXM_POOL_SIZE, PROT_READ | PROT_WRITE) == 0)
					{
						pool.rxBase = rxPtr;
						pool.rwBase = reinterpret_cast<void*>(rwRegion);
						pool.ready = true;
						std::snprintf(pool.lastOutcome, sizeof(pool.lastOutcome), "ready (rx=%p rw=%p)", pool.rxBase, pool.rwBase);
					}
					else
					{
						if(kr == KERN_SUCCESS)
							vm_deallocate(mach_task_self(), rwRegion, static_cast<vm_size_t>(TXM_POOL_SIZE));
						munmap(rxPtr, TXM_POOL_SIZE);
						std::snprintf(pool.lastOutcome, sizeof(pool.lastOutcome), "vm_remap/mprotect failed kr=%d", kr);
					}
				}
				else
				{
					munmap(rxPtr, TXM_POOL_SIZE);
					std::snprintf(pool.lastOutcome, sizeof(pool.lastOutcome), "brk handshake registration failed or timed out");
				}
			}
			else
			{
				std::snprintf(pool.lastOutcome, sizeof(pool.lastOutcome), "mmap failed err=%d", errno);
			}
			std::fprintf(stderr, "@@PLAY_JIT_POOL@@ %s\n", pool.lastOutcome);
			std::fflush(stderr);
		}

		return pool.ready;
	}

	// Allocates `size` bytes (BLOCK_ALIGN-aligned) from the shared TXM pool.
	// Returns false if the pool couldn't be set up at all, or is exhausted
	// — callers must fall back to the Legacy path in either case.
	bool TXMPoolAlloc(size_t size, void** outRx, void** outRw)
	{
		if(!EnsureTXMPoolReady())
			return false;

		auto& pool = GetTXMPool();
		std::lock_guard<std::mutex> lock(pool.mutex);

		const size_t alignedSize = (size + (BLOCK_ALIGN - 1)) & ~static_cast<size_t>(BLOCK_ALIGN - 1);
		if(pool.used + alignedSize > TXM_POOL_SIZE)
		{
			std::snprintf(pool.lastOutcome, sizeof(pool.lastOutcome), "exhausted used=0x%zx requested=0x%zx", pool.used, alignedSize);
			std::fprintf(stderr, "@@PLAY_JIT_POOL@@ %s\n", pool.lastOutcome);
			std::fflush(stderr);
			return false;
		}

		*outRx = static_cast<uint8_t*>(pool.rxBase) + pool.used;
		*outRw = static_cast<uint8_t*>(pool.rwBase) + pool.used;
		pool.used += alignedSize;
		return true;
	}
#endif
} // namespace

// AYS2: eager prepare + visible diagnostics (seam) — PlayBridge calls
// PrepareJIT() synchronously right when the user taps a game, instead of
// this firing silently deep inside CBasicBlock::Compile() the first time
// a block needs JIT'ing. On-device testing showed a real, hard-to-debug
// gap: no crash log gets generated for this failure mode (it's a silent
// hang, not a crash), and app stderr isn't reachable without a Mac — so
// GetStatus() gives AYS2RootView something concrete to put on screen.
bool AYS2PrepareJIT()
{
	if(GetJitMode() != JitMode::LuckTXM)
		return true; // Legacy path: nothing to pre-register
	return EnsureTXMPoolReady();
}

const char* AYS2JITStatus()
{
	static char buf[320];
	const JitMode mode = GetJitMode();
	if(mode != JitMode::LuckTXM)
	{
		std::snprintf(buf, sizeof(buf), "%s — Legacy mode, no TXM pool used", s_jitModeDetail);
		return buf;
	}
	auto& pool = GetTXMPool();
	std::lock_guard<std::mutex> lock(pool.mutex);
	std::snprintf(buf, sizeof(buf), "%s\nTXM pool: %s | used %zu/%zu bytes",
		s_jitModeDetail, pool.lastOutcome, pool.used, TXM_POOL_SIZE);
	return buf;
}

#endif // MEMFUNC_MACHVM_STRICT_PROTECTION

#if !defined(MEMFUNC_MACHVM_STRICT_PROTECTION)
bool AYS2PrepareJIT() { return true; }
const char* AYS2JITStatus() { return "N/A (not a dual-mapped iOS build)"; }
#endif

CMemoryFunction::CMemoryFunction()
: m_code(nullptr)
, m_size(0)
{

}

CMemoryFunction::CMemoryFunction(const void* code, size_t size)
: m_code(nullptr)
{
#if defined(MEMFUNC_USE_WIN32)
	m_size = size;
	m_code = framework_aligned_alloc(size, BLOCK_ALIGN);
	memcpy(m_code, code, size);

	DWORD oldProtect = 0;
	BOOL result = VirtualProtect(m_code, size, PAGE_EXECUTE_READWRITE, &oldProtect);
	assert(result == TRUE);
#elif defined(MEMFUNC_USE_MACHVM)
	vm_size_t page_size = 0;
	host_page_size(mach_task_self(), &page_size);
	unsigned int allocSize = ((size + page_size - 1) / page_size) * page_size;

#if defined(MEMFUNC_MACHVM_STRICT_PROTECTION)
	bool dualMapped = false;
	if(GetJitMode() == JitMode::LuckTXM)
	{
		void* rxPtr = nullptr;
		void* rwPtr = nullptr;
		if(TXMPoolAlloc(size, &rxPtr, &rwPtr))
		{
			m_code = rxPtr;
			m_rwAlias = rwPtr;
			m_pooled = true;
			memcpy(m_rwAlias, code, size);
			dualMapped = true;
			// Pool sub-ranges are exactly `size` bytes (BLOCK_ALIGN-aligned
			// by TXMPoolAlloc), not page-aligned like the Legacy path below
			// — m_size must reflect the real allocation size so ClearCache/
			// icache-invalidate and any later GetSize() callers agree with
			// what TXMPoolAlloc actually reserved.
			allocSize = static_cast<unsigned int>((size + (BLOCK_ALIGN - 1)) & ~static_cast<size_t>(BLOCK_ALIGN - 1));
		}
	}

	if(!dualMapped)
	{
		// Legacy: either DetectJitMode() picked Legacy directly, or the
		// shared TXM pool couldn't be set up/is exhausted, and we fall back
		// to the original vm_allocate + vm_protect-toggle strategy
		// per-instance.
		vm_allocate(mach_task_self(), reinterpret_cast<vm_address_t*>(&m_code), allocSize, TRUE);
		memcpy(m_code, code, size);
		kern_return_t result = vm_protect(mach_task_self(), reinterpret_cast<vm_address_t>(m_code), size, 0, VM_PROT_READ | VM_PROT_EXECUTE);
		assert(result == 0);
	}
#else
	vm_allocate(mach_task_self(), reinterpret_cast<vm_address_t*>(&m_code), allocSize, TRUE);
	memcpy(m_code, code, size);
	kern_return_t result = vm_protect(mach_task_self(), reinterpret_cast<vm_address_t>(m_code), size, 0, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
	assert(result == 0);
#endif
	m_size = allocSize;
#elif defined(MEMFUNC_USE_MMAP)
	uint32 additionalMapFlags = 0;
	#ifdef MEMFUNC_MMAP_ADDITIONAL_FLAGS
		additionalMapFlags = MEMFUNC_MMAP_ADDITIONAL_FLAGS;
	#endif
	m_size = size;
	m_code = mmap(nullptr, size, PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANONYMOUS | additionalMapFlags, -1, 0);
	assert(m_code != MAP_FAILED);
#ifdef MEMFUNC_MMAP_REQUIRES_JIT_WRITE_PROTECT
	pthread_jit_write_protect_np(false);
#endif
	memcpy(m_code, code, size);
#ifdef MEMFUNC_MMAP_REQUIRES_JIT_WRITE_PROTECT
	pthread_jit_write_protect_np(true);
#endif
#elif defined(MEMFUNC_USE_WASM)
	m_wasmModule = emscripten::val::take_ownership(WasmCreateModule(reinterpret_cast<uintptr_t>(code), size));
	m_size = size;
	m_code = reinterpret_cast<void*>(WasmCreateFunction(m_wasmModule.as_handle()));
#endif
	ClearCache();
#if !defined(MEMFUNC_USE_WASM)
	assert((reinterpret_cast<uintptr_t>(m_code) & (BLOCK_ALIGN - 1)) == 0);
#endif
}

CMemoryFunction::~CMemoryFunction()
{
	Reset();
}

void CMemoryFunction::ClearCache()
{
#ifdef __APPLE__
	sys_icache_invalidate(m_code, m_size);
#elif defined(MEMFUNC_USE_MMAP)
	#if defined(__arm__) || defined(__aarch64__)
		__clear_cache(m_code, reinterpret_cast<uint8*>(m_code) + m_size);
	#endif
#endif
}

void CMemoryFunction::Reset()
{
	if(m_code != nullptr)
	{
#if defined(MEMFUNC_USE_WIN32)
		framework_aligned_free(m_code);
#elif defined(MEMFUNC_USE_MACHVM)
#if defined(MEMFUNC_MACHVM_STRICT_PROTECTION)
		// AYS2: a pooled sub-range (m_pooled) must NEVER be individually
		// vm_deallocate'd — it's a slice of the shared TXM pool other
		// still-live CMemoryFunctions also point into. Pooled memory is
		// only reclaimed at process exit (see the file-level comment).
		if(!m_pooled)
			vm_deallocate(mach_task_self(), reinterpret_cast<vm_address_t>(m_code), m_size);
#else
		vm_deallocate(mach_task_self(), reinterpret_cast<vm_address_t>(m_code), m_size);
#endif
#elif defined(MEMFUNC_USE_MMAP)
		munmap(m_code, m_size);
#elif defined(MEMFUNC_USE_WASM)
		WasmDeleteFunction(reinterpret_cast<int>(m_code));
#endif
	}
	m_code = nullptr;
	m_rwAlias = nullptr;
	m_pooled = false;
	m_size = 0;
#if defined(MEMFUNC_USE_WASM)
	m_wasmModule = emscripten::val();
#endif
}

bool CMemoryFunction::IsEmpty() const
{
	return m_code == nullptr;
}

CMemoryFunction& CMemoryFunction::operator =(CMemoryFunction&& rhs)
{
	Reset();
	std::swap(m_code, rhs.m_code);
	std::swap(m_size, rhs.m_size);
	std::swap(m_rwAlias, rhs.m_rwAlias);
	std::swap(m_pooled, rhs.m_pooled);
#if defined(MEMFUNC_USE_WASM)
	std::swap(m_wasmModule, rhs.m_wasmModule);
#endif
	return (*this);
}

void CMemoryFunction::operator()(void* context)
{
	typedef void (*FctType)(void*);
	auto fct = reinterpret_cast<FctType>(m_code);
	fct(context);
}

void* CMemoryFunction::GetCode() const
{
	return m_code;
}

void* CMemoryFunction::GetWritableCode() const
{
	return m_rwAlias ? m_rwAlias : m_code;
}

size_t CMemoryFunction::GetSize() const
{
	return m_size;
}

void CMemoryFunction::BeginModify()
{
#if defined(MEMFUNC_USE_MACHVM) && defined(MEMFUNC_MACHVM_STRICT_PROTECTION)
	// Dual-mapped (LuckTXM): RW alias is always writable, RX pointer is
	// always executable — no toggle needed, this is the whole point.
	if(m_rwAlias != nullptr)
		return;
	kern_return_t result = vm_protect(mach_task_self(), reinterpret_cast<vm_address_t>(m_code), m_size, 0, VM_PROT_READ | VM_PROT_WRITE);
	assert(result == 0);
#elif defined(MEMFUNC_USE_MMAP) && defined(MEMFUNC_MMAP_REQUIRES_JIT_WRITE_PROTECT)
	pthread_jit_write_protect_np(false);
#endif
}

void CMemoryFunction::EndModify()
{
#if defined(MEMFUNC_USE_MACHVM) && defined(MEMFUNC_MACHVM_STRICT_PROTECTION)
	if(m_rwAlias != nullptr)
	{
		ClearCache();
		return;
	}
	kern_return_t result = vm_protect(mach_task_self(), reinterpret_cast<vm_address_t>(m_code), m_size, 0, VM_PROT_READ | VM_PROT_EXECUTE);
	assert(result == 0);
#elif defined(MEMFUNC_USE_MMAP) && defined(MEMFUNC_MMAP_REQUIRES_JIT_WRITE_PROTECT)
	pthread_jit_write_protect_np(true);
#endif
	ClearCache();
}

CMemoryFunction CMemoryFunction::CreateInstance()
{
#if defined(MEMFUNC_USE_WASM)
	CMemoryFunction result;
	result.m_wasmModule = m_wasmModule;
	result.m_size = m_size;
	result.m_code = reinterpret_cast<void*>(WasmCreateFunction(m_wasmModule.as_handle()));
	return result;
#else
	return CMemoryFunction(GetCode(), GetSize());
#endif
}
