//
//  main.m
//  ConflictTool
//
//  Created by guanche on 05/01/2017.
//  Copyright © 2017 guanche. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct {
    NSUInteger location1;
    NSUInteger location2;
    NSUInteger length;
} CommonLinesResult;

@interface RemovedInfo : NSObject

@property (nonatomic, assign) NSRange removedRange;

@end

@implementation RemovedInfo

@end

@interface InsertedInfo : NSObject

@property (nonatomic, assign) NSUInteger location;
@property (nonatomic, copy) NSString *insertedString;

@end

@implementation InsertedInfo

@end

@interface ConflictManager : NSObject

+ (NSString *)currentDirectoryPath;
+ (NSString *)runGitCommand:(NSArray *)args;

@end

@interface Conflict : NSObject

- (instancetype)initWithLines:(NSArray *)lines mark1:(NSUInteger)mark1 mark2:(NSUInteger)mark2 mark3:(NSUInteger)mark3 mark4:(NSUInteger)mark4;
- (NSArray *)resolveConflict;
@property (nonatomic, readonly) NSArray *lines;
@property (nonatomic, readonly) NSUInteger mark1;
@property (nonatomic, readonly) NSUInteger mark2;
@property (nonatomic, readonly) NSUInteger mark3;
@property (nonatomic, readonly) NSUInteger mark4;

@end

@implementation Conflict

- (instancetype)initWithLines:(NSArray *)lines mark1:(NSUInteger)mark1 mark2:(NSUInteger)mark2 mark3:(NSUInteger)mark3 mark4:(NSUInteger)mark4 {
    if (self = [super init]) {
        _lines = lines;
        _mark1 = mark1;
        _mark2 = mark2;
        _mark3 = mark3;
        _mark4 = mark4;
    }
    return self;
}

- (NSArray *)resolveConflict {
    NSString *content1 = [self contentFromLines:self.lines begin:self.mark1 end:self.mark2];
    NSString *content2 = [self contentFromLines:self.lines begin:self.mark2 end:self.mark3];
    NSString *content3 = [self contentFromLines:self.lines begin:self.mark3 end:self.mark4];
    NSMutableArray *diff1 = [NSMutableArray array];
    [self getDiff:diff1 content1:content2 range1:NSMakeRange(0, content2.length) content2:content1 range2:NSMakeRange(0, content1.length)];
    NSMutableArray *diff2 = [NSMutableArray array];
    [self getDiff:diff2 content1:content2 range1:NSMakeRange(0, content2.length) content2:content3 range2:NSMakeRange(0, content3.length)];
    for (id info1 in diff1) {
        for (id info2 in diff2) {
            if ([self isConflictForDiff1:info1 diff2:info2]) {
                return nil;
            }
        }
    }
    NSMutableString *content = [NSMutableString stringWithString:content2];
    NSMutableArray *allDiffs = [NSMutableArray array];
    [allDiffs addObjectsFromArray:diff2];
    [allDiffs addObjectsFromArray:diff1];
    [allDiffs sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSUInteger location1;
        if ([obj1 isKindOfClass:[InsertedInfo class]]) {
            location1 = [(InsertedInfo *)obj1 location];
        } else {
            location1 = [(RemovedInfo *)obj1 removedRange].location;
        }
        NSUInteger location2;
        if ([obj2 isKindOfClass:[InsertedInfo class]]) {
            location2 = [(InsertedInfo *)obj2 location];
        } else {
            location2 = [(RemovedInfo *)obj2 removedRange].location;
        }
        if ([@(location1) compare:@(location2)] != NSOrderedSame) {
            return [@(location2) compare:@(location1)];
        } else if ([obj1 class] != [obj2 class]) {
            return [obj1 isKindOfClass:[InsertedInfo class]] ? NSOrderedDescending : NSOrderedAscending;
        } else {
            return NSOrderedSame;
        }
    }];
    for (id info in allDiffs) {
        if ([info isKindOfClass:[InsertedInfo class]]) {
            InsertedInfo *insertedInfo = (InsertedInfo *)info;
            [content insertString:insertedInfo.insertedString atIndex:insertedInfo.location];
        }
        if ([info isKindOfClass:[RemovedInfo class]]) {
            RemovedInfo *removedInfo = (RemovedInfo *)info;
            [content replaceCharactersInRange:NSMakeRange(removedInfo.removedRange.location, removedInfo.removedRange.length) withString:@""];
        }
    }
    NSMutableArray *lines = [[NSMutableArray alloc] initWithArray:[content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]];
    [lines removeLastObject];
    return lines.copy;
}

