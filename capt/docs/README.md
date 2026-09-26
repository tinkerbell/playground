# CAPT playground documentation

## Understanding how it works

- [Architecture: the playground (IPv4)](./architecture-playground-ipv4.md) —
  C4 diagrams of a default playground, and the provisioning sequence. Start
  here.
- [Architecture: the playground (IPv6)](./architecture-playground-ipv6.md) —
  what `ipFamily: ipv6` adds, and why an IPv6-only machine can still pull from
  an IPv4-only registry.
- [Architecture: the e2e harness](./architecture-e2e.md) — C4 diagrams of the
  test harness and the combination matrix.
- [How the e2e tests work](./explanation-e2e.md) — what is under test, why the
  matrix has these four axes, and why the runner is a program.

## Getting something done

- [How to add or modify an e2e test](./how-to-e2e.md) — add a test, add a
  combination, build from your own Tinkerbell, debug a failure.

## Looking something up

- [capt/README.md](../README.md) — configuration keys, task reference, runner
  flags, and the operational caveats for each mode.
