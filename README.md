# aptmirror Salt formula

Installs a vendored and locally maintained copy of the Perl `apt-mirror`
utility, configures one or more Debian-style mirrors, and optionally schedules
synchronization with a hardened systemd timer.

The formula does **not** install the distribution `apt-mirror` package and does
not download application code on managed systems. The script is shipped in
`files/apt-mirror`; only its ordinary runtime dependencies are installed.

## Supported platforms

| Distribution | Supported releases |
| --- | --- |
| Debian | 12 (Bookworm), 13 (Trixie) |
| Ubuntu | 22.04 LTS, 24.04 LTS, 26.04 LTS |

Other platforms fail explicitly. The formula requires systemd and a modern
Salt release with `slsutil.merge` and Jinja JSON serialization.

## Vendored script provenance

The embedded script was retrieved from
[`apt-mirror/apt-mirror`](https://github.com/apt-mirror/apt-mirror) master at
commit `2ef8e73f700c0989f7f8e4347fbf76cf3b8ce132`, dated 2023-11-01. The pristine
script SHA-256 was
`8e2ee9712837f76f0fd820c32de47fdcf5376b24ba765d6aece6f6cad8bd8709`.

The upstream GPL-2.0 license is included in [`LICENSE`](LICENSE). Local changes
are documented in the script header and include:

- zstd (`.zst`) index discovery and decompression;
- selectable Contents, installer/udeb, DEP-11, command-not-found, and
  translation metadata;
- comma-separated architectures in modern `[arch=amd64,arm64]` syntax;
- Release-driven metadata discovery, including upstream `Acquire-By-Hash`,
  DEP-11, command-not-found, translations, and `binary-all` behavior;
- usable `InRelease` or `Release` metadata required by default;
- strict index and archive download failure propagation;
- SHA-256 requirements for package and source entries;
- Release-declared SHA-256/SHA-512 metadata verification;
- archive SHA-256 verification before metadata is published;
- atomic publication of Release and index metadata;
- corrected insecure-fallback source paths;
- configurable retries and network timeouts;
- safer decompression, cleanup path validation, and non-recursive removal;
- post-mirror script failure propagation.

## Managed resources

- Removal of the distribution `apt-mirror` package by default.
- Perl, wget, TLS certificates, compression tools, and checksum utilities.
- A dedicated `apt-mirror` system user and group.
- `/usr/local/bin/apt-mirror` from the embedded formula copy.
- `/etc/apt-mirror/mirror.list`.
- Mirror, staging, state, and log directories.
- An optional post-mirror script.
- `apt-mirror-sync.service` and `apt-mirror-sync.timer`.

The formula does not configure a web server. Serve the appropriate directory
below `paths:mirror` with nginx, Apache, or another static file server.

## Usage

Copy `pillar.example` into the pillar tree, select the repositories and
architectures actually required, then assign the formula:

```yaml
base:
  'roles:apt-mirror':
    - match: grain
    - aptmirror
```

Preview the state before enabling the timer:

```console
salt 'mirror-*' state.apply aptmirror test=True
salt 'mirror-*' state.apply aptmirror
```

Run an initial synchronization manually as the service account:

```console
systemctl start apt-mirror-sync.service
journalctl -u apt-mirror-sync.service
```

APT mirrors can consume hundreds of gigabytes. Estimate upstream repository
size and available storage before the first run.

## Available states

| State | Purpose |
| --- | --- |
| `aptmirror` | Complete runtime, configuration, and timer workflow. |
| `aptmirror.install` | Remove the packaged utility, install dependencies, create the account, and deploy the embedded script. |
| `aptmirror.config` | Manage directories, mirror configuration, and optional post-mirror script. |
| `aptmirror.service` | Manage hardened systemd service and timer units. |

## Pillar and defaults

All settings are below `aptmirror`. `defaults.yml` contains complete defaults;
`map.jinja` adds Debian-family paths and recursively merges pillar over them.
Lists are replaced rather than appended.

The timer is disabled by default, and the default mirror list is empty. This
prevents a newly assigned minion from unexpectedly starting a large download.

### Repository declarations

Each item in `mirrors` accepts:

| Key | Meaning |
| --- | --- |
| `name` | Human-readable comment in `mirror.list`. |
| `uri` | Upstream repository root, preferably HTTPS. |
| `suites` | Release suites such as `trixie` and `trixie-updates`. |
| `components` | Components such as `main`, `contrib`, and `non-free-firmware`. |
| `architectures` | Binary architectures. Multiple values render one `[arch=…]` line. |
| `sources` | Mirror source packages when true. |
| `clean` | Include this repository in obsolete-file cleanup. Defaults to true. |

Example:

```yaml
aptmirror:
  mirrors:
    - name: Debian 13
      uri: https://deb.debian.org/debian
      suites:
        - trixie
        - trixie-updates
      components:
        - main
        - contrib
        - non-free
        - non-free-firmware
      architectures:
        - amd64
        - arm64
      sources: false
      clean: true
```

Use separate entries when suites come from different roots, such as Debian
security or Ubuntu security. `raw_lines` can express unusual flat or vendor
repositories directly in apt-mirror syntax. `skip_clean` protects repository
roots that must never be pruned.

Credentials embedded in repository URIs appear in the generated config and
must come from protected pillar. The config is mode `0640`. Prefer scoped,
read-only credentials and HTTPS.

The formula does not download signing keys. A mirror must preserve upstream
signed metadata unchanged; clients should trust the distribution or vendor key
through their own keyring management.

### Paths

`paths` defines the base, published mirror, staging (`skel`), state/log (`var`),
cleanup script, and post-mirror script paths. Specify resolved absolute paths;
do not use `$base_path` substitutions in pillar because Salt must create and
authorize these directories before execution.

Repository content appears below a host/path directory. For example,
`https://deb.debian.org/debian` is stored below:

```text
/var/spool/apt-mirror/mirror/deb.debian.org/debian
```

### Integrity and modern metadata

`allow_insecure: false` requires a usable upstream `InRelease` or `Release`
file. It does not cryptographically verify the signature locally; downstream
APT clients remain responsible for signature verification. Enabling insecure
fallback is intended only for controlled legacy vendor repositories.

`require_sha256: true` rejects Release metadata without SHA-256 or SHA-512 and
rejects package or source entries without SHA-256. `verify_hashes: true`
verifies downloaded metadata, verifies existing archive files while processing
indexes, automatically re-downloads corrupt local files, and verifies new
archive downloads before publishing metadata. Keep both enabled for modern
repositories.

When upstream advertises `Acquire-By-Hash: yes`, the script downloads the
strongest advertised hash path and publishes both by-hash and canonical index
locations. Metadata is staged separately and published only after archive
downloads and checksum verification succeed, reducing inconsistent mirror
windows.

`contents` controls large Contents indexes. Disabling it saves bandwidth and
space but limits tools that depend on file-to-package lookup data.

`installer` includes `debian-installer` indexes and udeb packages. `dep11` and
`command_not_found` control desktop software metadata and Ubuntu's
command-not-found indexes. `translations` accepts a comma-separated language
list, `all`, or `none`; the default mirrors English only.

### Network controls

`nthreads`, `limit_rate`, `retries`, `connect_timeout`, and `read_timeout`
control wget behavior. An empty `limit_rate` means unlimited. Proxy and mutual
TLS options are available under `settings`.

Keep `no_check_certificate` false. Disabling TLS certificate validation exposes
the mirror process to metadata substitution and should only be used in a
temporary, isolated recovery scenario.

### Cleanup

Cleanup is limited to repository roots explicitly emitted with `clean`. The
script validates cleanup paths and never generates recursive `rm -r` commands.

With `autoclean: false`, synchronization writes an executable cleanup script
but does not run it. Review the script before manual execution. With
`autoclean: true`, obsolete files are removed automatically after a successful
download and metadata publication.

### Scheduling and hardening

`schedule:enabled` controls the systemd timer. `on_calendar` accepts systemd
calendar syntax. `randomized_delay` avoids many mirrors starting at the same
instant, and `persistent` catches up after downtime.

The oneshot service runs unprivileged and uses systemd filesystem, kernel, home,
device, address-family, and privilege restrictions. It can write only beneath
`paths:base` plus `schedule:extra_read_write_paths`.

If a post-mirror script publishes into a web root outside the mirror base, add
that destination to `extra_read_write_paths`. The script should still use
least-privilege ownership.

## Migration from the previous formula

This refactor intentionally removes:

- installation of the distribution `apt-mirror` package;
- `/usr/bin/apt-mirror` replacement;
- cron and `/etc/cron.d/apt-mirror` management;
- legacy Ubuntu Trusty/Xenial SaltStack repository examples;
- runtime wget commands for repository signing keys;
- implicit repository-directory calculations containing URL credentials;
- the old nested `mirrors:<name>:releases` pillar schema.

Translate old releases into individual entries under the new `mirrors` list.
The executable is now `/usr/local/bin/apt-mirror`, configuration is under
`/etc/apt-mirror`, and scheduling uses systemd.

## References

- [apt-mirror upstream](https://github.com/apt-mirror/apt-mirror)
- [Debian repository format](https://wiki.debian.org/DebianRepository/Format)
- [APT by-hash design](https://wiki.ubuntu.com/AptByHash)
- [Salt map-file guidance](https://docs.saltproject.io/salt/user-guide/en/latest/topics/map-files.html)

## Relationship to upstream

**This is a heavily modified fork of
[`saltstack-formulas/aptmirror-formula`](https://github.com/saltstack-formulas/aptmirror-formula). Do not treat it as a drop-in
replacement for it.**

States have been renamed, split, merged, and removed; pillar keys have moved;
defaults differ; and behaviour has changed in ways that are not backward
compatible. Pointing an existing deployment at this formula without reading
`pillar.example` and the state list above will not do what you expect.

It is also not a newer version of upstream — it diverged and was maintained
separately, so upstream may well have fixes and platform support that this
does not. If you want the maintained original, use
[`saltstack-formulas/aptmirror-formula`](https://github.com/saltstack-formulas/aptmirror-formula).

### Credit

The foundation of this formula, and much of what still works well in it, is
the work of the [saltstack-formulas](https://github.com/saltstack-formulas) authors and contributors. Any
bugs introduced in the divergence are this fork's own.

Specific third-party files bundled here, with their own authors and
licenses, are itemised in [THIRD-PARTY.md](THIRD-PARTY.md).

## License

GPL-2.0 — see [LICENSE](LICENSE). Unlike the other formulas in this set,
this one is **not** public domain, because it embeds a modified copy of the
GPL-2.0 `apt-mirror` script. See [THIRD-PARTY.md](THIRD-PARTY.md).
