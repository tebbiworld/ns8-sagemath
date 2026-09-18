<!--
First community post for the NS8 SageMath module, written in the style
of https://community.nethserver.org/t/ns8-forgejo-testing/28554 (first post).
Paste into a new topic on community.nethserver.org, category "App", tag "ns8".
Fill in the wiki link once the page is published.
-->

# NS8 SageMath (testing)

Hi all,

I've built an NS8 module for [SageMath](https://www.sagemath.org/) — the open-source mathematics system, running in the browser as a multi-user JupyterHub so a whole class or research group can share one server.

It's in my community repository. To try it, add the repo once:

```
api-cli run add-repository --data '{"name":"tebbiworld","url":"https://raw.githubusercontent.com/tebbiworld/ns8-repo/main/ns8/updates/","status":true,"testing":false}'
```

then install **SageMath** from the Software Center. (Or straight from the image: `add-module ghcr.io/tebbiworld/sagemath:latest 1`.)

What it does:

* Wraps the official SageMath image into a multi-user JupyterHub — people log in and each gets their own persistent JupyterLab with the SageMath kernel ready to go.
* Users sign in with their **Active Directory / LDAP** account, optionally restricted to a single AD group (there's a *Load groups* picker in the settings).
* Every user gets a private, persistent home under a named volume, so worksheets survive restarts and updates.
* Published on an FQDN through a single Traefik route with optional Let's Encrypt and HTTP→HTTPS redirection, notebook WebSockets forwarded transparently.

A few things to know:

* AD/LDAP is how people log in — LDAPS is required (AD refuses simple binds on plain `:389`), and without a directory configured the hub runs but nobody can sign in. The module never stores user passwords, only the read-only bind account.
* Each user's server runs as the container's own user in a separate HOME. That gives per-user *files*, which is fine for a trusted group, but it is not OS-level sandboxing between users.
* Unofficial and community-built — not affiliated with or endorsed by the SageMath project.

This one's still in testing, so I'd really value feedback — if you run it for a group, let me know how AD/LDAP login and the per-user homes work out for you.

Docs: NethServer wiki (tebbiworld repository) · Source: [github.com/tebbiworld/ns8-sagemath](https://github.com/tebbiworld/ns8-sagemath)

Thanks!

*Category: App · Tags: ns8*
