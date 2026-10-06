# AGENTS.md — fft_approximate

PostgreSQL C extension (PGXS) for approximate range averages over a time series stored as FFT coefficients. Listed in the W4H Contributions catalog as `kind: postgres_extension` (ADR-018). W4H does not vendor it: an admin installs it on the institution's Postgres.

## What is here

| Path | Role |
|------|------|
| `src/complex.c`, `src/complex.h` | `complex` type: text in/out (`(re+imj)`), binary send/recv, `+`, `re()`, `im()` |
| `src/avg.c` | `approximate_avg(c, t1, t2, signal_len ORDER BY k)` aggregate: per-harmonic integral over `[t1, t2]`, summed, divided by `t2 - t1` |
| `sql/fft_approximate--1.0.sql` | SQL names for the C functions. Changing a signature needs a new version file + upgrade script |
| `test/sql`, `test/expected` | pg_regress tests (`make installcheck`) |
| `bench/real_heart_rate.py` | Live accuracy/timing check against sibling `w4h-sample-fitbit-csv` |
| `install.sh` | Admin-only install (checks superuser, then `make install` + `make load`) |
| `contribution.yaml` | W4H test contract |

## Rules

- The extension does **not** compute the FFT. Callers pass coefficients from `numpy.fft.fft` (or equivalent), harmonics `0..L/2` only, one row per harmonic, `ORDER BY k`. `create_approximation(...)` is not implemented — do not document it as if it were.
- The harmonic number is the **row position** in the aggregate, not the value of `k`. Missing rows, NULL rows or a missing `ORDER BY` silently shift the result.
- `TOPK = 100` in `avg.c`: the 102nd row is always treated as the Nyquist harmonic. Keep queries to at most 101 coefficients until that is fixed.
- Only `re()` of the result is meaningful for real signals.
- `test/sql/known_issues.sql` records current wrong-but-silent behavior on purpose. A fix must update its expected output in the same change and the README "Known issues" list.
- Every C change: add or update a test with a hand-computable expected value (see `test/sql/waves.sql` for the coefficient convention).
- Never mark the extension `trusted` in the control file. C code runs inside the server process; install stays superuser-only.
- No patient data in tests or fixtures. `bench/` reads the public synthetic sample only and writes only to schema `fft_bench`.

## Commands

```sh
export PG_CONFIG=...              # README step 0
make && make install              # build + copy into the server
make installcheck                 # tests (needs PGUSER etc. if not local trust)
PGUSER=... PGDATABASE=... ./install.sh   # admin install into one database
python bench/real_heart_rate.py   # live check, see contribution.yaml
```
