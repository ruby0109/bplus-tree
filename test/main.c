#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <assert.h>

#include IMPL

#if defined(BPTREE)||defined(BULK)
#include "../include/bplus.h"
#define BP_FILE "/tmp/bp_tree.bp"
#define BULK_SIZE 350000
#include <unistd.h>
#endif
#if defined(BULK)
#include <sys/mman.h>
#include "file.c"
#include <fcntl.h>
#define ALIGN_FILE "align.txt"
#endif

#define DICT_FILE "./dictionary/words.txt"

static double diff_in_second(struct timespec t1, struct timespec t2)
{
    struct timespec diff;
    if (t2.tv_nsec-t1.tv_nsec < 0) {
        diff.tv_sec  = t2.tv_sec - t1.tv_sec - 1;
        diff.tv_nsec = t2.tv_nsec - t1.tv_nsec + 1000000000;
    } else {
        diff.tv_sec  = t2.tv_sec - t1.tv_sec;
        diff.tv_nsec = t2.tv_nsec - t1.tv_nsec;
    }
    return (diff.tv_sec + diff.tv_nsec / 1000000000.0);
}

int main(int argc, char *argv[])
{
    FILE *fp;
    int i = 0;
    char line[MAX_LAST_NAME_SIZE];
    struct timespec start, end;
    double cpu_time1, cpu_time2;

#if !defined(BULK)
    /* check file opening */
    fp = fopen(DICT_FILE, "r");
    if (fp == NULL) {
        printf("cannot open the file\n");
        return -1;
    }
#else
    /* Align data file to MAX_LAST_NAME_SIZE one line*/
    file_align(DICT_FILE, ALIGN_FILE, MAX_LAST_NAME_SIZE);
    int fd = open(ALIGN_FILE, O_RDONLY | O_NONBLOCK);
    off_t fs = fsize(ALIGN_FILE);
#endif

#if defined(BPTREE)||defined(BULK)
    if(access(BP_FILE,F_OK)==0) assert(unlink(BP_FILE) ==0);
    bp_db_t db;
    bp_open(&db, "BP_FILE");
#else
    /* build the entry */
    entry *pHead, *e;
    pHead = (entry *) malloc(sizeof(entry));
    printf("size of entry : %lu bytes\n", sizeof(entry));
    e = pHead;
    e->pNext = NULL;
#endif

#if defined(__GNUC__) && !defined(BPTREE) && !defined(BULK)
    __builtin___clear_cache((char *) pHead, (char *) pHead + sizeof(entry));
#endif

    clock_gettime(CLOCK_REALTIME, &start);

#if defined(BULK)
    /* mmap for data file*/
    char *map = (char*) mmap(NULL, fs, PROT_READ | PROT_WRITE, MAP_PRIVATE, fd, 0);
    assert(map && "mmap error");

    char *bulk_data[BULK_SIZE];
    int bulk_data_count = fs / MAX_LAST_NAME_SIZE;

    for(i=0; i < bulk_data_count; i++) {
        bulk_data[i] = map + MAX_LAST_NAME_SIZE * i;
    }
    bp_bulk_sets(&db,
                 bulk_data_count,
                 (const char**) bulk_data,
                 (const char**) bulk_data);

#else
    i = 0;
    while (fgets(line, sizeof(line), fp)) {
        while (line[i] != '\0')
            i++;
        line[i - 1] = '\0';
        i = 0;
#if defined(BPTREE)
        bp_sets(&db, line, line);
#else
        e = append(line, e);
#endif
    }
#endif
    clock_gettime(CLOCK_REALTIME, &end);
    cpu_time1 = diff_in_second(start, end);
#if !defined(BULK)
    /* close file as soon as possible */
    fclose(fp);
#endif

    /* the givn last name to find */
    char input[MAX_LAST_NAME_SIZE] = "zyxel";
#if defined(BPTREE)||defined(BULK)
    char* foundName;
    assert(bp_gets(&db, input, &foundName) == BP_OK);
    assert(0== strcmp(foundName, "zyxel"));
    free(foundName);
#else
    e = pHead;
    assert(findName(input, e) && "Did you implement findName() in " IMPL "?");
    assert(0 == strcmp(findName(input, e)->lastName, "zyxel"));
#endif
#if defined(__GNUC__) && !defined(BPTREE) && !defined(BULK)
    __builtin___clear_cache((char *) pHead, (char *) pHead + sizeof(entry));
#endif
    /* compute the execution time */
    clock_gettime(CLOCK_REALTIME, &start);
#if defined(BPTREE)||defined(BULK)
    bp_gets(&db, input, &foundName);
#else
    findName(input, e);
#endif
    clock_gettime(CLOCK_REALTIME, &end);
    cpu_time2 = diff_in_second(start, end);
    FILE *output;
#if defined(OPT)
    output = fopen("opt.txt", "a");
#elif defined(BPTREE)
    output = fopen("bptree.txt", "a");
#elif defined(BULK)
    output = fopen("bulk.txt","a");
#else
    output = fopen("orig.txt", "a");
#endif
    fprintf(output, "append() findName() %lf %lf\n", cpu_time1, cpu_time2);
    fclose(output);

    printf("execution time of append() : %lf sec\n", cpu_time1);
    printf("execution time of findName() : %lf sec\n", cpu_time2);


#if !defined(BPTREE) && !defined(BULK)
    if (pHead->pNext) free(pHead->pNext);
    free(pHead);
#endif
    return 0;
}
