# ns8-sagemath

A [NethServer 8](https://github.com/NethServer/ns8-core) module that runs
[SageMath](https://www.sagemath.org/) in the browser as a **multi-user
JupyterHub**: users sign in with their **Active Directory / LDAP** account and
each gets a private, persistent JupyterLab with the SageMath kernel.

> Unofficial, community-built module. Not affiliated with or endorsed by the
> SageMath project. "SageMath" is used only to identify the packaged software.

## What it is

The official `sagemath/sagemath` image is a *single-user* Jupyter notebook with
no login and no per-user separation. This module wraps it into a small
multi-user server by adding, in one rootless container:

- **JupyterHub** (with `configurable-http-proxy`) as the front door;
- the **LDAP/Active Directory authenticator**, so login uses existing AD
  accounts (optionally restricted to one AD group);
- a **`SimpleLocalProcessSpawner`** that gives every user their own persistent
  home under a named volume — this is what recreates the classic "everyone has
  their own worksheets" experience, now on top of JupyterLab + the SageMath
  kernel.

Everything the SageMath Jupyter kernel needs (the Sage shell environment) is
preserved: the hub is started via the base image's `sage -sh` entrypoint, so the
single-user servers it spawns inherit the environment and the `SageMath` kernel
works out of the box.

## Architecture

- **One rootless container** publishing only `127.0.0.1:${TCP_PORT}` → container
  port 8000. A single Traefik route on the module's FQDN reverse-proxies to it
  and forwards the notebook WebSocket upgrades.
- Runtime image `ghcr.io/tebbiworld/sagemath-app` (`FROM sagemath/sagemath` +
  JupyterHub + LDAP authenticator + Node/CHP), pinned by the module through the
  `org.nethserver.images` label.
- Two named volumes survive container recreation:
  `sagemath-hub` (hub database + cookie secret) and
  `sagemath-userhomes` (per-user notebook homes).

## Install

```
add-module ghcr.io/tebbiworld/sagemath:latest 1
```

Then open the module UI and set, on the **Settings** page:

- the **host name** (FQDN, must resolve to the node) and TLS options;
- **AD/LDAP login**: LDAPS URL (`ldaps://ad.example.org:636`), Base DN, a
  read-only bind/service account, and optionally an access group (use
  *Load groups* to pick one). LDAPS is required — AD refuses simple binds on
  plain `:389`.

Without AD/LDAP configured the hub still runs, but nobody can log in.

## Notes

- Users authenticate against AD; the module never stores their passwords. Only
  the bind/service-account credentials are kept in the instance configuration.
- `SimpleLocalProcessSpawner` runs each user's server as the container's own
  user in a separate `HOME`. It gives per-user *files*, suitable for a trusted
  group (e.g. one AD group); it is not OS-level sandboxing between users.
- The module is rootless and stores everything inside its own module user.

## Build

```
./build-images.sh
```

builds both the runtime image and the module package. See the script for the
manual publish commands.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).

## Directory server on the same node

If the LDAP/AD server is the node itself (for example the NS8 Samba account
provider on this node), the container cannot connect to the node's own IP
address — rootless containers see that address as their own. The module detects
this at configuration time and lets the hub connect through
`host.containers.internal` instead; nothing needs to be configured for it. The
detection runs again on every module update.
