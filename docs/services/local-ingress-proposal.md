# LAN-first service access: DNS, proxy, identity, and Tailscale

Status: research proposal, not an implementation. Researched 2026-11-05.
No NixOS, DNS, Tailscale, or application settings were changed for this proposal.

## Goal and recommendation

The primary requirement is that **household devices can use services on the
LAN without installing or enabling Tailscale**, while approved users are
authenticated and authorized through Pocket ID and TinyAuth. Remote users
should use the same URLs, with Tailscale providing private network access.

Recommended stack:

- **AdGuard Home:** household DNS, filtering, and local service-name rewrites.
- **Traefik:** LAN-reachable HTTPS ingress with label-driven service discovery.
- **Pocket ID:** identity provider; household accounts, passkeys, and groups.
- **TinyAuth:** checks browser sessions and per-application access policies
  before Traefik passes requests to applications.
- **Tailscale:** remote transport to the LAN ingress, not a prerequisite for
  using it while at home.
- **An owned domain with DNS-01 certificates:** recommended for trusted HTTPS
  on ordinary household devices. `home.arpa` is a valid alternative if managing
  a private certificate authority is acceptable.

Keep NixOS, Podman, existing service modules, the shared container network,
Agenix, and the backup approach. Test on a separate host before migrating Cobra.
Traefik fits the preference for labels better than Nginx Proxy Manager.

## 1. What changes for someone using a service?

At home, a household member opens a bookmark such as `https://cook.home.example.com`.
Their device asks AdGuard for the address and connects directly to the proxy's
LAN IP. No VPN client is involved. Traefik asks TinyAuth whether access is
allowed. If necessary, TinyAuth redirects the browser to Pocket ID to sign in
with a passkey. Approved users return to the app; others are denied.

Away from home, the user first connects Tailscale and opens **the same bookmark**.
Tailscale split DNS and an approved subnet route make the same proxy reachable.
The same TinyAuth policy applies. Nothing needs to be exposed publicly.

**Authentication is required on both paths.** This does not need Traefik's
Tailscale certificate integration: both LAN and Tailscale traffic reach the
same protected Traefik router. A trusted tailnet device is not automatically
an approved application user. Do not add a bypass based on Tailscale source IPs.
If old Docktail/`ts.net` URLs remain during migration, they must also pass through
the authentication gate or be retired before considering the app fully protected;
an old direct route would otherwise bypass the new policy.

```text
Household browser, Tailscale OFF
  -> router/DHCP-provided DNS -> AdGuard -> proxy LAN address
  -> Traefik HTTPS -> TinyAuth access decision -> application
                        |
                        +-> Pocket ID login when needed

Remote browser, Tailscale ON
  -> Tailscale split DNS -> reachable AdGuard -> same proxy LAN address
  -> approved subnet route -> Traefik -> same identity/access checks
```

DNS, routing, TLS, and authorization are separate layers. A DNS record alone
does not make a service reachable; a VPN connection alone does not approve an
application user. Returning a `100.x` Tailscale address to LAN-only clients
would leave the current problem unsolved.

## 2. Namespace and HTTPS choices

The standardized residential suffix is **`home.arpa`**, not `home.apra`.
RFC 8375 reserves it for local home-network naming. Avoid inventing `.home`
and avoid `.local`, which is used by multicast DNS. [1]

| Choice | Example | TLS | Household-device experience |
| --- | --- | --- | --- |
| Owned domain, private DNS (recommended) | `cook.home.<owned-domain>` | Publicly trusted certificate via DNS-01 | Normal HTTPS, no custom root installation |
| Reserved private namespace | `cook.home.arpa` | Private CA and certificates | Install and trust the CA on each client; some apps have separate trust stores |
| Existing Tailscale names | `cook.<tailnet>.ts.net` | Tailscale certificates | Useful for existing VPN access, but not itself a LAN-first architecture |

