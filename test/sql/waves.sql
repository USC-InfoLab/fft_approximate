-- Signals with a wave in them, so the non-DC branch of avg.c is exercised.
-- Coefficients follow numpy.fft.fft: X0 = sum of samples, a wave of
-- amplitude A at harmonic k gives X_k = A*L/2 (cosine) or -A*L/2 j (sine).
-- Only harmonics 0..L/2 are passed; the mirrored half is implied.
-- Expected values are the continuous average of the signal over [t1, t2].

-- x(t) = 70 + 10*cos(2*pi*t/8), L = 8
-- full period and half period: the wave cancels out, average is 70
SELECT round(re(approximate_avg(c, 0, 8, 8 ORDER BY k))::numeric, 6) AS full_period
FROM (VALUES (0, '(560+0j)'::complex), (1, '(40+0j)'::complex)) t(k, c);

SELECT round(re(approximate_avg(c, 0, 4, 8 ORDER BY k))::numeric, 6) AS half_period
FROM (VALUES (0, '(560+0j)'::complex), (1, '(40+0j)'::complex)) t(k, c);

-- quarter period [0, 2]: 70 + 20/pi = 76.366198
SELECT round(re(approximate_avg(c, 0, 2, 8 ORDER BY k))::numeric, 6) AS quarter_period
FROM (VALUES (0, '(560+0j)'::complex), (1, '(40+0j)'::complex)) t(k, c);

-- x(t) = 70 + 10*sin(2*pi*t/8), L = 8 (imaginary coefficient)
-- [0, 4] is the high half: 70 + 20/pi = 76.366198
-- [4, 8] is the low half:  70 - 20/pi = 63.633802
SELECT round(re(approximate_avg(c, 0, 4, 8 ORDER BY k))::numeric, 6) AS sine_high_half
FROM (VALUES (0, '(560+0j)'::complex), (1, '(0-40j)'::complex)) t(k, c);

SELECT round(re(approximate_avg(c, 4, 8, 8 ORDER BY k))::numeric, 6) AS sine_low_half
FROM (VALUES (0, '(560+0j)'::complex), (1, '(0-40j)'::complex)) t(k, c);

-- two waves: x(t) = 80 + 10*cos(2*pi*t/8) + 4*cos(2*pi*2t/8), window [0, 2]
-- 80 + 20/pi + 0 (second wave completes a half period... integral is 0) = 86.366198
SELECT round(re(approximate_avg(c, 0, 2, 8 ORDER BY k))::numeric, 6) AS two_waves
FROM (VALUES (0, '(640+0j)'::complex), (1, '(40+0j)'::complex), (2, '(16+0j)'::complex)) t(k, c);

-- one aggregate per subject with GROUP BY (cohort use)
SELECT id, round(re(approximate_avg(c, 0, 2, 8 ORDER BY k))::numeric, 6) AS avg_hr
FROM (VALUES
  ('s1', 0, '(560+0j)'::complex), ('s1', 1, '(40+0j)'::complex),
  ('s2', 0, '(480+0j)'::complex), ('s2', 1, '(0-40j)'::complex)
) t(id, k, c)
GROUP BY id ORDER BY id;

-- empty window (t1 = t2) returns NULL
SELECT approximate_avg(c, 5, 5, 8 ORDER BY k) IS NULL AS empty_window_is_null
FROM (VALUES (0, '(560+0j)'::complex)) t(k, c);

-- a reversed window gives the same average as the forward one
SELECT round(re(approximate_avg(c, 2, 0, 8 ORDER BY k))::numeric, 6) AS reversed_window
FROM (VALUES (0, '(560+0j)'::complex), (1, '(40+0j)'::complex)) t(k, c);
