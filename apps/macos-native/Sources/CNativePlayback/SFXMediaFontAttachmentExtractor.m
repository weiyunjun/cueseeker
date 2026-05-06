#import "SFXNativePlaybackPlayer.h"

#include <libavcodec/codec_id.h>
#include <libavcodec/codec_par.h>
#include <libavformat/avformat.h>
#include <libavutil/dict.h>
#include <libavutil/error.h>
#include <dispatch/dispatch.h>

static NSString *SFXAttachmentFFmpegErrorString(int code) {
    char buffer[AV_ERROR_MAX_STRING_SIZE] = {0};
    if (av_strerror(code, buffer, sizeof(buffer)) < 0) {
        return [NSString stringWithFormat:@"FFmpeg error %d", code];
    }
    return [NSString stringWithUTF8String:buffer];
}

static NSError *SFXMediaFontAttachmentError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:SFXNativePlaybackErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

static NSSet<NSString *> *SFXSupportedFontExtensions(void) {
    static NSSet<NSString *> *extensions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        extensions = [NSSet setWithObjects:@"ttf", @"otf", @"ttc", @"otc", @"woff", @"woff2", nil];
    });
    return extensions;
}

static NSString *SFXStringFromAVDictionary(AVDictionary *metadata, const char *key) {
    AVDictionaryEntry *entry = av_dict_get(metadata, key, NULL, 0);
    if (entry == NULL || entry->value == NULL) {
        return nil;
    }
    return [NSString stringWithUTF8String:entry->value];
}

static BOOL SFXMimeTypeLooksLikeFont(NSString *mimeType) {
    NSString *lowercase = mimeType.lowercaseString;
    return [lowercase containsString:@"font"]
        || [lowercase containsString:@"truetype"]
        || [lowercase containsString:@"opentype"]
        || [lowercase containsString:@"woff"]
        || [lowercase containsString:@"sfnt"];
}

static BOOL SFXAttachmentLooksLikeFont(AVCodecParameters *parameters, NSString *filename, NSString *mimeType) {
    if (parameters == NULL || parameters->codec_type != AVMEDIA_TYPE_ATTACHMENT) {
        return NO;
    }

    if (parameters->codec_id == AV_CODEC_ID_TTF || parameters->codec_id == AV_CODEC_ID_OTF) {
        return YES;
    }

    NSString *extension = filename.pathExtension.lowercaseString;
    if (extension.length > 0 && [SFXSupportedFontExtensions() containsObject:extension]) {
        return YES;
    }

    return mimeType.length > 0 && SFXMimeTypeLooksLikeFont(mimeType);
}

static NSString *SFXDefaultExtensionForAttachment(AVCodecParameters *parameters, NSString *mimeType) {
    if (parameters != NULL) {
        if (parameters->codec_id == AV_CODEC_ID_OTF) {
            return @"otf";
        }
        if (parameters->codec_id == AV_CODEC_ID_TTF) {
            return @"ttf";
        }
    }

    NSString *lowercase = mimeType.lowercaseString;
    if ([lowercase containsString:@"opentype"] || [lowercase containsString:@"otf"]) {
        return @"otf";
    }
    if ([lowercase containsString:@"woff2"]) {
        return @"woff2";
    }
    if ([lowercase containsString:@"woff"]) {
        return @"woff";
    }
    return @"ttf";
}

static NSString *SFXSanitizedAttachmentFilename(NSString *filename, NSUInteger index, AVCodecParameters *parameters, NSString *mimeType) {
    NSString *candidate = filename.lastPathComponent;
    if (candidate.length == 0) {
        candidate = [NSString stringWithFormat:@"attachment-%lu.%@", (unsigned long)index, SFXDefaultExtensionForAttachment(parameters, mimeType)];
    }

    NSMutableString *sanitized = [NSMutableString stringWithCapacity:candidate.length];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-()[] "];
    for (NSUInteger offset = 0; offset < candidate.length; offset += 1) {
        unichar character = [candidate characterAtIndex:offset];
        if ([allowed characterIsMember:character]) {
            [sanitized appendFormat:@"%C", character];
        } else {
            [sanitized appendString:@"_"];
        }
    }

    NSString *extension = sanitized.pathExtension.lowercaseString;
    if (extension.length == 0 || ![SFXSupportedFontExtensions() containsObject:extension]) {
        NSString *baseName = sanitized.stringByDeletingPathExtension;
        if (baseName.length == 0) {
            baseName = [NSString stringWithFormat:@"attachment-%lu", (unsigned long)index];
        }
        sanitized = [[baseName stringByAppendingPathExtension:SFXDefaultExtensionForAttachment(parameters, mimeType)] mutableCopy];
    }

    return sanitized;
}