- (BOOL)isConflictForDiff1:(id)diff1 diff2:(id)diff2 {
    if ([diff1 isKindOfClass:[InsertedInfo class]] && [diff2 isKindOfClass:[InsertedInfo class]]) {
        return NO;
    } else if ([diff1 isKindOfClass:[InsertedInfo class]] && [diff2 isKindOfClass:[RemovedInfo class]]) {
        InsertedInfo *info1 = (InsertedInfo *)diff1;
        RemovedInfo *info2 = (RemovedInfo *)diff2;
        return info1.location > info2.removedRange.location && info1.location < info2.removedRange.location + info2.removedRange.length;
    } else if ([diff1 isKindOfClass:[RemovedInfo class]] && [diff2 isKindOfClass:[InsertedInfo class]]) {
        RemovedInfo *info1 = (RemovedInfo *)diff1;
        InsertedInfo *info2 = (InsertedInfo *)diff2;
        return info2.location > info1.removedRange.location && info2.location < info1.removedRange.location + info1.removedRange.length;
    } else {
        RemovedInfo *info1 = (RemovedInfo *)diff1;
        RemovedInfo *info2 = (RemovedInfo *)diff2;
        return info1.removedRange.location < info2.removedRange.location + info2.removedRange.length && info2.removedRange.location < info1.removedRange.location + info1.removedRange.length;
    }
}

- (void)getDiff:(NSMutableArray *)diff content1:(NSString *)content1 range1:(NSRange)range1 content2:(NSString *)content2 range2:(NSRange)range2 {
    NSString *subContent1 = [content1 substringWithRange:range1];
    NSString *subContent2 = [content2 substringWithRange:range2];
    CommonLinesResult result = [self maxCommonLinesWithContent1:subContent1 content2:subContent2];
    if (result.length == 0) {
        if (range1.length > 0) {
            RemovedInfo *info = [[RemovedInfo alloc] init];
            info.removedRange = range1;
            [diff addObject:info];
        }

        if (range2.length > 0) {
            InsertedInfo *info = [[InsertedInfo alloc] init];
            info.location = range1.location;
            info.insertedString = subContent2;
            [diff addObject:info];
        }
    } else {
        [self getDiff:diff content1:content1 range1:NSMakeRange(range1.location, result.location1) content2:content2 range2:NSMakeRange(range2.location, result.location2)];
        [self getDiff:diff content1:content1 range1:NSMakeRange(range1.location + result.location1 + result.length, range1.length - result.location1 - result.length) content2:content2 range2:NSMakeRange(range2.location + result.location2 + result.length, range2.length - result.location2 - result.length)];
    }
}

// 求最大公共子串算法
- (CommonLinesResult)maxCommonLinesWithContent1:(NSString *)content1 content2:(NSString *)content2 {
    CommonLinesResult commonLinesResult;
    commonLinesResult.location1 = 0;
    commonLinesResult.location2 = 0;
    commonLinesResult.length = 0;
    if (content1.length == 0 || content2.length == 0) {
        return commonLinesResult;
    }
    NSUInteger **result = malloc(sizeof(NSUInteger *) * content1.length);
    for (NSUInteger index = 0; index < content1.length; ++index) {
        result[index] = malloc(sizeof(NSUInteger) * content2.length);
    }

    for (NSUInteger i = 0; i < content1.length; ++i) {
        for (NSUInteger j = 0; j < content2.length; ++j) {
            unichar char1 = [content1 characterAtIndex:i];
            unichar char2 = [content2 characterAtIndex:j];
            if (char1 == char2) {
                if (i > 0 && j > 0) {
                    result[i][j] = result[i-1][j-1] + 1;
                } else {
                    result[i][j] = 1;
                }
            } else {
                result[i][j] = 0;
            }
            if (result[i][j] > commonLinesResult.length) {
                commonLinesResult.length = result[i][j];
                commonLinesResult.location1 = i - commonLinesResult.length + 1;
                commonLinesResult.location2 = j - commonLinesResult.length + 1;
            }
        }
    }

    for (NSUInteger index = 0; index < content1.length; ++index) {
        free(result[index]);
    }
    free(result);
    
    return commonLinesResult;
}

