//
//  FileTransferFormat.m
//  socket-client
//
//  Created by hzzhangshuangli on 2017/9/27.
//  Copyright © 2017年 hzzhangshuangli. All rights reserved.
//

#import "FileTransferFormat.h"

@implementation FileTransferFormat
//REQUEST_REGISTRATION_ = 0x00,
//REQUEST_REGISTRATION_ALLOWED = 0x01,
//REQUEST_REGISTRATION_DENY = 0x02,
//FILE_ONE_END_HERE = 0x10,
//FILE_ALL_END_HERE = 0x20,
//PROCESS_REGISTRATION_FINISHED = 0xA0
//RECEIVED_MARKER
- (NSString*) convertMsgToString:(StateMessages) messageID
{
    switch (messageID) {
        case REQUEST_REGISTRATION:
            return @"RequestRegistration";
            break;
        case REQUEST_REGISTRATION_ALLOWED:
            return @"RequestRegistrationAllowed";
            break;
        case REQUEST_REGISTRATION_DENY:
            return @"RequestRegistrationDeny";
            break;
        case FILE_ONE_END_HERE:
            return @"FileOneEndHere";
            break;
        case FILE_ALL_END_HERE:
            return @"FileAllEndHere";
            break;
        case PROCESS_REGISTRATION_FINISHED:
            return @"ProcessRegistrationFinished";
            break;
        case RECEIVED_MARKER:
            return @"ReceivedMarker";
            break;
        default:
            break;
    }
}

- (StateMessages) convertMsgToInt:(NSString *)messageText
{
    if ([messageText isEqualToString:@"RequestRegistration"]) {
        return REQUEST_REGISTRATION;
    }
    if ([messageText isEqualToString:@"RequestRegistrationAllowed"]) {
        return REQUEST_REGISTRATION_ALLOWED;
    }
    if ([messageText isEqualToString:@"RequestRegistrationDeny"]) {
        return REQUEST_REGISTRATION_DENY;
    }
    if ([messageText isEqualToString:@"FileOneEndHere"]) {
        return FILE_ONE_END_HERE;
    }
    if ([messageText isEqualToString:@"FileAllEndHere"]) {
        return FILE_ALL_END_HERE;
    }
    if ([messageText isEqualToString:@"ProcessRegistrationFinished"]) {
        return PROCESS_REGISTRATION_FINISHED;
    }
    if ([messageText isEqualToString:@"ReceivedMarker"]) {
        return RECEIVED_MARKER;
    }
    return -1;
}

- (bool)sendRegistrationRequest:(NSInteger *)state withSender:(GCDAsyncSocket *)sender withFiles:(NSArray *) files
{
    // send request
    NSString *msgRequest = [self convertMsgToString:REQUEST_REGISTRATION];
    self.timerWaiting = 10.0;
    bool result = [self sendRequest:state withSender:sender withData:[msgRequest dataUsingEncoding:NSUTF8StringEncoding] withGoal:REQUEST_REGISTRATION_ALLOWED];
    if (!result) {
        NSLog(@"REQUEST_REGISTRATION_DENY error");
        return false;
    }
    self.timerWaiting = 2.0;
    // send frame number
    NSString *msgFileNumber = [NSString stringWithFormat: @"%i", [files count]];
    result = [self sendRequest:state withSender:sender withData:[msgFileNumber dataUsingEncoding:NSUTF8StringEncoding] withGoal:RECEIVED_MARKER];
    
    if (!result) {
        NSLog(@"Fail to send message file number");
        return false;
    }
    
    // send files
    for (NSString *file in files) {
        result = [self sendRequest:state withSender:sender withData:[file dataUsingEncoding:NSUTF8StringEncoding] withGoal:RECEIVED_MARKER];
        if (!result) {
            NSLog(@"Fail to send message %@", file);
            return false;
        }
        NSString *theFileName = [file lastPathComponent];
        [self sendFile:state withSender:sender withFiles:theFileName];
    }
    
    // send EOF of all
    NSString *msgEOF = [self convertMsgToString:FILE_ALL_END_HERE];
    result = [self sendRequest:state withSender:sender withData:[msgEOF dataUsingEncoding:NSUTF8StringEncoding] withGoal:REQUEST_REGISTRATION_ALLOWED];
    if (!result) {
        NSLog(@"FILE_ALL_END_HERE error");
        return false;
    }
    
    return true;
}