`example.com` in this document is a documentation placeholder, **not a domain
to deploy or request certificates for**. Choose a domain you control before
implementation, for example a dedicated `home` subdomain of that domain.

### Recommended: owned domain, private services, real TLS

Use private DNS to map service names to the proxy's LAN IP. Public authoritative
DNS need not publish service A/AAAA records pointing to the home network.
Traefik uses ACME DNS-01 to create temporary public `_acme-challenge` TXT records
and obtain/renew certificates. DNS-01 can issue wildcard certificates without
opening inbound WAN ports 80 or 443. Outbound access and working public DNS
automation are still required for issuance and renewal. [5]

Prefer a narrowly scoped DNS API token, or delegate the challenge zone where
the provider/ACME tooling supports it. Keep credentials in Agenix runtime files,
not labels, Git, or the Nix store. Persist certificate state and monitor expiry.
Use the CA's staging endpoint while testing to avoid production rate limits.

A certificate for `*.home.<owned-domain>` covers `cook.home.<owned-domain>`,
but not `home.<owned-domain>` or `a.b.home.<owned-domain>`. Include the base name
separately if required. Public certificates are logged in Certificate
Transparency; wildcard issuance can disclose the chosen namespace even without
public service addresses. Private DNS is not a secrecy guarantee.

### Alternative: home.arpa and a private CA

Public CAs cannot issue normal publicly trusted certificates for this locally
scoped namespace. Private-CA TLS is still real encryption and authentication
when clients trust the CA. Traefik can load certificates issued by that CA;
automated private-CA issuance needs a separate supported issuance workflow.
Caddy is worth considering if its built-in internal CA is more valuable than
first-party Docker-provider support. [1, 5, 10]

Do not settle for clicking through browser certificate warnings. Pocket ID's
passkeys require a secure browser context, and certificate trust must work on
every participating device. Test phones, passkey providers, and native apps
before committing to this option. It is more administration than an owned
domain with DNS-01, especially for visitors and unmanaged devices.

### What Traefik's Tailscale integration actually does

Traefik's Tailscale certificate resolver obtains certificates from the local
Tailscale daemon for supported `machine-name.<tailnet>.ts.net` names. It does
not issue `*.home.arpa` or owned-domain certificates, distribute LAN DNS,
create arbitrary service identities, or replace routing. [4]

A certificate validates a hostname, not whether packets used LAN or VPN.
Making an existing `ts.net` name work locally would still require deliberate
local DNS and a proxy holding the correct certificate for that Tailscale
identity. It is not the cleanest foundation for a new household namespace.
Use ordinary DNS-01 for the recommended architecture; Tailscale remains transport.

## 3. DNS and remote routing

### LAN: no Tailscale dependency

1. Give the test proxy a stable LAN address using a reservation or static IP.
2. Configure AdGuard rewrites for the chosen service names to that address.
   AdGuard supports explicit records and wildcard rewrites. A wildcard DNS
   answer does **not** automatically create a Traefik application route. [2]
3. Configure the router's DHCP DNS advertisement to use AdGuard, initially only
   on a designated test client/network. Consider IPv6 DNS advertisements too.
4. Ensure Traefik listens on a LAN-reachable address and that the host firewall
   permits the intended LAN clients to reach HTTPS.

For a private zone, resolve/handle it locally rather than leaking unanswered
`home.arpa` queries to public resolvers. Do not configure an unrelated public
resolver as a supposed secondary: clients may choose it even when AdGuard is
healthy, causing intermittent private-name failures. A second resolver should
serve the same local records. Browser secure DNS, Android Private DNS, router
DNS-rebinding protection, and IPv6 can bypass or reject intended answers;
test actual client behavior, not just a DNS query on the server.

### Remote: same DNS answers, routed LAN ingress

The simplest initial model uses **the same LAN-IP answer at home and away**:

- Configure a Tailscale restricted nameserver for the chosen suffix, pointing
  to AdGuard's reachable Tailscale IP or to its LAN IP over a subnet route.
