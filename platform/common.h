#ifndef __common_H__
#define __common_H__

struct image {
    const char * kind; // File extension in lower case: "png", "jpg", "tiff", etc. Empty string means no image.
    const void * bytes;
    int          length;
};

struct files {
    const char ** names;
    int           count;
};

struct clipboard_content {
    const char * text;
    struct image image;
    struct files files;
};

#endif // __common_H__
