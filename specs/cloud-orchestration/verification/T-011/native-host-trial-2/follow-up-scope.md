# Current guard follow-up

This is a second actual native host trial after T011 guard repair. All eight active SDD packages (455 installed/cache files; 426 deduplicated canonical source files) were refreshed via the real repository installer and native marketplace/plugin commands. The two discovered standard hooks were already trusted; no trust bypass or trust-setting change was made. Their actual execution records include blocked proposed inspection scripts as well as completed calls. The previous trial remains historical and did not refresh the full SDD guard dependency set.

Azure made five individual host CLI calls after a combined proposal was denied. AWS made five actual CLI subprocess calls inside one admitted host command after a separate inspection proposal was denied. Both reached the expected route and denial states. All 22 completed host command bodies were inspected; they contain local reads, hashes, CLI calls and evidence capture, with no provider API, credential access, governed wrapper invocation or product edit. Incidental nonrepository/no-file search exit codes do not count as CLI outcomes.

Azure denial filenames were not written by the native model; the root caller captured exact CLI stdout into the public artifact directory. AWS denial files were written by the native model from exact stdout. Per-fixture capture-provenance.json distinguishes those copies from the provider-published route evidence. No denied result is attributed to provider evidence publication.

The original verify-profile configuration and complete plugin cache were restored exactly after capture; native history was retained. These are synthetic local fixtures, not live Azure/AWS acceptance. This is one follow-up per provider, not a statistical comparison.