- Permit authorized tailnet devices to query that resolver on TCP/UDP 53.
- Advertise and approve a route covering the proxy's LAN IP. Remote clients
  must accept/use that route; verify platform-specific behavior.
- Permit those devices to reach ingress HTTPS through Tailscale policy and
  the host firewall. Restrict the route and grants to what is needed rather
  than granting the entire household LAN by default. [3]

**Reaching DNS at a Tailscale IP does not make the returned LAN IP reachable.**
The route to the proxy is a separate requirement. Cobra already declares
`192.168.128.0/24` as an advertised route, but advertisement is not evidence
of admin approval, client acceptance, or an effective access policy.

Alternative: return a proxy LAN IP to household clients and a proxy Tailscale
IP to remote clients. That avoids routing application traffic through a LAN
subnet but needs an explicit second DNS view/resolver policy. Merely sending
both populations to the same AdGuard rewrite does not create different answers.
It is an optional later refinement, not the proposed first experiment.

Keep DNS upstreams acyclic: AdGuard must not forward its own private zone back
to Tailscale, which then sends the same question back to AdGuard. Do not expose
an unrestricted DNS resolver or the AdGuard administration UI to the internet.

## 4. Traefik, labels, and NixOS

Traefik's Docker provider discovers containers and builds routers/services from
labels. This preserves the workflow of declaring routing alongside each NixOS
OCI container, rather than maintaining proxy hosts by clicking in a UI. [6]

An illustrative service declaration would eventually include labels like:

```nix
# Concept only: baseDomain is a proposed fleet ingress option, not an existing one.
labels = {
  "traefik.enable" = "true";
  "traefik.docker.network" = "proxy";
  "traefik.http.routers.cook.rule" = "Host(`cook.${baseDomain}`)";
  "traefik.http.routers.cook.entrypoints" = "websecure";
  "traefik.http.routers.cook.tls" = "true";
  "traefik.http.routers.cook.middlewares" = "tinyauth@docker";
  "traefik.http.services.cook.loadbalancer.server.port" = "9080";
};
```

This is **not a complete deployment snippet**. It assumes the HTTPS entrypoint,
certificate selection, shared network, and named TinyAuth middleware have
already been configured. Set `exposedByDefault = false`; applications must opt
in. Explicit backend ports avoid accidentally routing to the wrong exposed port.
Use exact host rules and let unknown hosts fail, rather than forwarding a
wildcard to an arbitrary default application.

Podman offers a Docker-compatible API, and this project already enables it for
Docktail. Validate Traefik's discovery/events and network-address selection
against the project's pinned Podman/Traefik versions before assuming parity.
TinyAuth's own label-based access-control discovery also needs an appropriate
supported connection/configuration; attaching TinyAuth labels alone is not a
complete setup. Use its supported declarative configuration if necessary.

Access to a rootful container API socket is a major privilege boundary.
A `:ro` socket mount does **not** make API requests read-only. Consider a
restricted socket proxy exposing only required read/event endpoints, and
keep it off user-accessible networks. Audit what both discovery consumers need.
The file provider is a fallback that avoids giving Traefik container API access,
at the cost of explicitly generating its routing config. [6]

### Deployment choices and alternatives

- **Traefik container on `proxy`:** best initial fit for this project's existing
  OCI-container conventions, label discovery, backend DNS, and volume backups.
- **Native `services.traefik`:** NixOS supports static/dynamic config options,
  runtime environment files, and a data directory. Valid alternative; account
  for host-to-container connectivity and explicit backups for host state. [11]
- **Caddy:** excellent HTTPS ergonomics; Docker-label discovery comes from the
  third-party `caddy-docker-proxy` project, which documents Podman considerations,
  not from Caddy core. [10]
- **Nginx Proxy Manager:** approachable proxy-host UI/API, but no official generic
  Docker-label discovery workflow was found. Less aligned with this request. [10]

