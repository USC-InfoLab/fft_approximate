# fft_approximate

PostgreSQL C extension (PGXS) for approximate FFT range aggregates on time series.

Install is two steps: copy files into **that** PostgreSQL installation, then `CREATE EXTENSION` with **your** connection settings. Nothing is inferred from PATH or saved passwords.

## 0. Set PG_CONFIG

Every step below (`install`, `load`, `installcheck`) needs `PG_CONFIG` to locate the PGXS build infrastructure for your target server. Export it once per shell session so you don't repeat it on every command — pick the line for your platform:

| Platform | Command |
|---|---|
| Ubuntu / Debian | `export PG_CONFIG=/usr/lib/postgresql/17/bin/pg_config` (match your running server's major version) |
| macOS — Postgres.app | `export PG_CONFIG=/Applications/Postgres.app/Contents/Versions/latest/bin/pg_config` |
| macOS — postgresql.org / EDB | `export PG_CONFIG=/Library/PostgreSQL/17/bin/pg_config` |
| macOS — Homebrew | `export PG_CONFIG="$(brew --prefix postgresql@17)/bin/pg_config"` |
| Windows — EDB installer | `set "PGROOT=C:\Program Files\PostgreSQL\17"` (cmd.exe, not PG_CONFIG — see Windows section) |
| RDS / Aurora / Cloud SQL | not supported — these hosts don't allow custom C libraries |

`sudo` resets the environment by default, so `PG_CONFIG` won't survive into a `sudo make` call on its own. Every install command below passes it inline (`sudo make PG_CONFIG=$PG_CONFIG install`) to route around that — no need for `sudo -E` or `env_keep` sudoers edits.

## 1. Build and install files

You need write access to `pg_config --pkglibdir` and `pg_config --sharedir` (`sudo` if not writable).

```sh
make
sudo make PG_CONFIG=$PG_CONFIG install
```

### Ubuntu / Debian

Install build dependencies first if you haven't:

```sh
sudo apt-get install postgresql-server-dev-17 build-essential
```

**AppArmor:** some Ubuntu setups run PostgreSQL under an AppArmor profile that restricts which paths the server process may `dlopen()`. If the extension file lands in `pkglibdir` fine but `CREATE EXTENSION` still fails to load it, check `sudo aa-status` and `/etc/apparmor.d/*postgresql*` for a path allowlist that excludes third-party extension directories.

### RHEL / Fedora / Amazon Linux (SELinux)

Install the matching `postgresql-server-devel` package for your distro's package manager, then build/install as above.

On SELinux-enforcing systems, a `.so` copied via plain `cp` may get the wrong security context, causing `could not load library` at `CREATE EXTENSION` time even though file permissions look fine. If that happens:

```sh
sudo restorecon -v $(pg_config --pkglibdir)/fft_approximate.so
```

### macOS — Postgres.app

Postgres.app's bundle lives under `/Applications`, which macOS's **App Management** privacy control guards separately from normal file permissions — `sudo` alone does not grant access to it. This permission is per-app: grant it to **whichever app you're actually running the command from** — Terminal.app, iTerm, Warp, or your editor's integrated terminal (Cursor, VS Code, etc. each show up as their own entry). Granting it to Terminal.app does not cover an editor's built-in terminal, and vice versa.

**System Settings → Privacy & Security → App Management** → enable the app you're using → fully quit it (Cmd+Q, not just close the window) and relaunch it.

Then install normally:

```sh
sudo make PG_CONFIG=$PG_CONFIG install
```

If you skip that step, `make install` falls back to writing into `~/.local/pgsql` instead (no `sudo` needed, no error) — usable, but then `CREATE EXTENSION` needs `make load` rather than `psql -c`, since the files aren't in the server's own directories. Prefer granting App Management access up front and installing into the real bundle.

If the error persists after granting and restarting the right app, double check you granted it to the actual process running your shell — `ps -o comm= -p $(ps -o ppid= -p $$)` from that terminal will print the parent app's name.

### macOS — postgresql.org / EDB download

The installer must include command-line tools.

### macOS — Homebrew server formula

Only if that formula is the cluster you run (not `libpq`).

### Windows — EDB installer

x64 Native Tools prompt, as Administrator:

```bat
set "PGROOT=C:\Program Files\PostgreSQL\17"
nmake /F Makefile.win
nmake /F Makefile.win install
```

If `nmake install` fails with a file-in-use error, the target DLL is likely already loaded by a running `postgres.exe` service. Stop the PostgreSQL service before `install`/`installcheck`, not just before `load`.

### RDS / Aurora / Cloud SQL

Not supported. Those hosts do not let you copy a custom C library into the server.

## 2. Create the extension (needs credentials)

`PGUSER`, `PGDATABASE`, and `PGPASSWORD` are required when the server asks for a password. Set `PGHOST` / `PGPORT` if you are not using the default socket.

```sh
make PGHOST=127.0.0.1 PGPORT=5432 \
     PGUSER=myuser PGPASSWORD=secret PGDATABASE=mydb \
     load
```

Or:

```sh
psql "postgresql://myuser:secret@127.0.0.1:5432/mydb" -c 'CREATE EXTENSION fft_approximate;'
```

## Test

After step 1, with the same connection variables:

```sh
make PGHOST=127.0.0.1 PGPORT=5432 \
     PGUSER=myuser PGPASSWORD=secret PGDATABASE=postgres \
     installcheck
```

`installcheck` runs `type`, `avg` (synthetic coefficients), and `cohort_hr` (constant heart-rate style DC windows).

Windows: `nmake /F Makefile.win installcheck` with `PGROOT` and the same libpq variables.

## Usage

```sql
SELECT approximate_avg(c, 0, 10, 10 ORDER BY k) FROM coeffs;
```

`complex` is the coefficient type (`(re+imj)`). `re()` / `im()` / `+` are provided. `t1`, `t2`, `signal_len` are integer indexes. Harmonic index is row order (0 = DC).

`create_approximation(...)` is not implemented.

## License

MIT. See [LICENSE](LICENSE).