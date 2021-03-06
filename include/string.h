#ifndef _STRING_H
#define _STRING_H

/* prototypes */
void *memset(void *s, int c, size_t n);
int memcmp(const void *s1, const void *s2, size_t n);

void bzero(void *s, size_t n);

char * strcpy(char *dest, const char *src);
size_t strlen (const char* str);

#endif /* _STRING_H */