One proxy host does not require replacing all backend hosts. Later, a Traefik
file-provider service can route to another host's explicitly reachable backend.
Docker-provider labels on one machine do not automatically discover an entire
fleet; each additional API endpoint/network path needs deliberate design.

## 5. Approved access with TinyAuth and Pocket ID

These components solve different problems:

| Component | Responsibility | Does not replace |
| --- | --- | --- |
| Tailscale | Private remote transport and network policy | LAN user authentication |
| Pocket ID | Who the person is; passkeys, accounts, groups, OIDC | Proxy enforcement on every app |
| TinyAuth | Browser session and per-app allow/deny decisions | Permissions inside the application |
| Traefik | HTTPS routing and calling the authentication middleware | Application business logic |

### Proposed login configuration

Put identity and auth on the **same locally reachable namespace** as the apps,
for example `id.home.<owned-domain>` and `auth.home.<owned-domain>`. Leaving
Pocket ID exclusively at a VPN-only address would still force household users
onto Tailscale just to log in.

Register a TinyAuth OIDC client in Pocket ID. The documented callback is:

```text
https://auth.home.<owned-domain>/api/oauth/callback/pocketid
```

TinyAuth's current guide documents these Pocket ID endpoints and scopes: [7]

```text
Authorization: https://id.home.<owned-domain>/authorize
Token:         https://id.home.<owned-domain>/api/oidc/token
User info:     https://id.home.<owned-domain>/api/oidc/userinfo
Scopes:        openid email profile groups
```

The current documentation uses v5-style configuration such as
`TINYAUTH_APPURL` and `TINYAUTH_OAUTH_PROVIDERS_POCKETID_*`. Pin a tested image
and follow that version's reference; old examples with differently named
environment variables should not be copied blindly. Store the OIDC client
secret through Agenix. Verify issuer/discovery details and exact redirect URI
against the actual Pocket ID client configuration.

Configure Traefik ForwardAuth to call TinyAuth at
`http://tinyauth:3000/api/auth/traefik` on the internal network. Keep the auth
and Pocket ID routers outside that middleware to prevent login redirect loops;
their own account/admin controls still apply. [7, 8]

TinyAuth uses a parent-domain cookie for sibling applications. Plan the auth
and app names together. Explicitly set `TINYAUTH_AUTH_SECURECOOKIE=true`:
the reviewed v5.2.0 defaults do not enable it. Verify `Secure` and `HttpOnly`
on initial and refreshed cookies as well as the intended cookie scope. Do not
place untrusted applications under the same cookie
namespace. Keep the same canonical HTTPS URLs locally and remotely, rather
than trying to share cookies between `home.arpa` and `ts.net`. Test private
suffix cookie behavior on target browsers if choosing `home.arpa`.

### Approval must be explicit

Create household users in Pocket ID and assign groups such as `household` and
`admins`. Configure each TinyAuth application to require its intended groups;
the documented label is `tinyauth.apps.<app>.oauth.groups`. For example:

```text
tinyauth.apps.cook.oauth.groups = household
tinyauth.apps.admin.oauth.groups = admins
```

Request the `groups` scope and verify the actual claims returned by Pocket ID.
Use explicit supported domain matching for each TinyAuth app and test that its
policy matches the intended Traefik route. Labels shown above are policy intent,
not a complete TinyAuth application definition. [7]

**Require tested deny-by-default behavior.** TinyAuth v5.2.0 defaults to an
`allow` ACL policy, so a missing or mismatched application policy can admit
authenticated users who were never approved for that app. Configure the
supported deny policy and explicit matching approval rules, then test missing
policies and label-discovery failures. Do not merely set
`TINYAUTH_AUTH_ACLS_POLICY=deny` and assume the group-only illustrations above
are complete: in the reviewed implementation, the OAuth whitelist/user rule
also needs an appropriate allow match or it denies before group approval can
succeed. Resolve this interaction using the pinned version's documented
whitelist and group semantics, with positive and negative tests. [7, 12]

