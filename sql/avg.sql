CREATE FUNCTION fft_accum(anyarray, complex, integer, integer, integer) 
  RETURNS anyarray AS '/usr/lib/postgresql/complex.so', 'fft_accum' 
  LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION complex_fft(anyarray) 
  RETURNS complex AS '/usr/lib/postgresql/complex.so', 'complex_fft' 
  LANGUAGE C IMMUTABLE STRICT;

CREATE AGGREGATE approximate_avg(complex, integer, integer, integer) 
  (sfunc = fft_accum, stype = float8[], finalfunc = complex_fft, initcond = '{0,0,0,0}');