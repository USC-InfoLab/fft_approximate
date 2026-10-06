"""Approximate vs exact average heart rate on the W4H Fitbit sample.

Live test (see contribution.yaml). Needs fft_approximate installed in the
target database and w4h-sample-fitbit-csv checked out next to this repo.

    pip install -r bench/requirements.txt
    PGDATABASE=fft_lab python bench/real_heart_rate.py

Everything is written to a scratch schema `fft_bench`, dropped at the start.
Readings are treated as a sequence (index = reading number), not a time grid,
because the sample has large gaps (0.4% to 66% of minutes present).
"""
import os
import random
import time
from pathlib import Path

import numpy as np
import psycopg

SAMPLE = Path(__file__).resolve().parents[2] / "w4h-sample-fitbit-csv" / "data" / "fitbit_heart_rate.csv"
KS = [1, 5, 20, 50, 100]
WINDOWS_PER_SUBJECT = 30

random.seed(7)
conn = psycopg.connect(autocommit=True)  # libpq env: PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE
cur = conn.cursor()

cur.execute("DROP SCHEMA IF EXISTS fft_bench CASCADE; CREATE SCHEMA fft_bench")
cur.execute("CREATE TABLE fft_bench.raw (id text, date date, t time, value double precision)")
with SAMPLE.open() as f, cur.copy("COPY fft_bench.raw FROM STDIN WITH (FORMAT csv, HEADER true)") as cp:
    for line in f:
        cp.write(line)
cur.execute("""
    CREATE TABLE fft_bench.hr AS
    SELECT id, date + t AS ts, value,
           (row_number() OVER (PARTITION BY id ORDER BY date + t) - 1)::int AS idx
    FROM fft_bench.raw;
    CREATE INDEX ON fft_bench.hr (id, idx);
    CREATE TABLE fft_bench.coeffs (id text, k int, c complex);
""")

lengths = {}
for (s,) in cur.execute("SELECT DISTINCT id FROM fft_bench.hr ORDER BY id").fetchall():
    x = np.array([r[0] for r in cur.execute("SELECT value FROM fft_bench.hr WHERE id = %s ORDER BY idx", (s,))])
    lengths[s] = len(x)
    X = np.fft.fft(x)[: max(KS)]  # keep only the waves we query (fewer than the TOPK=100 limit + 1)
    with cur.copy("COPY fft_bench.coeffs (id, k, c) FROM STDIN") as cp:
        for k, v in enumerate(X):
            cp.write_row((s, k, f"({v.real:.17g}{v.imag:+.17g}j)"))
cur.execute("CREATE INDEX ON fft_bench.coeffs (id, k)")


def approx(s, K, t1, t2):
    return cur.execute(
        "SELECT re(approximate_avg(c, %s, %s, %s ORDER BY k)) FROM fft_bench.coeffs WHERE id = %s AND k < %s",
        (t1, t2, lengths[s], s, K)).fetchone()[0]


def exact(s, t1, t2):
    return cur.execute("SELECT avg(value) FROM fft_bench.hr WHERE id = %s AND idx >= %s AND idx < %s",
                       (s, t1, t2)).fetchone()[0]


print(f"Error vs exact average, {WINDOWS_PER_SUBJECT} random windows per subject (median %)")
print(f"{'subject':9} {'readings':>8}  " + "  ".join(f"K={K:<5}" for K in KS))
all_errs = {K: [] for K in KS}
for s, L in lengths.items():
    wins = []
    for _ in range(WINDOWS_PER_SUBJECT):
        w = random.randint(max(2, L // 50), max(3, L // 2))
        t1 = random.randint(0, L - w)
        wins.append((t1, t1 + w))
    cells = []
    for K in KS:
        errs = [abs(approx(s, K, a, b) - e) / e * 100 for a, b in wins for e in [exact(s, a, b)]]
        all_errs[K] += errs
        cells.append(f"{np.median(errs):6.2f}%")
    print(f"{s:9} {L:8}  " + "  ".join(cells))
print(f"{'median':9} {'':8}  " + "  ".join(f"{np.median(all_errs[K]):6.2f}%" for K in KS))
print(f"{'worst':9} {'':8}  " + "  ".join(f"{np.max(all_errs[K]):6.2f}%" for K in KS))


def ms(sql, n=20):
    t = time.perf_counter()
    for _ in range(n):
        cur.execute(sql).fetchall()
    return (time.perf_counter() - t) / n * 1000


print("\nTiming, all subjects, whole range (ms, average of 20 runs)")
print(f"exact AVG over {sum(lengths.values())} raw rows:   {ms('SELECT id, avg(value) FROM fft_bench.hr GROUP BY id'):.1f}")
print("approximate from 100 coefficients:  "
      f"{ms('SELECT id, re(approximate_avg(c, 0, 1000, 1000 ORDER BY k)) FROM fft_bench.coeffs GROUP BY id'):.1f}")
