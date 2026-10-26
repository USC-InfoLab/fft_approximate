# AGENTS.md — fft_approximate

PostgreSQL C extension (PGXS) for **approximate range aggregates over FFT-compressed time series**. Install and platform notes for humans: [README.md](./README.md). The shared W4H architecture overview is at the end of this file.

## Where this repo fits in W4H

- **Layer:** contribution, `kind: postgres_extension`, catalog slug **`fft-approximate`** (seeded in `w4h-api/data/schema.sql`). The catalog row is documentation only; it is not `runnable`.
- **Runtime position:** it lives **inside the operator's PostgreSQL server**, below the API. `w4h-api` never calls it, and `w4h-docker` does not ship it, because Postgres is external (ADR-015). ADR-023 explicitly keeps it out of the SQL-job engine: it is installed with `CREATE EXTENSION`, then used from notebooks.
- **Why it exists:** wearable signals are large (the Fitbit sample's calories file alone is over 1.2M rows). Storing a few FFT coefficients per series and answering range averages from them trades exactness for size and speed.
- **Who uses it:** `w4h-demo-approximate-queries` reads a bounded slice of an imported signal table (for example `ds_sample_fitbit_csv.fitbit_heart_rate`), computes coefficients in NumPy, inserts them into a `(k, c complex)` table, and compares `approximate_avg` with the exact mean. A future `kind: sql` job may call these functions from vetted SQL once the extension is installed (ADR-023 §3).
- **Upstream dependency:** none inside W4H. It only needs a self-managed PostgreSQL whose `pg_config` you can build against.

## What this repo is not

- Not a W4H API client: no API keys, no `csv-batch`, no `w4h` schema DDL.
- Not a coefficient builder: `create_approximation(...)` is **not implemented**. Callers insert coefficients themselves.
- Not supported on RDS, Aurora or Cloud SQL, which do not allow custom C libraries.

## Layout

```text
sql/fft_approximate--1.0.sql   CREATE TYPE complex, operators, approximate_avg(...)
src/complex.c / complex.h      complex type I/O; the text format is a client contract
src/avg.c                      approximate_avg aggregate
test/sql/*.sql, test/expected/ installcheck regression cases: type, avg, cohort_hr
Makefile / Makefile.win        PGXS build; custom install targets (NO_INSTALL = 1)
fft_approximate.control, META.json
```

**SQL surface:**

- Coefficients live in a table ordered by harmonic index `k` (0 = DC term).
- `approximate_avg(c, t1, t2, signal_len ORDER BY k)`: `t1`, `t2` and `signal_len` are integer indexes into the original signal.
- `complex` literals are `(re+imj)` / `(re-imj)`. `(1.5+-2.5j)` is rejected; Python clients format with `f"({c.real}{c.imag:+}j)"`.
- For a constant signal, the DC coefficient equals `mean * signal_len`, so a DC-only `approximate_avg` returns the mean (covered by `cohort_hr`).

## Commands

Every build, install and test target needs **`PG_CONFIG`** pointing at the **same** server you will run `CREATE EXTENSION` on. Platform-specific paths are in README §0.

| Command | Purpose |
|---|---|
| `make` | Build `fft_approximate.so` |
| `sudo make PG_CONFIG=$PG_CONFIG install` | Copy into the server's `pkglibdir` / `sharedir` (`sudo` resets env, so pass `PG_CONFIG` inline) |
| `make PGHOST=… PGUSER=… PGPASSWORD=… PGDATABASE=… load` | `CREATE EXTENSION fft_approximate` |
| `make PGHOST=… PGUSER=… PGPASSWORD=… PGDATABASE=postgres installcheck` | Run the regression suite |
| Windows | `nmake /F Makefile.win`, `install`, `installcheck` with `PGROOT` set |

If the server directories are not writable, install falls back to `~/.local/pgsql` and you must use `make load`. On macOS Postgres.app, grant **App Management** to the terminal app you are using (README).

## Playbooks

**Add or change an aggregate**

1. Implement in `src/*.c`; keep `IMMUTABLE STRICT PARALLEL SAFE` consistent with existing functions.
2. Declare it in the extension SQL script. Shipping a new version means a new `sql/fft_approximate--<ver>.sql` and an `EXTVERSION` bump.
3. Add `test/sql/<case>.sql` + `test/expected/<case>.out` and list the case in `REGRESS`.
4. Run `installcheck` against a real local server.
5. Update `w4h-demo-approximate-queries` if the notebook depends on the change, and the optional-extension section of `w4h-docs/guide/docker-deployment.md` if install steps change.

**Change `complex` text I/O**

The demo's `tests/test_coeffs.py` pins the literal format. Change both together.

## Hard boundaries

| Rule | Reason |
|---|---|
| Do not claim managed-Postgres support | Custom `.so` files cannot be loaded there |
| Do not add W4H API calls, ingest or MET formulas | Those belong to the API and other contributions (ADR-023) |
| Do not drop `installcheck` cases without replacement | It is the only automated test harness |
| Never commit credentials | `PGPASSWORD` belongs on the command line or in the environment |

## Git expectations for agents

- Do not `git commit` or `git push` unless the user asks.
- Intentional output changes must update `test/expected/*.out` in the same change.
- Catalog text lives in `w4h-api/data/schema.sql`; install docs live in `w4h-docs`; accuracy narrative lives in `w4h-demo-approximate-queries`.

<!-- BEGIN w4h-system-overview: identical in every W4H repo's AGENTS.md. Edit all copies together. -->

## W4H system overview (shared across all repos)

**W4H (Wearables for Health) Toolkit** loads wearable-device data into PostgreSQL, organizes it by team, project and dataset, controls access, and runs curated analyses on it. Each signal is a **GeoMTS** (Geospatial Multivariate Time Series) table whose roles (`subject`, `time`, optional `geo`, `values[]`) are stored in `w4h.tables.mapping_json`, not in fixed column names. Three repos form the platform, one packages it, and the rest are **contributions** listed in the in-app catalog (`w4h.contributions`).

| Repo | Role |
|---|---|
| `w4h-api` | Express API and Postgres DDL (`w4h` schema): auth, ACL, ingest, catalog, contribution runner, SQL engine. Port 2026 |
| `w4h-app` | Vue 3 + Vite SPA; talks only to `w4h-api`. Port 5173 |
| `w4h-docs` | Product rules, MVP, ADRs and guides; imported by the API as in-app Help. Owns product decisions |
| `w4h-docker` | Compose stack (`api`, `app`, `notebooks`) built from sibling repos; Postgres is external |
| `w4h-sample-fitbit-csv`, `w4h-sample-icde-demo-csv` | Synthetic sample CSVs plus `manifest.yaml` (ICDE includes a `gps_track` geo signal) |
| `w4h-sample-fitbit-csv-importer`, `w4h-sample-icde-demo-csv-importer` | Runnable importers (notebook, CLI, `run.sh`) for those samples |
| `w4h-fitbit-csv-file-importer` | Runnable importer for user-supplied Fitbit CSVs: profile headers, review a drafted mapping, ingest |
| `w4h-sql-compute-mets` | SQL contribution (YAML + SQL template) that `w4h-api` executes in-process |
| `fft_approximate` | Postgres C extension, catalog slug `fft-approximate`; no API involvement |
| `w4h-demo-approximate-queries` | Notebook comparing `fft_approximate` with exact averages over direct Postgres |

**Main flows:**

1. **Ingest:** importers post 500-row chunks to `POST /datasets/:id/import/csv-batch`. `lib/ingest-csv.js` creates `ds_<dataset_id>.<table_prefix>_<signal>` and upserts its `w4h.tables` mapping.
2. **In-app Run (ADR-022):** `POST /contributions/:slug/run` makes `lib/contribution-runner.js` spawn `../<slug>/run.sh` with the user's `W4H_API_KEY`, `W4H_API_BASE` and `W4H_DATASET_ID`. Stdout lines `@@PROGRESS@@ {json}` drive the progress bar.
3. **SQL analytics (ADR-023):** `lib/sql-contribution-engine.js` reads `../<slug>/manifest.yaml` and `sql/`, binds identifiers from `w4h.tables`, and runs in-process. There is no free-SQL endpoint.
4. **Extensions:** the operator installs `fft_approximate` on their Postgres; notebooks call it directly.

**Layout:** clone every repo as a sibling in one folder. The API finds contributions at `../<slug>` (override `CONTRIBUTION_RUNNER_REPO_ROOT`) and docs at `DOCS_REPO_PATH=../w4h-docs`.

**Cross-repo changes:** `w4h-api` first (regenerate `API_INDEX.md`), then `w4h-app`, then `w4h-docs`. Catalog rows are seeded in `w4h-api/data/schema.sql`. Start at `w4h-docs/dev/mvp.md` and `w4h-docs/dev/ADR-README.md` for decisions, and `w4h-docs/dev/developer-setup.md` for local setup, getting an API key, test personas, troubleshooting, per-repo test commands, default branches and a glossary. Do not commit or push unless asked; never commit `.env` files, API keys or participant data.

<!-- END w4h-system-overview -->
