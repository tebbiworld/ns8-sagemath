# Copyright (C) 2026 tebbi
# SPDX-License-Identifier: GPL-3.0-or-later
#
# JupyterHub configuration for the NS8 SageMath module. Every tunable is read
# from the environment so the NS8 configure-module action only writes an env
# file (state/hub.env) and restarts the container.

import os

c = get_config()  # noqa: F821


def _env(key, default=""):
    v = os.environ.get(key)
    return default if v is None else v


def _bool(key, default=False):
    v = os.environ.get(key)
    if v is None:
        return default
    return v.strip().lower() in ("1", "true", "yes", "on")


# --- Networking -------------------------------------------------------------
# The container publishes only 127.0.0.1:${TCP_PORT} -> 8000 on the node and
# Traefik terminates TLS in front of it. The hub and the routing proxy's API
# stay bound to container-local addresses.
base_url = _env("HUB_BASE_URL", "/") or "/"
c.JupyterHub.base_url = base_url
c.JupyterHub.bind_url = "http://0.0.0.0:8000"
c.JupyterHub.hub_ip = "127.0.0.1"
c.ConfigurableHTTPProxy.api_url = "http://127.0.0.1:8001"
# We sit behind a trusted TLS-terminating reverse proxy on loopback.
c.JupyterHub.trusted_downstream_ips = ["127.0.0.1"]

# --- State & spawner --------------------------------------------------------
c.JupyterHub.db_url = "sqlite:////srv/jupyterhub/jupyterhub.sqlite"
c.JupyterHub.cookie_secret_file = "/srv/jupyterhub/jupyterhub_cookie_secret"
c.JupyterHub.pid_file = "/srv/jupyterhub/jupyterhub.pid"

# One local process per user, each with its own persistent HOME. No system
# accounts and no sudo are needed: every single-user server runs as the
# container's own user but in a separate home directory, which is what gives
# each AD user their private, persistent SageMath notebooks.
c.JupyterHub.spawner_class = "jupyterhub.spawner.SimpleLocalProcessSpawner"
c.SimpleLocalProcessSpawner.home_dir_template = "/srv/userhomes/{username}"
c.Spawner.default_url = "/lab"
c.Spawner.start_timeout = 120
c.Spawner.http_timeout = 120

# Optional comma-separated list of hub administrators (AD login names).
admins = {u.strip() for u in _env("HUB_ADMIN_USERS").split(",") if u.strip()}
if admins:
    c.Authenticator.admin_users = admins

# --- Authentication: Active Directory / LDAP --------------------------------
# When LDAP is not configured yet nobody can log in (the hub still starts, so
# the module is manageable and the Settings page can enable it).
if _bool("LDAP_ENABLED", False):
    from ldapauthenticator import LDAPAuthenticator

    c.JupyterHub.authenticator_class = LDAPAuthenticator
    c.LDAPAuthenticator.server_address = _env("LDAP_HOST")
    c.LDAPAuthenticator.server_port = int(_env("LDAP_PORT", "636") or "636")
    # LDAPS on connect; AD refuses simple binds over plain :389.
    c.LDAPAuthenticator.tls_strategy = "on_connect"

    login_attr = _env("LDAP_USER_ATTRIBUTE", "sAMAccountName") or "sAMAccountName"
    c.LDAPAuthenticator.user_attribute = login_attr

    # Look the user's DN up with a read-only service account, then bind as the
    # user to verify the password.
    c.LDAPAuthenticator.lookup_dn = True
    c.LDAPAuthenticator.bind_dn_template = []
    c.LDAPAuthenticator.lookup_dn_search_user = _env("LDAP_BIND_DN")
    c.LDAPAuthenticator.lookup_dn_search_password = _env("LDAP_BIND_PASSWORD")
    c.LDAPAuthenticator.user_search_base = _env("LDAP_BASE_DN")
    c.LDAPAuthenticator.lookup_dn_search_filter = "({login_attr}={login})"
    c.LDAPAuthenticator.lookup_dn_user_dn_attribute = login_attr
    c.LDAPAuthenticator.escape_userdn = False
    # Keep the plain login name as the JupyterHub username (not the full DN).
    c.LDAPAuthenticator.use_lookup_dn_username = False

    # Restrict access to members of one AD group (by full group DN).
    group_dn = _env("LDAP_GROUP")
    if group_dn:
        c.LDAPAuthenticator.allowed_groups = [group_dn]
        c.LDAPAuthenticator.group_search_filter = "(member={userdn})"
        c.LDAPAuthenticator.group_attributes = ["member"]
