# Configuraible options
#   MODE = release | debug (default: debug)
#   SNAPPY = 0 | 1 (default: 1)
#
CSTDFLAG = --std=c99 -pedantic -Wall -Wextra -Wno-unused-parameter
CPPFLAGS += -fPIC -Iinclude -Iexternal/snappy
CPPFLAGS += -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64
CPPFLAGS += -D_XOPEN_SOURCE=500 -D_DARWIN_C_SOURCE
LDFLAGS += -lpthread
SRCS_common = test/main.c
CFLAGS_common ?= -Wall -std=gnu99
CFLAGS_orig = -O0
CFLAGS_opt  = -O0

EXEC = test/phonebook_orig \
test/phonebook_bptree \
test/phonebook_opt \
test/phonebook_bulk

ifeq ($(MODE),release)
	CPPFLAGS += -O3
	DEFINES += -DNDEBUG
else
	CFLAGS += -g
endif
 
# run make with SNAPPY=0 to turn it off
ifneq ($(SNAPPY),0)
	DEFINES += -DBP_USE_SNAPPY=1
else
	DEFINES += -DBP_USE_SNAPPY=0
endif

all: external/snappy/config.status bplus.a

external/snappy/config.status:
	(git submodule init && git submodule update && cd external/snappy)
	(cd external/snappy && ./autogen.sh && ./configure)

OBJS= 
ifneq ($(SNAPPY),0)
	OBJS += external/snappy/snappy-sinksource.o
	OBJS += external/snappy/snappy.o
	OBJS += external/snappy/snappy-c.o
endif
OBJS += src/utils.o
OBJS += src/writer.o
OBJS += src/values.o
OBJS += src/pages.o
OBJS += src/bplus.o

deps := $(OBJS:%.o=%.o.d)

bplus.a: $(OBJS)
	$(AR) rcs bplus.a $(OBJS)

src/%.o: src/%.c
	$(CC) $(CFLAGS) $(CSTDFLAG) $(CPPFLAGS) $(DEFINES) \
		-o $@ -MMD -MF $@.d -c $< 

external/snappy/snappy.o: external/snappy/snappy.cc
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $< -o $@
external/snappy/snappy-c.o: external/snappy/snappy-c.cc
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $< -o $@
external/snappy/snappy-sinksource.o: external/snappy/snappy-sinksource.cc
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $< -o $@

test/phonebook_orig: $(SRCS_common) test/phonebook_orig.c test/phonebook_orig.h
	$(CC) $(CFLAGS_common) $(CFLAGS_orig) \
		-DIMPL="\"phonebook_orig.h\"" -o $@ \
		$(SRCS_common) $@.c
test/phonebook_opt: $(SRCS_common) test/phonebook_opt.c test/phonebook_opt.h
	$(CC) $(CFLAGS_common) $(CFLAGS_opt) \
		-DIMPL="\"phonebook_opt.h\"" -DOPT -o $@ \
		$(SRCS_common) $@.c
test/phonebook_bptree: $(SRCS_common) bplus.a test/phonebook_bptree.c test/phonebook_bptree.h
	$(CXX) $(CPPFLAGS_common) $(CFLAGS_opt) \
		-DIMPL="\"phonebook_bptree.h\"" -DBPTREE -o $@ \
		$(SRCS_common) bplus.a $(LDFLAGS)
test/phonebook_bulk: $(SRCS_common) bplus.a test/phonebook_bptree.c test/phonebook_bptree.h
    $(CXX) $(CPPFLAGS_common) $(CFLAGS_opt) \
        -DIMPL="\"phonebook_bptree.h\"" -DBULK -o $@ \
        $(SRCS_common) phonebook_bptree.c ../bplus.a $(LDFLAGS)

deps := $(OBJS:%.o=%.o.d)

src/%.o: src/%.c
	$(CC) $(CFLAGS) $(CSTDFLAG) $(CPPFLAGS) $(DEFINES) \
		-o $@ -MMD -MF $@.d -c $<

external/snappy/%.o: external/snappy/%.cc
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $< -o $@

TESTS =
TESTS += test/original_test/test-api
TESTS += test/original_test/test-reopen
TESTS += test/original_test/test-range
TESTS += test/original_test/test-corruption
TESTS += test/original_test/test-bulk
TESTS += test/original_test/test-threaded-rw
TESTS += test/original_test/bench-basic
TESTS += test/original_test/bench-bulk
TESTS += test/original_test/bench-multithread-get

check: $(TESTS)
	@test/original_test/test-api
	@test/original_test/test-reopen
	@test/original_test/test-range
	@test/original_test/test-bulk
	@test/original_test/test-corruption
	@test/original_test/test-threaded-rw

test/%: test/%.cc bplus.a
	$(CXX) $(CFLAGS) $(CPPFLAGS) $< -o $@ bplus.a $(LDFLAGS)

cache-test: $(EXEC)
	perf stat --repeat 100 -e cache-misses,cache-references,instructions,cycles test/phonebook_orig
	perf stat --repeat 100 -e cache-misses,cache-references,instructions,cycles test/phonebook_opt
	perf stat --repeat 10 -e cache-misses,cache-references,instructions,cycles test/phonebook_bptree
	perf stat --repeat 10 -e cache-misses,cache-references,instructions,cycles test/phonebook_bulk

output.txt: cache-test ./test/calculate
	./test/calculate

plot: all output.txt
	gnuplot test/scripts/runtime.gp

./test/calculate: test/calculate.c
	$(CC) $(CFLAGS_common) $^ -o $@
clean:
	rm -f bplus.a
	rm -f $(OBJS) $(TESTS) $(deps)
	$(RM) $(EXEC) *.o perf.* ./test/calculate test/orig.txt opt.txt output.txt bptree.txt runtime.png

.PHONY: all check clean

-include $(deps)