Also restrict which users/groups can use the Pocket ID OIDC client where
supported. Do not treat “signed in successfully” as “approved for every app.”
Test an approved user, a signed-in but unapproved user, and a user removed from
a group. In the reviewed v5.2.0 implementation, OAuth groups are stored in the
TinyAuth session and rolling refresh preserves them. Maximum session lifetime
defaults to disabled, so an actively used session can retain stale approval
indefinitely. Require a bounded maximum lifetime and fresh identity checks on
reauthentication, or a verified explicit session-invalidation mechanism. Test
group removal and account disablement while actively refreshing the session;
document the resulting revocation window rather than promising instant removal.
Avoid unintended local-password or other-provider fallback paths around policy.

### Security and application compatibility

- Block direct backend access that bypasses Traefik. Many current containers
  publish host ports; removing a URL from DNS does not close those ports.
  Podman-published ports can bypass the NixOS firewall. Remove unneeded
  publications or constrain them to deliberate private management paths.
- Do not trust identity headers supplied by browsers. Configure trusted proxy
  sources narrowly in both Traefik and TinyAuth, replace/strip untrusted identity
  headers, and only forward the identity headers the backend needs. Do not
  copy broad `trustedIPs` or forwarded-header settings from quick-start examples.
- Proxy authentication does not automatically log someone into the app or make
  them an app administrator. Prefer an app's native Pocket ID OIDC integration
  when it provides the right user/role model. A double login may otherwise remain.
- Native mobile clients, API clients, webhooks, health checks, WebSockets, and
  media clients may not follow browser OAuth redirects. Choose app-native auth,
  a narrowly scoped separately authenticated route, or an explicitly justified
  exception. Never exempt all `/api` routes by default.
- Keep management UIs restricted. A wildcard certificate or a LAN connection
  is not permission to use the Traefik dashboard or AdGuard/Pocket ID admin UI.

## 6. Fit with the current fleet

These are repository declarations, not live-host inspection results:

| Existing area | Finding and implication |
| --- | --- |
| `hosts/cobra/configuration.nix` | Cobra declares LAN `192.168.128.3/24`, router/DNS `192.168.128.1`, Tailscale DNS acceptance, and an advertised LAN subnet. DNS acceptance on Cobra does not configure household DHCP clients. |
| `services/adguard.nix` | AdGuard already exists with host networking and persistent named volumes. Firewall permits DNS 53, HTTP 80, and setup 3000. Inspect its actual bind settings before adding a proxy; port 80 must have one owner per address. |
| `services/docktail.nix`, `modules/podman.nix` | Existing shared `proxy` network and Docker-compatible socket are useful foundations. Docktail labels are not Traefik labels. |
| `hosts/cobra/configuration.nix` | An existing Tailscale Serve NAS mapping uses HTTPS 443. Inspect actual socket ownership/interface binding before deciding whether it can coexist with Traefik; do not assume all port-443 listeners conflict or safely coexist. |
| `services/pocket-id.nix` | Pocket ID module and encrypted key exist, with `APP_URL` derived from MagicDNS. The module is not imported by Cobra's current service list; establish its actual deployment before migration. |
| `modules/container-backup.nix` | Discovers named volumes of imported services. Container-owned state can reuse that approach; a new host still needs its own backup configuration. |

Before putting Traefik on Cobra, move AdGuard's administration listener off any
address/port needed by ingress, and audit Tailscale Serve/Docktail listeners.
Use a separate test host first so these changes are not prerequisites for learning.

### URLs are application configuration too

Changing DNS and proxy labels is not enough. Inventory base/public URL settings,
CORS/CSRF allowlists, trusted proxy settings, OIDC clients/callbacks, webhooks,
bookmarks, and mobile clients. CookCLI, for example, already needed an explicit
`COOK_CORS_ORIGIN`; a new hostname requires updating that allowed origin.

