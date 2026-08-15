-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION fft_approximate" to load this file. \quit

CREATE TYPE complex;

CREATE FUNCTION complex_in(cstring)
RETURNS complex
AS 'MODULE_PATHNAME', 'complex_in'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION complex_out(complex)
RETURNS cstring
AS 'MODULE_PATHNAME', 'complex_out'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION complex_recv(internal)
RETURNS complex
AS 'MODULE_PATHNAME', 'complex_recv'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION complex_send(complex)
RETURNS bytea
AS 'MODULE_PATHNAME', 'complex_send'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE TYPE complex (
    internallength = 16,
    input = complex_in,
    output = complex_out,
    receive = complex_recv,
    send = complex_send,
    alignment = double
);

CREATE FUNCTION complex_add(complex, complex)
RETURNS complex
AS 'MODULE_PATHNAME', 'complex_add'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE OPERATOR + (
    leftarg = complex,
    rightarg = complex,
    procedure = complex_add,
    commutator = +
);

CREATE FUNCTION re(complex)
RETURNS float8
AS 'MODULE_PATHNAME', 'complex_re'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION im(complex)
RETURNS float8
AS 'MODULE_PATHNAME', 'complex_im'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION complex_avg_accum(float8[], complex, integer, integer, integer)
RETURNS float8[]
AS 'MODULE_PATHNAME', 'complex_avg_accum'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION complex_avg(float8[])
RETURNS complex
AS 'MODULE_PATHNAME', 'complex_avg'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE AGGREGATE approximate_avg(complex, integer, integer, integer) (
    sfunc = complex_avg_accum,
    stype = float8[],
    finalfunc = complex_avg,
    initcond = '{0,0,0,0}'
);
