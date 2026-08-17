EXTENSION = fft_approximate
EXTVERSION = 1.0

MODULE_big = $(EXTENSION)
OBJS = src/complex.o src/avg.o
DATA = sql/$(EXTENSION)--$(EXTVERSION).sql
PGFILEDESC = "fft_approximate - approximate FFT range aggregates"

REGRESS = type avg cohort_hr
REGRESS_OPTS = --inputdir=test --load-extension=$(EXTENSION)

SHLIB_LINK += -lm

# Own install: PGXS always copies into pg_config --pkglibdir, which is not
# writable for Postgres.app. We copy into the server when we can, else $HOME.
NO_INSTALL = 1

srcdir := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

ifneq ($(MAKECMDGOALS),clean)

ifndef PG_CONFIG
$(error Set PG_CONFIG to this server's pg_config, e.g. make PG_CONFIG=/Applications/Postgres.app/Contents/Versions/latest/bin/pg_config)
endif

PGXS := $(shell "$(PG_CONFIG)" --pgxs 2>/dev/null)
ifeq ($(wildcard $(PGXS)),)
$(error "$(PG_CONFIG) --pgxs" is not a usable server pg_config (file missing).)
endif

$(info using PG_CONFIG=$(PG_CONFIG))

include $(PGXS)

PKGLIBDIR_ABS := $(shell "$(PG_CONFIG)" --pkglibdir)
SHAREDIR_ABS := $(shell "$(PG_CONFIG)" --sharedir)
USER_PREFIX := $(HOME)/.local/pgsql
PSQL := $(shell "$(PG_CONFIG)" --bindir)/psql
CONTROL_IN_SERVER := $(SHAREDIR_ABS)/extension/$(EXTENSION).control

export PGHOST
export PGPORT
export PGUSER
export PGPASSWORD
export PGDATABASE

.PHONY: install
install: all
	@w_err=$$(touch "$(PKGLIBDIR_ABS)/.fft_w" 2>&1); \
	if [ $$? -eq 0 ]; then \
	  rm -f "$(PKGLIBDIR_ABS)/.fft_w"; \
	  dest_lib="$(PKGLIBDIR_ABS)"; \
	  dest_share="$(SHAREDIR_ABS)/extension"; \
	else \
	  dest_lib="$(USER_PREFIX)/lib"; \
	  dest_share="$(USER_PREFIX)/share/extension"; \
	  echo "Cannot write $(PKGLIBDIR_ABS) ($$w_err); installing to $$dest_lib"; \
	  echo "On macOS, if this says 'Operation not permitted' even with sudo, see the macOS section in README.md (System Settings > Privacy & Security > App Management)."; \
	fi; \
	mkdir -p "$$dest_lib" "$$dest_share"; \
	cp "$(MODULE_big)$(DLSUFFIX)" "$$dest_lib/"; \
	cp "$(srcdir)$(EXTENSION).control" "$$dest_share/"; \
	cp "$(srcdir)sql/$(EXTENSION)--$(EXTVERSION).sql" "$$dest_share/"; \
	echo "library $$dest_lib/$(MODULE_big)$(DLSUFFIX)"; \
	echo "sql     $$dest_share/"

.PHONY: load
load:
	@if [ -z "$(PGDATABASE)" ] || [ -z "$(PGUSER)" ]; then \
	  echo "Set PGDATABASE and PGUSER (optional: PGHOST, PGPORT, PGPASSWORD)"; \
	  exit 1; \
	fi
	@if [ -f "$(CONTROL_IN_SERVER)" ]; then \
	  "$(PSQL)" -v ON_ERROR_STOP=1 -c "CREATE EXTENSION IF NOT EXISTS $(EXTENSION);"; \
	else \
	  echo "Loading from $(USER_PREFIX) (pass PGHOST PGPORT PGUSER PGPASSWORD PGDATABASE)"; \
	  sed -e '/^\\echo/d' \
	      -e "s|'MODULE_PATHNAME'|'$(USER_PREFIX)/lib/$(MODULE_big)'|g" \
	      "$(srcdir)sql/$(EXTENSION)--$(EXTVERSION).sql" \
	    | "$(PSQL)" -v ON_ERROR_STOP=1 -f -; \
	fi

else

.PHONY: clean
clean:
	rm -f src/*.o src/*.obj src/*.bc
	rm -f fft_approximate.so fft_approximate.dylib fft_approximate.dll
	rm -f fft_approximate.lib fft_approximate.exp libfft_approximate.a libfft_approximate.pc
	rm -rf results/ regression.diffs regression.out tmp_check/ tmp_check_iso/ log/ output_iso/

endif