Pocket ID's hostname is especially important: passkeys are bound to a WebAuthn
relying-party identity, and clients depend on its OIDC issuer/URLs. Moving from
`id.<tailnet>.ts.net` to a new domain is an identity migration, not just a DNS
alias. Do not assume old passkeys or sessions transfer. Test with disposable
accounts, retain admin recovery access, and inventory registered clients before
changing an existing deployment. [9]

### Persist and back up the whole trust chain

Plan persistence for AdGuard config/data, Pocket ID data, TinyAuth's selected
version's persistent state/configuration, and Traefik ACME/certificate state.
If using a private CA, back up and strongly protect its signing keys as well.

The existing weekly process covers discovered named volumes only on hosts
where backups are enabled and configured. It does not automatically cover a
new host, arbitrary bind mounts, native `/var/lib/traefik`, or runtime Agenix
secrets. Preserve Pocket ID's exact encryption key separately from its data,
and verify a restore. Test backup-induced outages: the existing job stops
volume-owning containers, so backing up DNS/proxy/identity can briefly affect
the entire household, not just one application.

## 7. Proposed isolated experiment

No infrastructure changes are part of this document. A later implementation
could proceed in these gates:

1. **Choose names and a test host.** Use a distinct LAN IP and namespace such
   as `lab.<owned-domain>` or `lab.home.arpa`. Keep production Docktail working.
2. **Prove plain routing first.** Run Traefik and a disposable test app on the
   shared proxy network. Validate host matching and HTTPS before adding auth.
3. **Prove LAN DNS.** Use only a designated test client's DNS configuration.
   With Tailscale off, confirm the name returns the LAN IP and the browser works.
   Do not replace household DHCP DNS or tailnet-wide settings yet.
4. **Prove identity.** Use a separate test Pocket ID instance/client and TinyAuth.
   Demonstrate approved, denied, and admin-only flows on LAN-only devices.
5. **Prove remote access.** Add the test suffix to Tailscale split DNS and a
   deliberately scoped route/policy. Test from cellular or another external
   network, not just a laptop still on the home Wi-Fi.
6. **Prove operations.** Test renewal, restart, outage behavior, backups, restore,
   access revocation, and the application's API/mobile compatibility.
7. **Migrate deliberately.** Inventory listeners and direct ports, choose canonical
   identity URLs, then migrate one noncritical app before changing household DNS.

Suggested acceptance evidence:

| Test | Required result |
| --- | --- |
| LAN phone/laptop with Tailscale disabled | DNS returns LAN IP; trusted HTTPS; app usable after approved login |
| LAN phone/laptop with no Pocket ID approval | No protected application content, including direct URL requests |
| Signed-in household user on admin app | Denied unless explicitly in the admin policy |
| Direct backend IP/port | Cannot bypass the proxy's protection |
| Remote device with Tailscale | Same URL, valid TLS, same group restrictions |
| Remote device without Tailscale | Private service not reachable from internet |
| Browser secure-DNS / IPv6 client | Expected resolver behavior documented and tested |
| TinyAuth unavailable | No protected application content is forwarded |
| Pocket ID unavailable | New logins fail; existing approved TinyAuth sessions may continue, with behavior documented |
| Missing/mismatched app ACL or unavailable discovery | No unapproved access, including for already-authenticated users |
| Group removal/account disablement during active use | Revocation meets a documented bound; rolling refresh cannot extend stale approval indefinitely |
| Initial and refreshed session cookies | Correct domain scope and `Secure`/`HttpOnly` flags |
| Unknown host and spoofed identity headers | No unintended backend access or user impersonation |
| Restore from backup | Accounts, keys, certificates/config, and intended policies recover correctly |

Use the repository's Nix parse/evaluation checks before a later deployment;
they cannot establish DNS behavior, browser cookies, TLS trust, or passkey login.
Those require the real client/network tests above.

Rollback: keep old Docktail routes and existing production URLs until tests
pass. Revert the test client's resolver and the test split-DNS/route changes
to stop using the experiment. Once canonical identity URLs/passkeys migrate,
rollback needs an explicit account/client recovery plan; it is no longer just
a proxy-config rollback.

