// Render entrypoint for the infra subpackage. Three exported symbols, each
// fetched independently by the Taskfile via `cue export -e <symbol> --out yaml`:
//
//   outHardware     map[string]Hardware       — one file per VM
//   outBmcMachines  map[string]Machine        — one file per VM
//   outBmcSecret    Secret                    — single shared secret
package infra

import v "tinkerbell.org/capt-playground/cue/values"

// Top-level injected by the task pipeline:
//   cue export ./cue/infra yaml: .state -l 'values:' -e <symbol> --out yaml
values: v.#Config

// _mode is unused by the infra resources but the shared #Computed struct
// requires it; default to netboot to keep the unification valid. The choice
// has no effect on any field referenced by infra (clusterName, namespace).
_mode: "netboot"

c: v.#Computed & {"values": values, mode: _mode}
