#ifndef _CRYPT_H_
#define _CRYPT_H_

#include "cbasetypes.h"

// Use endian-aware byte swapping from cbasetypes.h
#define SWAP16(x) MITHIA_SWAP16(x)
#define SWAP32(x) MITHIA_SWAP32(x)

#define RAND_INC rand()%0xFF
#define USE_RANDOM_INDEXES

char* generate_hashvalues(const char*, char*, int);
char* populate_table(const char*, char*, int);
int set_packet_indexes(unsigned char*);
char* generate_key2(unsigned char*, char*, char*, int);
char* generate_key(const char*, char*, int);
void mithia_crypt(char*);
void mithia_crypt2(char*, char*);
#endif