## 8. Decisions before implementation

1. Owned domain with DNS-01 (recommended), or `home.arpa` with a managed private CA?
2. Which host/IP will own test DNS and ingress, and which DNS provider supports
   appropriately scoped ACME automation?
3. Which household/admin groups may use which apps? Which apps need native OIDC,
   mobile/API routes, or deliberately different treatment?
4. Where is Pocket ID actually deployed today, and is its existing identity
   hostname worth preserving versus performing a planned migration?
5. How should DNS/proxy/auth downtime be handled: acceptable single-host outage,
   or a later second DNS server and a separate availability design?

The best first result is one working LAN-only client and one protected test app,
not a fleet-wide replacement of Docktail.

## Sources

Sources below are upstream documentation; configuration details should be
checked against pinned versions when implementing.

1. [RFC 8375: home.arpa](https://www.rfc-editor.org/rfc/rfc8375.html),
   [RFC 6762: multicast DNS](https://www.rfc-editor.org/rfc/rfc6762).
2. [AdGuard Home technical documentation: DNS rewrites](https://github.com/AdguardTeam/AdGuardHome/blob/master/AGHTechDoc.md).
3. [Tailscale DNS](https://tailscale.com/docs/reference/dns-in-tailscale),
   [subnet routers](https://tailscale.com/docs/features/subnet-routers).
4. [Traefik Tailscale certificate resolver](https://doc.traefik.io/traefik/reference/install-configuration/tls/certificate-resolvers/tailscale/),
   [Tailscale HTTPS certificates](https://tailscale.com/docs/how-to/set-up-https-certificates).
5. [Let's Encrypt challenge types](https://letsencrypt.org/docs/challenge-types/),
   [local-name certificate discussion](https://letsencrypt.org/docs/certificates-for-localhost/),
   [CA/Browser Forum baseline requirements](https://cabforum.org/working-groups/server/baseline-requirements/).
6. [Traefik Docker provider](https://doc.traefik.io/traefik/providers/docker/),
   [file provider](https://doc.traefik.io/traefik/providers/file/).
7. [TinyAuth getting started](https://tinyauth.app/docs/getting-started/),
   [Pocket ID integration and groups](https://tinyauth.app/docs/guides/pocket-id/),
   [access controls](https://github.com/tinyauthapp/docs/blob/main/src/content/docs/docs/guides/access-controls.mdx),
   [configuration reference](https://github.com/tinyauthapp/docs/blob/main/src/gen/generated_configuration.mdx).
8. [Traefik ForwardAuth](https://doc.traefik.io/traefik/middlewares/http/forwardauth/),
   [TinyAuth behind a proxy](https://github.com/tinyauthapp/docs/blob/main/src/content/docs/docs/guides/advanced.mdx).
9. [Pocket ID documentation](https://pocket-id.org/docs),
   [OIDC client examples](https://pocket-id.org/docs/client-examples).
10. [Caddy automatic HTTPS and local certificates](https://caddyserver.com/docs/automatic-https),
    [Caddy Docker Proxy](https://github.com/lucaslorentz/caddy-docker-proxy),
    [Nginx Proxy Manager](https://github.com/NginxProxyManager/nginx-proxy-manager).
11. [NixOS Traefik module source](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/web-servers/traefik.nix).
12. TinyAuth v5.2.0 source cross-checks:
    [ACL rules](https://github.com/tinyauthapp/tinyauth/blob/v5.2.0/internal/service/access_controls_rules.go),
    [configuration defaults](https://github.com/tinyauthapp/tinyauth/blob/v5.2.0/internal/model/config.go),
    [session creation/refresh](https://github.com/tinyauthapp/tinyauth/blob/v5.2.0/internal/service/auth_service.go),
    [request context and session validation](https://github.com/tinyauthapp/tinyauth/blob/v5.2.0/internal/middleware/context_middleware.go).
