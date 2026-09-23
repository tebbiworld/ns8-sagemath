# Changelog

## 1.1.0 — 2026-09-19

Alignment with the NethServer module conventions (NethServer/agents skills).

### Changed

- **Secrets moved out of the module environment.** The LDAP bind password is now kept in `state/passwords.env` (mode 0600) instead of `state/environment`, which NS8 mirrors to Redis in plain text. Existing installations are migrated on update; the value does not change. The generated `hub.env` is private (0600).
- **Module backup now contains the data.** New `etc/state-include.conf`: the backup holds the JupyterHub volume, the users' home directories and the secrets file. Before, only the module environment was saved.
- **Working restore.** New `restore-module` steps re-apply every setting, including the directory login.
- `update-module` only restarts a running instance.

### Added

- Robot Framework tests (install, update from the previous release, backup and restore) run on real NS8 nodes through `stephdl/ns8-ci-actions`.

### Platform integration

- **Clone and move.** New `clone-module` step (a link to the restore step): a cloned or moved instance gets its route and settings back instead of coming up unconfigured. The settings are read from the source instance, including those a new instance starts with a default for.
- `org.nethserver.volumes`: the bulk-data volume(s) `sagemath-userhomes` can be placed on an additional disk when the module is installed.
- Release notes are linked from the software centre (`relnotes_url`).

## 1.0.1 — 2026-09-12

### Fixed

- **AD/LDAP login failed when the directory server runs on the same node.**
  With the rootless default network the node's own IP address is mirrored into
  the container, so a connection to it is refused instead of reaching the host.
  When the configured LDAP host resolves to this node, the hub now connects
  through `host.containers.internal` (new helper `bin/ldap-container-host`);
  other hosts are unaffected.
- `update-module` re-runs that detection and restarts the hub, so the fix
  applies to existing instances right after the update.

## 1.0.0 — 2026-07-05

- Initial release: JupyterHub + SageMath kernel, AD/LDAP login, per-user
  notebook homes.