static NSString *SFXUniqueAttachmentPath(NSString *directory, NSString *filename) {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *candidate = [directory stringByAppendingPathComponent:filename];
    if (![fileManager fileExistsAtPath:candidate]) {
        return candidate;
    }

    NSString *baseName = filename.stringByDeletingPathExtension;
    NSString *extension = filename.pathExtension;
    for (NSUInteger index = 2; index < NSUIntegerMax; index += 1) {
        NSString *numberedName = extension.length > 0
            ? [[NSString stringWithFormat:@"%@-%lu", baseName, (unsigned long)index] stringByAppendingPathExtension:extension]
            : [NSString stringWithFormat:@"%@-%lu", baseName, (unsigned long)index];
        candidate = [directory stringByAppendingPathComponent:numberedName];
        if (![fileManager fileExistsAtPath:candidate]) {
            return candidate;
        }
    }

    return [directory stringByAppendingPathComponent:[[NSUUID UUID].UUIDString stringByAppendingPathExtension:extension.length > 0 ? extension : @"ttf"]];
}

@implementation SFXMediaFontAttachmentExtractor

+ (nullable NSNumber *)extractFontAttachmentsFromMediaAtPath:(NSString *)mediaPath
                                                 toDirectory:(NSString *)directory
                                                       error:(NSError **)error {
    if (mediaPath.length == 0 || directory.length == 0) {
        if (error != NULL) {
            *error = SFXMediaFontAttachmentError(100, @"Media path and font attachment directory are required.");
        }
        return nil;
    }

    BOOL isDirectory = NO;
    NSFileManager *fileManager = NSFileManager.defaultManager;
    if (![fileManager fileExistsAtPath:directory isDirectory:&isDirectory] || !isDirectory) {
        if (error != NULL) {
            *error = SFXMediaFontAttachmentError(101, [NSString stringWithFormat:@"Font attachment directory does not exist: %@", directory]);
        }
        return nil;
    }

    AVFormatContext *formatContext = NULL;
    int result = avformat_open_input(&formatContext, mediaPath.fileSystemRepresentation, NULL, NULL);
    if (result < 0) {
        if (error != NULL) {
            *error = SFXMediaFontAttachmentError(102, [NSString stringWithFormat:@"Could not open media for font attachment extraction: %@", SFXAttachmentFFmpegErrorString(result)]);
        }
        return nil;
    }

    result = avformat_find_stream_info(formatContext, NULL);
    if (result < 0) {
        if (error != NULL) {
            *error = SFXMediaFontAttachmentError(103, [NSString stringWithFormat:@"Could not inspect media font attachments: %@", SFXAttachmentFFmpegErrorString(result)]);
        }
        avformat_close_input(&formatContext);
        return nil;
    }

    NSInteger extractedCount = 0;
    for (unsigned int index = 0; index < formatContext->nb_streams; index += 1) {
        AVStream *stream = formatContext->streams[index];
        if (stream == NULL || stream->codecpar == NULL) {
            continue;
        }

        AVCodecParameters *parameters = stream->codecpar;
        NSString *filename = SFXStringFromAVDictionary(stream->metadata, "filename");
        NSString *mimeType = SFXStringFromAVDictionary(stream->metadata, "mimetype");
        if (!SFXAttachmentLooksLikeFont(parameters, filename, mimeType)) {
            continue;
        }

        if (parameters->extradata == NULL || parameters->extradata_size <= 0) {
            continue;
        }

        NSString *safeFilename = SFXSanitizedAttachmentFilename(filename, index, parameters, mimeType);
        NSString *destinationPath = SFXUniqueAttachmentPath(directory, safeFilename);
        NSData *fontData = [NSData dataWithBytes:parameters->extradata length:(NSUInteger)parameters->extradata_size];
        if (![fontData writeToFile:destinationPath options:NSDataWritingAtomic error:error]) {
            avformat_close_input(&formatContext);
            return nil;
        }
        extractedCount += 1;
    }

    avformat_close_input(&formatContext);
    return @(extractedCount);
}

@end