- (void)saveConflict {
    NSString *content1 = [self contentFromLines:self.lines begin:self.mark1 end:self.mark2];
    NSString *content2 = [self contentFromLines:self.lines begin:self.mark2 end:self.mark3];
    NSString *content3 = [self contentFromLines:self.lines begin:self.mark3 end:self.mark4];
    NSString *ID1 = [self objIDWithContent:content1];
    NSString *ID2 = [self objIDWithContent:content2];
    NSString *ID3 = [self objIDWithContent:content3];
    [ID1 writeToFile:[[ConflictManager currentDirectoryPath] stringByAppendingPathComponent:@"conflict_ID1.con"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [ID2 writeToFile:[[ConflictManager currentDirectoryPath] stringByAppendingPathComponent:@"conflict_ID2.con"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [ID3 writeToFile:[[ConflictManager currentDirectoryPath] stringByAppendingPathComponent:@"conflict_ID3.con"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (NSString *)contentFromLines:(NSArray *)lines begin:(NSUInteger)begin end:(NSUInteger)end {
    NSMutableString *content = [NSMutableString string];
    for (NSUInteger i = begin + 1; i < end; ++i) {
        NSString *line = lines[i];
        [content appendString:line];
        [content appendString:@"\n"];
    }
    return [content copy];
}

- (NSString *)objIDWithContent:(NSString *)content {
    NSString *tempPath = [[ConflictManager currentDirectoryPath] stringByAppendingPathComponent:@"conflict_temp.txt"];
    [content writeToFile:tempPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSString *ID = [ConflictManager runGitCommand:@[@"hash-object", @"-w", tempPath]];
    [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];
    return [ID stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

@end

@implementation ConflictManager

+ (NSString *)currentDirectoryPath {
    return [[NSFileManager defaultManager] currentDirectoryPath];
//    return @"/Users/guanche/workspace/lib_keyboard_ios";
}

+ (NSString *)runGitCommand:(NSArray *)args output:(BOOL)output {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/git"];
    [task setArguments:args];
    [task setCurrentDirectoryPath:[self currentDirectoryPath]];
    if (!output) {
        NSPipe *pipe = [NSPipe pipe];
        [task setStandardOutput:pipe];
        NSFileHandle *file = [pipe fileHandleForReading];
        [task launch];
        NSData *data = [file readDataToEndOfFile];
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    } else {
        [task launch];
        return nil;
    }
}

+ (NSString *)runGitCommand:(NSArray *)args {
    return [self runGitCommand:args output:NO];
}

+ (NSMutableArray *)linesFromFile:(NSString *)file {
    NSString *path = [[self currentDirectoryPath] stringByAppendingPathComponent:file];
    NSString *string = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    return [NSMutableArray arrayWithArray:[string componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]];
}

+ (void)saveLines:(NSArray *)lines toFile:(NSString *)file {
    NSMutableString *string = [NSMutableString string];
    for (NSString *line in lines) {
        [string appendString:line];
        [string appendString:@"\n"];
    }
    if (string.length > 0) {
        [string deleteCharactersInRange:NSMakeRange(string.length - 1, 1)];
    }
    NSString *path = [[self currentDirectoryPath] stringByAppendingPathComponent:file];
    [string writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

+ (NSArray *)conflictFiles {
    NSMutableDictionary *files = [NSMutableDictionary dictionary];
    NSString *string = [self runGitCommand:@[@"ls-files", @"-u"]];
    NSArray *lines = [string componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        if (line.length == 0) {
            continue;
        }
        NSArray *contents = [line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if ([contents[0] integerValue] == 100644) {
            NSString *name = contents[3];
            [files setObject:@([files[name] integerValue] + 1) forKey:name];
        }
    }

    NSMutableArray *result = [NSMutableArray array];
    for (NSString *name in files) {
        if ([files[name] integerValue] == 3) {
            [result addObject:name];
        }
    }
    [result sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2 options:0];
    }];
    return result.copy;
}

+ (Conflict *)findFirstConflictInLines:(NSArray *)lines {
    NSUInteger beginLine = 0;
    NSUInteger midLine = 0;
    NSUInteger endLine = 0;
    for (NSUInteger i = 0; i < lines.count; ++i) {
        NSString *line = lines[i];
        if ([line hasPrefix:@"<<<<<<<"]) {
            beginLine = i;
        } else if ([line hasPrefix:@"|||||||"]) {
            midLine = i;
        } else if ([line hasPrefix:@"======="]) {
            endLine = i;
        } else if ([line hasPrefix:@">>>>>>>"]) {
            if (midLine > beginLine && endLine > midLine && i > endLine) {
                return [[Conflict alloc] initWithLines:lines mark1:beginLine mark2:midLine mark3:endLine mark4:i];
            }
        }
    }
    return nil;
}

@end

void outputLines(NSArray *lines) {
    for (NSString *line in lines) {
        printf("%s\n", [line cStringUsingEncoding:NSUTF8StringEncoding]);
    }
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSArray *files = [ConflictManager conflictFiles];
        for (NSString *fileName in files) {
            printf("Finding conflict in file: %s\n", [fileName cStringUsingEncoding:NSUTF8StringEncoding]);
            NSMutableArray *lines = [ConflictManager linesFromFile:fileName];
            Conflict *conflict = [ConflictManager findFirstConflictInLines:lines];
            while (conflict) {
                NSArray *resultLines = [conflict resolveConflict];
                printf("冲突内容：\n");
                outputLines([lines subarrayWithRange:NSMakeRange(conflict.mark1, conflict.mark4 - conflict.mark1 + 1)]);
                if (resultLines) {
                    printf("自动解决冲突结果：\n");
                    if (resultLines.count > 0) {
                        outputLines(resultLines);
                    } else {
                        printf("<no content>\n");
                    }
                } else {
                    printf("无法自动解决冲突！\n");
                }
                printf("请选择操作(a:自动解决/h:使用HEAD版本/t:使用另一版本/m:手动解决):");
                while (YES) {
                    char ch = getchar();
                    if (resultLines && (ch == 'a' || ch == 'A')) {
                        [lines replaceObjectsInRange:NSMakeRange(conflict.mark1, conflict.mark4 - conflict.mark1 + 1) withObjectsFromArray:resultLines];
                        [ConflictManager saveLines:lines toFile:fileName];
                        conflict = [ConflictManager findFirstConflictInLines:lines];
                        break;
                    } else if (ch == 'h' || ch == 'H') {
                        [lines removeObjectsInRange:NSMakeRange(conflict.mark2, conflict.mark4 - conflict.mark2 + 1)];
                        [lines removeObjectsInRange:NSMakeRange(conflict.mark1, 1)];
                        [ConflictManager saveLines:lines toFile:fileName];
                        conflict = [ConflictManager findFirstConflictInLines:lines];
                        break;
                    } else if (ch == 't' || ch == 'T') {
                        [lines removeObjectsInRange:NSMakeRange(conflict.mark4, 1)];
                        [lines removeObjectsInRange:NSMakeRange(conflict.mark1, conflict.mark3 - conflict.mark1 + 1)];
                        [ConflictManager saveLines:lines toFile:fileName];
                        conflict = [ConflictManager findFirstConflictInLines:lines];
                        break;
                    } else if (ch == 'm' || ch == 'M') {
                        [conflict saveConflict];
                        return 0;
                    }
                }
            }
            printf("No conflict in file: %s\n", [fileName cStringUsingEncoding:NSUTF8StringEncoding]);
        }
    }
    return 0;
}
