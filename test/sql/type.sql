SELECT '(1+2j)'::complex AS c;
SELECT '(1-2j)'::complex AS c;
SELECT '(-1+2j)'::complex AS c;
SELECT '(-1-2j)'::complex AS c;
SELECT re('(1+2j)'::complex) AS re, im('(1+2j)'::complex) AS im;
SELECT '(1+2j)'::complex + '(3-4j)'::complex AS sum;
SELECT complex_add('(1+2j)'::complex, '(3-4j)'::complex) AS sum;
