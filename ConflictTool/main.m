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

@interface ModifiedInfo : NSObject
@property (nonatomic, assign) NSRange removedRange;
@property (nonatomic, copy) NSArray *insertedLines;
@end

@implementation ModifiedInfo
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
    NSArray *content1 = [self.lines subarrayWithRange:NSMakeRange(self.mark1 + 1, self.mark2 - self.mark1 - 1)];
    NSArray *content2 = [self.lines subarrayWithRange:NSMakeRange(self.mark2 + 1, self.mark3 - self.mark2 - 1)];
    NSArray *content3 = [self.lines subarrayWithRange:NSMakeRange(self.mark3 + 1, self.mark4 - self.mark3 - 1)];
    NSMutableArray *diff1 = [NSMutableArray array];
    [self getDiff:diff1 content1:content2 range1:NSMakeRange(0, content2.count) content2:content1 range2:NSMakeRange(0, content1.count)];
    NSMutableArray *diff2 = [NSMutableArray array];
    [self getDiff:diff2 content1:content2 range1:NSMakeRange(0, content2.count) content2:content3 range2:NSMakeRange(0, content3.count)];
    for (id info1 in diff1) {
        for (id info2 in diff2) {
            if ([self isConflictForDiff1:info1 diff2:info2]) {
                return nil;
            }
        }
    }
    NSMutableArray *content = [NSMutableArray arrayWithArray:content2];
    NSMutableArray *allDiffs = [NSMutableArray array];
    [allDiffs addObjectsFromArray:diff2];
    [allDiffs addObjectsFromArray:diff1];
    [allDiffs sortUsingComparator:^NSComparisonResult(ModifiedInfo *obj1, ModifiedInfo *obj2) {
        NSUInteger location1 = obj1.removedRange.location;
        NSUInteger location2 = obj2.removedRange.location;
        if ([@(location1) compare:@(location2)] != NSOrderedSame) {
            return [@(location2) compare:@(location1)];
        } else {
            return [@(obj2.removedRange.length) compare:@(obj1.removedRange.length)];
        }
    }];
    for (ModifiedInfo *info in allDiffs) {
        if (info.removedRange.length > 0) {
            [content removeObjectsInRange:info.removedRange];
        }
        if (info.insertedLines.count > 0) {
            [content insertObjects:info.insertedLines atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(info.removedRange.location, info.insertedLines.count)]];
        }
    }
    return content.copy;
}

- (BOOL)isConflictForDiff1:(ModifiedInfo *)diff1 diff2:(ModifiedInfo *)diff2 {
    return diff1.removedRange.location < diff2.removedRange.location + diff2.removedRange.length && diff2.removedRange.location < diff1.removedRange.location + diff1.removedRange.length;
}

- (void)getDiff:(NSMutableArray *)diff content1:(NSArray *)content1 range1:(NSRange)range1 content2:(NSArray *)content2 range2:(NSRange)range2 {
    if (range1.length == 0 && range2.length == 0) {
        return;
    }
    NSArray *subContent1 = [content1 subarrayWithRange:range1];
    NSArray *subContent2 = [content2 subarrayWithRange:range2];
    CommonLinesResult result = [self maxCommonLinesWithContent1:subContent1 content2:subContent2];
    if (result.length == 0) {
        ModifiedInfo *info = [[ModifiedInfo alloc] init];
        info.removedRange = range1;
        info.insertedLines = subContent2;
        [diff addObject:info];
    } else {
        [self getDiff:diff content1:content1 range1:NSMakeRange(range1.location, result.location1) content2:content2 range2:NSMakeRange(range2.location, result.location2)];
        [self getDiff:diff content1:content1 range1:NSMakeRange(range1.location + result.location1 + result.length, range1.length - result.location1 - result.length) content2:content2 range2:NSMakeRange(range2.location + result.location2 + result.length, range2.length - result.location2 - result.length)];
    }
}