-(bool)sendFile:(NSInteger *)state withSender:(GCDAsyncSocket *)sender withFiles:(NSString *)filename
{
    NSString *content = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:NULL];
    NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
    
    int index = 0;
    int totalLen = [content length];
    //   NSData *piece = buffer;
    uint8_t *readBytes = (uint8_t *)[data bytes];
    
    while (index < totalLen) {
        //if ([outputStream hasSpaceAvailable]) {
        int indexLen =  256;
        NSRange first4k = {index, MIN([data length]-index, indexLen)};
        NSData *piece =[data subdataWithRange:first4k];
        index += indexLen;
        bool result = [self sendRequest:state withSender:sender withData:piece withGoal:RECEIVED_MARKER];
        if (!result) {
            NSLog(@"Fail to send piece of file %@", filename);
            return false;
        }
    }
    NSString *msgEnd = [self convertMsgToString:FILE_ONE_END_HERE];
    bool result = [self sendRequest:state withSender:sender withData:[msgEnd dataUsingEncoding:NSUTF8StringEncoding] withGoal:RECEIVED_MARKER];
    if (!result) {
        NSLog(@"Fail to send EOF of file %@", filename);
        return false;
    }
    return true;
}

- (void)myTimer
{
    double delayInSeconds = self.timerWaiting;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        self.timeOut = true;
    });
}

- (bool)sendRequest:(NSInteger *)state withSender:(GCDAsyncSocket *)sender withData:(NSData *)data withGoal:(StateMessages) idealBack
{
    *state = -1;
    self.timeOut = false;
    [sender writeData:data withTimeout:-1 tag:0];
    NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(myTimer) object:nil];
    [thread start];
    
    while (!self.timeOut && *state != idealBack) {
        continue;
    }
    if (self.timeOut) {
        NSLog(@"warning: Failed, timeOut during data sending, state = %i", *state);
        return false;
    }
    return true;
}

- (bool)receiveAndSaveFiles:(bool *)reader withSender:(GCDAsyncSocket *)sender withFolder:(NSString *)folder withData:(NSData *)data;
{
    NSString *msgRequestAllow = [self convertMsgToString:REQUEST_REGISTRATION_ALLOWED];
    NSString *msgReceive = [self convertMsgToString:RECEIVED_MARKER];
    [sender writeData:[msgRequestAllow dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
    *reader = false;
    NSInteger fileNumber;
    if (!*reader) {
        NSString *fileNum = [[NSString alloc]initWithData:data encoding:NSISOLatin1StringEncoding];
        fileNumber = [fileNum integerValue];
    }
    *reader = false;
    [sender writeData:[msgReceive dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
    
    for (int i = 0; i<fileNumber; i++) {
        NSString *filename;
        if (!*reader) {
            filename = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
        }
        *reader = false;
        [sender writeData:[msgReceive dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
        
        NSString *filePath = [folder stringByAppendingPathComponent:filename];
        [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
        NSFileHandle *handle = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
        
        if (!*reader) {
            [data writeToFile:filePath atomically:YES];
        }
        *reader = false;
        
        while ([self convertMsgToInt:[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]] != FILE_ONE_END_HERE) {
            if (!*reader) {
                *reader = true;
                [sender writeData:[msgReceive dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
                [handle seekToEndOfFile];
                [handle writeData:data];
                [handle closeFile];
            }
        }
        
        if ([self convertMsgToInt:[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]] != FILE_ALL_END_HERE) {
            break;
        }
    }
    [sender writeData:[msgRequestAllow dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
    return true;
}

@end
