# AGENTS.md

RPM packaging + runtime config generator + Ansible addin that installs Bacula
backup (Director/Storage Daemon) support into an [ApisCP](https://apiscp.com)
host. Target is Enterprise Linux 10 with EPEL's Bacula 15. There is no
application code and no test/lint/CI tooling.

## Layout

- `conf/` — installed verbatim to `/etc/bacula/`.
  - `conf.d/` — shipped defaults. **Never edit installed files here at runtime;**
    `conf.d/*.sh` regenerate Bacula include files from `conf.d/servers/*.conf`
    on each service start. `bacula-dir.sh` emits client/Job/Storage/Pool
    resources; `bacula-sd.sh` emits a `Device` per slot under `local.d/servers/`.
  - `local.d/` — user overrides. `helpers.sh:flexible_check` resolves
    `local.d/<name>` before `conf.d/<name>`, so user customizations win.
- `plays/bacula-setup/` — Ansible addin, installed to
  `%{apnscp_root}/resources/playbooks/addins/` and run by `%run_apnscp_addin`.
- `apnscp-bacula.spec` — the RPM. `apnscp-bacula-latest.rpm` is a **symlink**
  pointing at the current release artifact (materialized as a plain text file on
  Windows checkouts; git still tracks it as a symlink).
- `README.md` — user-facing install/backup/restore docs. Keep it in sync with
  behavior changes; it is the source of truth for operators.

## Build

```bash
rpmbuild -bb --define 'apnscp_root /usr/local/apnscp' apnscp-bacula.spec
```

The spec sets `_sourcedir` to the repo root, so run it from there. On a plain
EL10 host the `--define` is required: `%{apnscp_root}` is otherwise left literal
and files land under a bogus path. `%run_apnscp_addin` is only expanded at
install time, so it does not block the build. Output is
`~/rpmbuild/RPMS/noarch/apnscp-bacula-<ver>-<rel>.el10.noarch.rpm`.

Config can be smoke-tested without ApisCP by installing EPEL `bacula-*` and
running the `conf/conf.d/*.sh` generators followed by
`bacula-dir -t -c /etc/bacula/bacula-dir.conf` / `bacula-sd -t`. The Ansible
addin itself requires ApisCP (ansible-core, `community.mysql`/`community.postgresql`,
and ApisCP roles) and cannot run here.

## Release workflow

1. Bump `Release:` and add a `%changelog` entry in `apnscp-bacula.spec`.
2. Repoint the `apnscp-bacula-latest.rpm` symlink at the new
   `apnscp-bacula-<version>-<release>.el10.noarch.rpm`.
3. Keep `%files` in the spec in sync with any added/removed files under `conf/`
   and `plays/`; unmatched files break the build.

## Gotchas

- All text files are pinned to LF via `.gitattributes`. Do not introduce CRLF;
  the `conf.d/*.sh` generators run under `set -euo pipefail` and a `\r` breaks
  them (and the RPM build). If `git status` shows the whole tree modified,
  check line endings before committing.
- This repo is often checked out on a Windows/9p mount where symlinks are not
  supported and `core.symlinks=false`. Repoint `apnscp-bacula-latest.rpm` with
  `git update-index --cacheinfo 120000,<blob>,apnscp-bacula-latest.rpm` rather
  than editing the file, or the symlink becomes a regular file.
- `conf/conf.d/*.sh` source `/etc/sysconfig/bacula-vars`; templates rely on
  `${VAR}` env expansion via `env_fill` (perl) and
  `%NAME%`/`%PASSWORD%`/`%ADDRESS%`/`%FILESET%`/`%N%` substitution (awk). Files
  concatenated by `bacula-dir.sh` (e.g. `servers/storage.conf`) must end with a
  newline or they swallow the next resource.
- EL10/EPEL Bacula is built with native catalog drivers only: `dbdriver` must be
  `mysql`/`postgresql`/`sqlite3`, never `dbi:<x>`. The distro
  `update_*_tables` scripts hardcode `db_name=bacula` (only `make_*_tables`
  honor the `db_name` env), so schema migration only supports the default name.
- No automated verification exists. Test changes against a real Bacula install
  using the flows in `README.md`.