CC ?= gcc
CFLAGS_common ?= -Wall -std=gnu99
CFLAGS_orig = -O0
CFLAGS_opt  = -O0
CSTDFLAG = --std=c99 -pedantic -Wall -Wextra -Wno-unused-parameter
CPPFLAGS += -fPIC -Iinclude -Iexternal/snappy
CPPFLAGS += -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64
CPPFLAGS += -D_XOPEN_SOURCE=500 -D_DARWIN_C_SOURCE
LDFLAGS += -lpthread


EXEC = phonebook_orig \
phonebook_bptree \
phonebook_opt \
phonebook_bulk

all: $(EXEC)

SRCS_common = main.c

phonebook_orig: $(SRCS_common) phonebook_orig.c phonebook_orig.h
	$(CC) $(CFLAGS_common) $(CFLAGS_orig) \
		-DIMPL="\"$@.h\"" -o $@ \
		$(SRCS_common) $@.c

phonebook_opt: $(SRCS_common) phonebook_opt.c phonebook_opt.h
	$(CC) $(CFLAGS_common) $(CFLAGS_opt) \
		-DIMPL="\"$@.h\"" -DOPT -o $@ \
		$(SRCS_common) $@.c

phonebook_bptree: $(SRCS_common) ../bplus.a phonebook_bptree.c phonebook_bptree.h
	$(CXX) $(CPPFLAGS_common) $(CFLAGS_opt) \
		-DIMPL="\"$@.h\"" -DBPTREE -o $@ \
		$(SRCS_common) $@.c ../bplus.a $(LDFLAGS)

phonebook_bulk: $(SRCS_common) ../bplus.a phonebook_bptree.c phonebook_bptree.h
	$(CXX) $(CPPFLAGS_common) $(CFLAGS_opt) \
		-DIMPL="\"phonebook_bptree.h\"" -DBULK -o $@ \
		$(SRCS_common) phonebook_bptree.c ../bplus.a $(LDFLAGS)

run: $(EXEC)
	echo 3 | sudo tee /proc/sys/vm/drop_caches
	watch -d -t "./phonebook_orig && echo 3 | sudo tee /proc/sys/vm/drop_caches"

cache-test: $(EXEC)
	perf stat --repeat 100 \
		-e cache-misses,cache-references,instructions,cycles \
		./phonebook_orig
	perf stat --repeat 100 \
		-e cache-misses,cache-references,instructions,cycles \
		./phonebook_opt
	perf stat --repeat 10 \
		-e cache-misses,cache-references,instructions,cycles \
		./phonebook_bptree
	perf stat --repeat 10 \
		-e cache-misses,cache-references,instructions,cycles \
		./phonebook_bulk

output.txt: cache-test calculate
	./calculate

plot: output.txt
	gnuplot scripts/runtime.gp

calculate: calculate.c
	$(CC) $(CFLAGS_common) $^ -o $@

.PHONY: clean
clean:
	$(RM) $(EXEC) *.o perf.* \
	      	calculate orig.txt opt.txt output.txt runtime.png bptree.txt bulk.txt
