#include <nexvyn/nxn_sys.h>

#ifdef NEXVYN_WINDOWED
#pragma weak nxn_thread_hint_host_request
#endif

uint32_t nxn_thread_hint_request(uint32_t worker_cores, nxn_thread_hint_priority priority,
                                 nxn_thread_hint_priority* granted_priority) {
#ifdef NEXVYN_WINDOWED
    if (nxn_thread_hint_host_request)
        return nxn_thread_hint_host_request(worker_cores, priority, granted_priority);
#else
    (void)worker_cores;
    (void)priority;
#endif
    if (granted_priority) *granted_priority = NXN_THREAD_HINT_NORMAL;
    return 0;
}
