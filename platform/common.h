#ifndef __common_H__
#define __common_H__

struct image {
    char         kind;
    const void * bytes;
    int          length;
};

#define IMAGE_KIND_NONE (0)
#define IMAGE_KIND_PNG  (1)
#define IMAGE_KIND_TIFF (2)

struct files {
    const char ** names;
    int           count;
};

#endif // __common_H__
