#import <Foundation/Foundation.h>

#import "SFXASSRenderer.h"

#include <errno.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void print_usage(void) {
    fprintf(
        stderr,
        "Usage: ASSRenderingProbe --width pixels --height pixels --timestamp-ms milliseconds --output output.png [--fonts-dir directory] <source.ass>\n"
    );
}

static bool parse_positive_integer(const char *value, NSInteger *integerOut) {
    errno = 0;
    char *end = NULL;
    long long parsed = strtoll(value, &end, 10);
    if (errno != 0 || end == value || *end != '\0' || parsed <= 0 || parsed > INT_MAX) {
        return false;
    }

    *integerOut = (NSInteger)parsed;
    return true;
}

static bool parse_nonnegative_integer(const char *value, NSInteger *integerOut) {
    errno = 0;
    char *end = NULL;
    long long parsed = strtoll(value, &end, 10);
    if (errno != 0 || end == value || *end != '\0' || parsed < 0 || parsed > LONG_LONG_MAX) {
        return false;
    }

    *integerOut = (NSInteger)parsed;
    return true;
}

int main(int argc, char **argv) {
    @autoreleasepool {
        NSInteger width = 0;
        NSInteger height = 0;
        NSInteger timestampMilliseconds = -1;
        NSString *outputPath = nil;
        NSString *fontsDirectory = nil;
        int argumentIndex = 1;

        while (argumentIndex < argc) {
            if (strcmp(argv[argumentIndex], "--width") == 0) {
                if (argumentIndex + 1 >= argc || !parse_positive_integer(argv[argumentIndex + 1], &width)) {
                    fprintf(stderr, "Invalid --width value.\n");
                    print_usage();
                    return 2;
                }
                argumentIndex += 2;
                continue;
            }

            if (strcmp(argv[argumentIndex], "--height") == 0) {
                if (argumentIndex + 1 >= argc || !parse_positive_integer(argv[argumentIndex + 1], &height)) {
                    fprintf(stderr, "Invalid --height value.\n");
                    print_usage();
                    return 2;
                }
                argumentIndex += 2;
                continue;
            }

            if (strcmp(argv[argumentIndex], "--timestamp-ms") == 0) {
                if (argumentIndex + 1 >= argc || !parse_nonnegative_integer(argv[argumentIndex + 1], &timestampMilliseconds)) {
                    fprintf(stderr, "Invalid --timestamp-ms value.\n");
                    print_usage();
                    return 2;
                }
                argumentIndex += 2;
                continue;
            }

            if (strcmp(argv[argumentIndex], "--output") == 0) {
                if (argumentIndex + 1 >= argc) {
                    fprintf(stderr, "Missing --output path.\n");
                    print_usage();
                    return 2;
                }
                outputPath = [NSString stringWithUTF8String:argv[argumentIndex + 1]];
                argumentIndex += 2;
                continue;
            }

            if (strcmp(argv[argumentIndex], "--fonts-dir") == 0) {
                if (argumentIndex + 1 >= argc) {
                    fprintf(stderr, "Missing --fonts-dir path.\n");
                    print_usage();
                    return 2;
                }
                fontsDirectory = [NSString stringWithUTF8String:argv[argumentIndex + 1]];
                argumentIndex += 2;
                continue;
            }

            break;
        }

        if (width <= 0 || height <= 0 || timestampMilliseconds < 0 || outputPath.length == 0) {
            print_usage();
            return 2;
        }
        if (argumentIndex + 1 != argc) {
            print_usage();
            return 2;
        }

        NSString *sourcePath = [NSString stringWithUTF8String:argv[argumentIndex]];
        NSError *error = nil;
        SFXASSRenderOutput *output = [SFXASSRenderer renderASSFileAtPath:sourcePath
                                                               frameWidth:width
                                                              frameHeight:height
                                                    timestampMilliseconds:timestampMilliseconds
                                                           fontsDirectory:fontsDirectory
                                                                    error:&error];
        if (output == nil) {
            fprintf(stderr, "ASSRenderingProbe failed: %s\n", error.localizedDescription.UTF8String);
            return 1;
        }

        if (![output writePNGToPath:outputPath error:&error]) {
            fprintf(stderr, "ASSRenderingProbe failed: %s\n", error.localizedDescription.UTF8String);
            return 1;
        }

        printf(
            "Rendered ASS frame: source=%s, output=%s, size=%ldx%ld, timestamp_ms=%ld, images=%ld, changed=%s, libass=%s\n",
            sourcePath.UTF8String,
            outputPath.UTF8String,
            (long)output.width,
            (long)output.height,
            (long)timestampMilliseconds,
            (long)output.imageCount,
            output.changed ? "yes" : "no",
            SFXASSRenderer.libassVersionString.UTF8String
        );
        return 0;
    }
}