// 求最大公共子串算法
- (CommonLinesResult)maxCommonLinesWithContent1:(NSArray *)content1 content2:(NSArray *)content2 {
    CommonLinesResult commonLinesResult;
    commonLinesResult.location1 = 0;
    commonLinesResult.location2 = 0;
    commonLinesResult.length = 0;
    if (content1.count == 0 || content2.count == 0) {
        return commonLinesResult;
    }
    NSUInteger **result = malloc(sizeof(NSUInteger *) * content1.count);
    for (NSUInteger index = 0; index < content1.count; ++index) {
        result[index] = malloc(sizeof(NSUInteger) * content2.count);
    }

    for (NSUInteger i = 0; i < content1.count; ++i) {
        for (NSUInteger j = 0; j < content2.count; ++j) {
            NSString *line1 = [content1 objectAtIndex:i];
            NSString *line2 = [content2 objectAtIndex:j];
            if ([line1 isEqualToString:line2]) {
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

    for (NSUInteger index = 0; index < content1.count; ++index) {
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

+ (void)saveLines:(NSArray *)lines toFile:(NSString *)file addNewLineAtEndOfFile:(BOOL)add {
    NSMutableString *string = [NSMutableString string];
    for (NSString *line in lines) {
        [string appendString:line];
        [string appendString:@"\n"];
    }
    if (!add && string.length > 0) {
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
        NSString *fileFormat = [line substringWithRange:NSMakeRange(0, 6)];
        __used NSString *fileSha = [line substringWithRange:NSMakeRange(7, 40)];
        __used NSString *fileZone = [line substringWithRange:NSMakeRange(48, 1)];
        NSString *fileName = [line substringFromIndex:50];
        if ([fileFormat integerValue] == 100644 || [fileFormat integerValue] == 100755) {
            [files setObject:@([files[fileName] integerValue] + 1) forKey:fileName];
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
            printf("正在以下文件 \"%s\" 中查找冲突……\n", [fileName cStringUsingEncoding:NSUTF8StringEncoding]);
            NSMutableArray *lines = [ConflictManager linesFromFile:fileName];
            Conflict *conflict = [ConflictManager findFirstConflictInLines:lines];
            NSString *conflictContentPath = [[ConflictManager currentDirectoryPath] stringByAppendingPathComponent:@"conflict_content.con"];
            if ([[NSFileManager defaultManager] fileExistsAtPath:conflictContentPath]) {
                NSMutableArray *resultLines = [[ConflictManager linesFromFile:@"conflict_content.con"] mutableCopy];
                [resultLines removeLastObject];
                [lines replaceObjectsInRange:NSMakeRange(conflict.mark1, conflict.mark4 - conflict.mark1 + 1) withObjectsFromArray:resultLines];
                [ConflictManager saveLines:lines toFile:fileName addNewLineAtEndOfFile:NO];
                conflict = [ConflictManager findFirstConflictInLines:lines];
                [[NSFileManager defaultManager] removeItemAtPath:conflictContentPath error:nil];
            }
            while (conflict) {
                printf("冲突内容：\n");
                outputLines([lines subarrayWithRange:NSMakeRange(conflict.mark1, conflict.mark4 - conflict.mark1 + 1)]);
                NSArray *resultLines = [conflict resolveConflict];
                if (resultLines) {
                    printf("自动解决冲突结果：\n");
                    if (resultLines.count > 0) {
                        outputLines(resultLines);
                    } else {
                        printf("<no content>\n");
                    }
                    printf("请选择操作(a:自动解决|h:使用HEAD版本|t:使用另一版本|v:在vim中编辑|m:显示两边diff手动解决):");
                } else {
                    printf("无法自动解决冲突！\n");
                    printf("请选择操作(h:使用HEAD版本|t:使用另一版本|v:在vim中编辑|m:显示两边diff手动解决):");
                }

                while (YES) {
                    char ch = getchar();
                    if (resultLines && (ch == 'a' || ch == 'A')) {
                        [lines replaceObjectsInRange:NSMakeRange(conflict.mark1, conflict.mark4 - conflict.mark1 + 1) withObjectsFromArray:resultLines];
                        [ConflictManager saveLines:lines toFile:fileName addNewLineAtEndOfFile:NO];
                        conflict = [ConflictManager findFirstConflictInLines:lines];
                        break;
                    } else if (ch == 'h' || ch == 'H') {
                        [lines removeObjectsInRange:NSMakeRange(conflict.mark2, conflict.mark4 - conflict.mark2 + 1)];
                        [lines removeObjectsInRange:NSMakeRange(conflict.mark1, 1)];
                        [ConflictManager saveLines:lines toFile:fileName addNewLineAtEndOfFile:NO];
                        conflict = [ConflictManager findFirstConflictInLines:lines];
                        break;
                    } else if (ch == 't' || ch == 'T') {
                        [lines removeObjectsInRange:NSMakeRange(conflict.mark4, 1)];
                        [lines removeObjectsInRange:NSMakeRange(conflict.mark1, conflict.mark3 - conflict.mark1 + 1)];
                        [ConflictManager saveLines:lines toFile:fileName addNewLineAtEndOfFile:NO];
                        conflict = [ConflictManager findFirstConflictInLines:lines];
                        break;
                    } else if (ch == 'm' || ch == 'M') {
                        [conflict saveConflict];
                        [fileName writeToFile:[[ConflictManager currentDirectoryPath] stringByAppendingPathComponent:@"conflict_file.con"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
                        return 0;
                    } else if (ch == 'v' || ch == 'V') {
                        [ConflictManager saveLines:[lines subarrayWithRange:NSMakeRange(conflict.mark1, conflict.mark4 - conflict.mark1 + 1)] toFile:@"conflict_content.con" addNewLineAtEndOfFile:YES];
                        return 0;
                    }
                }
            }
            printf("文件 \"%s\" 已无冲突，是否暂存文件(y/n)？", [fileName cStringUsingEncoding:NSUTF8StringEncoding]);
            while (YES) {
                char ch = getchar();
                if (ch == 'y' || ch == 'Y') {
                    [ConflictManager runGitCommand:@[@"add", fileName]];
                    break;
                } else if (ch == 'n' || ch == 'N') {
                    break;
                }
            }
        }
    }
    return 0;
}
