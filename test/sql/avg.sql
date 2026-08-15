-- empty input -> NULL
SELECT approximate_avg(c, 0, 10, 10) AS avg
FROM (SELECT '(1+0j)'::complex AS c WHERE false) t;

-- DC coefficient (N=0) over the full period [0, 10], L=10
-- integral_real = (1/L) * x * period = 1, result = 1/period = 0.1
SELECT re(approximate_avg(c, 0, 10, 10)) AS re,
       im(approximate_avg(c, 0, 10, 10)) AS im
FROM (VALUES ('(1+0j)'::complex)) t(c);

-- same query returning the complex value
SELECT approximate_avg(c, 0, 10, 10) AS avg
FROM (VALUES ('(1+0j)'::complex)) t(c);

-- harmonics are taken in row order: ORDER BY the coefficient index
SELECT re(approximate_avg(c, 0, 10, 10 ORDER BY k)) AS re
FROM (VALUES
  (0, '(2+0j)'::complex),
  (1, '(0+0j)'::complex)
) t(k, c);
