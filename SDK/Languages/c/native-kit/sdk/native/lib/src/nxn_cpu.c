/* Nexvyn Native SDK library - nxn_cpu.h in a stand-alone .nro. Inside Nexvyn OS (windowed mode) the host import answers
 * (source/runtimes/nxwin_cpu.cpp); both use nxn_cpu_impl.h. */
#include "nxn_cpu_impl.h"

nxn_result nxn_cpu_info_get(nxn_cpu_info* out) { return nxn_cpu__get(out); }
