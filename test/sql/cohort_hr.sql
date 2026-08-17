-- Constant heart-rate style signal: mean 72 over L=1000 samples, window [0, 1000].
-- DC coefficient scales as mean * L (the aggregate divides by period).
SELECT round(re(approximate_avg(c, 0, 1000, 1000 ORDER BY k))::numeric, 6) AS avg_hr
FROM (VALUES (0, '(72000+0j)'::complex)) t(k, c);

-- Same cohort, sub-window [250, 750] — constant signal average unchanged
SELECT round(re(approximate_avg(c, 250, 750, 1000 ORDER BY k))::numeric, 6) AS avg_hr
FROM (VALUES (0, '(72000+0j)'::complex)) t(k, c);

-- Second subject in cohort: mean 68.5, L=500
SELECT round(re(approximate_avg(c, 0, 500, 500 ORDER BY k))::numeric, 6) AS avg_hr
FROM (VALUES (0, '(34250+0j)'::complex)) t(k, c);
