//
//  AppDelegate.m
//  JsonModelAutoMake
//
//  Created by yangjihang on 14/12/9.
//  Copyright (c) 2014年 yangjihang. All rights reserved.
//

#import "AppDelegate.h"
#import "JsonModelTreeNode.h"

//  resultDic中头文件名称的Key值
NSString * const HeaderFileNameKey = @"autoGenerateHeaderFileNameKey";
//  resultDic中源文件名称的Key值
NSString * const ResourceFileNameKey = @"autoGenerateResourceFileNameKey";

@interface AppDelegate () 

@property (weak) IBOutlet NSWindow *window;

//  查找，存储桌面上所有.json文件的路径
@property(nonatomic, strong) NSMutableArray *allJsonFilePathArray;

//  当前json文件树形结构的根节点
@property(nonatomic, strong) JsonModelTreeNode *currentFileRootNode;
//  当前文件下的所有需要定义的protocol
@property(nonatomic, strong) NSMutableSet *allProtocolSet;
//  当前文件下所有的jsonModel的类名
@property(nonatomic, strong) NSMutableSet *allJsonModelClassSet;

//  创建文件时间，copyRight，#import基本文件等等的模版String
@property(nonatomic, strong) NSString *illustrationPrefixString;

@end

@implementation AppDelegate

#pragma mark - Lazy Allocation
- (NSMutableArray *)allJsonFilePathArray {
    if (nil == _allJsonFilePathArray) {
        _allJsonFilePathArray = [NSMutableArray array];
    }
    return _allJsonFilePathArray;
}

- (NSString *)illustrationPrefixString {
    if (nil == _illustrationPrefixString) {
        _illustrationPrefixString = @"//\n//  %@\n//  Yuedu\n//\n//  Created by JsonModelAutoMakeTool on %@.\n//  Copyright (c) 2014年 YangJihang. All rights reserved.\n//\n\n#import \"JSONModel.h\"\n";
    }
    return _illustrationPrefixString;
}

- (NSMutableSet *)allProtocolSet {
    if (nil == _allProtocolSet) {
        _allProtocolSet = [NSMutableSet set];
    }
    return _allProtocolSet;
}

- (NSMutableSet *)allJsonModelClassSet {
    if (nil == _allJsonModelClassSet) {
        _allJsonModelClassSet = [NSMutableSet set];
    }
    return _allJsonModelClassSet;
}

#pragma mark - System Call Back
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

#pragma mark - Respond To Button Click
- (IBAction)generateByURLClicked:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSString *urlString = self.urlTextField.stringValue;
        NSURL *url = [NSURL URLWithString:urlString];
        if (url.absoluteString.length <= 0) {
            return;
        }
        
        NSString *jsonName = self.customJsonModelNameTextField.stringValue;
        if (jsonName.length <= 0) {
            jsonName = @"WKNewJsonModel";
        }
        
        NSData *jsonData = [NSData dataWithContentsOfURL:url];
        if (!jsonData) {
            NSLog(@"return empty JSON data!");
            return;
        }
        
        NSError *error;
        id jsonObj = [NSJSONSerialization JSONObjectWithData:jsonData
                                                     options:0
                                                       error:&error];
        if (![jsonObj isKindOfClass:[NSDictionary class]]) {
            //  检测是否为dictionary类型
            return;
        }
        NSDictionary *dic = jsonObj;
        if (0 == dic.count) {
            //  检测是否为空的dictionary
            return;
        }
        
        NSURL *finalURL = url;
        if (self.customJsonModelNameTextField.stringValue.length > 0) {
            finalURL = [NSURL URLWithString:[[self getDesktopFilePath] stringByAppendingPathComponent:self.customJsonModelNameTextField.stringValue]];
            if (finalURL.absoluteString.length <= 0) {
                finalURL = url;
            }
        }
        
        [self generateHeaderAndResourceFileWithJsonFileURL:finalURL
                                               withJsonObj:jsonObj];
    });
}

- (IBAction)generateByJsonFilesClicked:(id)sender {
    [self generateJsonModelAccordingToJsonFileFromDesktop];
}

#pragma mark - Function Method
/**
 *  遍历桌面所有*.json文件，根据这些文件声称对应的JsonModel
 */
- (void)generateJsonModelAccordingToJsonFileFromDesktop {
    //  过滤json文件的路径
    [self readAndRecordAllJsonFilePath];
    
    //  遍历json文件，生成对应的.h和.m文件
    for (NSURL *url in self.allJsonFilePathArray) {
        _currentFileRootNode = nil;
        _allJsonFilePathArray = nil;
        _allJsonModelClassSet = nil;
        
        [self generateHeaderAndResourceFileWithJsonFileURL:url];
    }
}


/**
 *  读取桌面的所有json后缀名文件并保存到allJsonFilePathArray中
 */
- (void)readAndRecordAllJsonFilePath {
    NSArray *destopPathArray = [[NSFileManager defaultManager] URLsForDirectory:NSDesktopDirectory
                                                                      inDomains:NSAllDomainsMask];
    NSURL *fileURL = destopPathArray.firstObject;
    
    NSError *error;
    NSArray *pathArray = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:fileURL
                                                       includingPropertiesForKeys:nil
                                                                          options:NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                                                            error:&error];
    for (NSURL *url in pathArray) {
        if (![url isKindOfClass:[NSURL class]]) {
            continue;
        }
        if ([url.pathExtension isEqualToString:@"json"]) {
            [self.allJsonFilePathArray addObject:url];
        }
    }
}


/**
 *  根据NSURL生成.h和.m文件
 *
 *  @param  url     桌面*.json文件的路径
 */
- (void)generateHeaderAndResourceFileWithJsonFileURL:(NSURL *)url {
    NSError *error;
    NSData *jsonData = [NSData dataWithContentsOfURL:url];
    id jsonObj = [NSJSONSerialization JSONObjectWithData:jsonData
                                                 options:0
                                                   error:&error];
    if (![jsonObj isKindOfClass:[NSDictionary class]]) {
        //  检测是否为dictionary类型
        return;
    }
    NSDictionary *dic = jsonObj;
    if (0 == dic.count) {
        //  检测是否为空的dictionary
        return;
    }

    [self generateHeaderAndResourceFileWithJsonFileURL:url
                                           withJsonObj:jsonObj];
}

/**
 *  根据NSURL生成.h和.m文件
 *
 *  @param  url     桌面*.json文件的路径
 *  @param  jsonObj NSDictionary对象
 */
- (void)generateHeaderAndResourceFileWithJsonFileURL:(NSURL *)url
                                         withJsonObj:(id)jsonObj {
    NSDictionary *dic = jsonObj;
    
    //  创建空的.h和.m文件
    NSMutableDictionary *resultMutableDic = [NSMutableDictionary dictionary];
    if (![self createEmptyHeaderAndResourceFileWithURL:url
                                        withDictionary:resultMutableDic]) {
        //  创建空文件失败，那么返回
        return;
    }
    
    NSString *headerFileFullPath = [[self getDesktopFilePath] stringByAppendingPathComponent:[resultMutableDic objectForKey:HeaderFileNameKey]];
    NSString *sourceFileFullPath = [[self getDesktopFilePath] stringByAppendingPathComponent:[resultMutableDic objectForKey:ResourceFileNameKey]];


    /*
     *  递归解析该对象，生成jsonInfoTree
     */
    [self setUpJsonInfoTreeRecursivelyWithKey:[self getFileNameWithoutPathExtensionWithFilePath:headerFileFullPath]
                                  withJsonObj:dic
                               withFatherNode:nil];
    
    //  去除根节点的JsonModel类，其他类用于提前声明
    [self.allJsonModelClassSet removeObject:self.currentFileRootNode.objTypeName];
    
    /*
     *  根据jsonInfoTree，向头文件中追加类的信息
     */
    //  需要的class声明写在前面
    NSArray *array = [self.allJsonModelClassSet allObjects];
    NSString *classString = @"";
    NSString *classDeclareTemplate = @"\n@class %@;\n";
    if (1 == array.count) {
        classString = [NSString stringWithFormat:classDeclareTemplate, array.firstObject];
    } else {
        classString = [NSString stringWithFormat:classDeclareTemplate, [array componentsJoinedByString:@", "]];
    }
    
    //  需要的protocol写在前面
    NSString *protocolTemplate = @"\n@protocol %@ <NSObject>\n@end\n";

    
    //  打开文件指针，准备开始写.h文件
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:headerFileFullPath];
    [fileHandle truncateFileAtOffset:[fileHandle seekToEndOfFile]];
    
    //  开始写class声明
    NSData *data = [classString dataUsingEncoding:NSUTF8StringEncoding];
    [fileHandle writeData:data];
    
    //  开始写所有的protocol定义
    for (NSString *protocolName in self.allProtocolSet) {
        NSString *dataString = [NSString stringWithFormat:protocolTemplate, protocolName];
        NSData *data = [dataString dataUsingEncoding:NSUTF8StringEncoding];
        [fileHandle writeData:data];
    }
    
    //  开始写入所有类的声明
    [self writeClassesRecursivelyWithFileHandle:fileHandle
                                       withNode:self.currentFileRootNode];
    
    //  关闭.h文件的指针
    [fileHandle closeFile];
    
    
    
    /*
     *  根据jsonInfoTree，向源文件中追加类的信息
     */
    NSFileHandle *sourceFileHandle = [NSFileHandle fileHandleForWritingAtPath:sourceFileFullPath];
    [sourceFileHandle truncateFileAtOffset:[sourceFileHandle seekToEndOfFile]];
    
    //  开始写入所有类的实现
    [self writeClassesImplementationRecursivelyWithFileHandle:sourceFileHandle
                                                     withNode:self.currentFileRootNode];

    //  关闭.m文件的指针
    [sourceFileHandle closeFile];
}


/**
 *  创建空的.h和.m文件
 *
 *  @param  url         桌面*.json文件的路径
 *  @param  resultDic   key:HeaderFileNameKey,ResourceFileNameKey   
                        value:头文件的文件名，源文件的文件名
 */
- (BOOL)createEmptyHeaderAndResourceFileWithURL:(NSURL *)url
                                 withDictionary:(NSMutableDictionary *)resultDic {
    /*
     *  首先创建头文件
     */
    NSString *prefixFileName = [self getFileNameWithoutPathExtensionWithFileURL:url];
    NSString *suffixFileName = @"JsonModel.h";
    
    NSString *headerFileName = nil;
    NSString *tempName = [NSString stringWithFormat:@"%@%@", prefixFileName, suffixFileName];
    NSString *contentDataString = [NSString stringWithFormat:self.illustrationPrefixString, tempName, [self getFormatedDateString]];
    NSData *cententData = [contentDataString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *fullPath = [[self getDesktopFilePath] stringByAppendingPathComponent:tempName];
    
    BOOL isSuccessed = [[NSFileManager defaultManager] createFileAtPath:fullPath
                                                               contents:cententData
                                                             attributes:nil];
    if (isSuccessed) {
        NSLog(@"%@ created success!", fullPath);
        headerFileName = tempName;
    } else {
        NSLog(@"%@ created fail!", fullPath);
    }
    
    if (0 == headerFileName.length) {
        //  .h文件创建失败
        return NO;
    }
    
    /*
     *  头文件创建成功后，根据头文件来创建源文件
     */
    NSString *sourceFileName = [[headerFileName stringByDeletingPathExtension] stringByAppendingPathExtension:@"m"];
    contentDataString = [NSString stringWithFormat:self.illustrationPrefixString, sourceFileName, [self getFormatedDateString]];
    NSString *headerFileString = [NSString stringWithFormat:@"%@#import \"%@\"\n", contentDataString, headerFileName];
    cententData = [headerFileString dataUsingEncoding:NSUTF8StringEncoding];
    fullPath = [[self getDesktopFilePath] stringByAppendingPathComponent:sourceFileName];
    isSuccessed = [[NSFileManager defaultManager] createFileAtPath:fullPath
                                                               contents:cententData
                                                             attributes:nil];
    if (isSuccessed) {
        NSLog(@"%@ created success!", fullPath);

        [resultDic setObject:headerFileName forKey:HeaderFileNameKey];
        [resultDic setObject:sourceFileName forKey:ResourceFileNameKey];
        
    } else {
        NSLog(@"%@ created fail!", fullPath);
    }
    return isSuccessed;
}


/**
 *  递归创建整个jsonInfoTree，传入为NSDictionary
 *
 *  @param  key     pair中的key
 *  @param  dic     pair中的value
 *  举例：     "yooo"  :   {
                            "yeah"  :   "1",
                            "fuck"  :   "2"
                           }
        此时，key为"yooo"，dic为{"yeah":"1","fuck":"2"}
 *  @param  fatherNode  jsonInfoTree中的父节点
 */
- (void)setUpJsonInfoTreeRecursivelyWithKey:(NSString *)key
                                    withDic:(NSDictionary *)dic
                             withFatherNode:(JsonModelTreeNode *)fatherNode {
    if (nil == fatherNode) {
        //  创建根节点
        fatherNode = [[JsonModelTreeNode alloc] initNodeWithFatherNode:nil];
        fatherNode.objTypeName = [self getFileNameWithoutPathExtensionWithFilePath:key];
        self.currentFileRootNode = fatherNode;
    }
    
    NSArray *keyArray = dic.allKeys;
    for (NSString *keyName in keyArray) {
        JsonModelTreeNode *subNode = [[JsonModelTreeNode alloc] initNodeWithFatherNode:fatherNode];
        [subNode.fatherNode.subContentNodes addObject:subNode];
        
        subNode.objPropertyName = keyName;
        id value = [dic objectForKey:keyName];
        subNode.objTypeName = [self getObjTypeNameWithObject:value
                                                    withNode:subNode];
        
        if ([subNode.objTypeName isEqualToString:@"NSArray"]) {
            //  数组类型，则根据其firstObject来生成protocol
            [subNode.objProtocols addObject:@"ConvertOnDemand"];
            [self setUpJsonInfoTreeRecursivelyWithKey:keyName
                                            withArray:value
                                       withFatherNode:subNode];
        } else if (![self isSystemMetaType:subNode.objTypeName] && subNode.objTypeName.length > 0) {
            //  如果是dictionary类型，那么继续递归
            [self setUpJsonInfoTreeRecursivelyWithKey:keyName
                                              withDic:value
                                       withFatherNode:subNode];
        }
    }
}


/**
 *  递归创建整个jsonInfoTree，传入为NSArray
 *
 *  @param  key     pair中的key
 *  @param  array   pair中的value
 *
 *  举例：     "yooo"  :  ["yeah", "fuck"]
    此时，key为"yooo"，array为["yeah", "fuck"]
 *
 *  @param  fatherNode  jsonInfoTree中的父节点
 */
- (void)setUpJsonInfoTreeRecursivelyWithKey:(NSString *)key
                                  withArray:(NSArray *)array
                             withFatherNode:(JsonModelTreeNode *)fatherNode {
    id obj;
    if (array.count) {
        obj = array.firstObject;
    } else {
        obj = @"";
    }
    
    JsonModelTreeNode *subNodeOfArray = [[JsonModelTreeNode alloc] initNodeWithFatherNode:fatherNode];
    [subNodeOfArray.fatherNode.subContentNodes addObject:subNodeOfArray];
    subNodeOfArray.objPropertyName = @"";
    
    subNodeOfArray.objTypeName = [self getObjTypeNameWithObject:obj
                                                       withNode:subNodeOfArray];

    if (![self isSystemMetaType:subNodeOfArray.objTypeName]) {
        [self setUpJsonInfoTreeRecursivelyWithKey:@""
                                      withJsonObj:obj
                                   withFatherNode:subNodeOfArray];
    }
    [fatherNode.objProtocols addObject:subNodeOfArray.objTypeName];
    [self.allProtocolSet addObject:subNodeOfArray.objTypeName];
}


/**
 *  递归创建整个jsonInfoTree，传入为id，具体会根据外观分流到NSDictionary或者NSArray的对应函数
 *
 *  @param  key     pair中的key
 *  @param  obj     pair中的value
 *  @param  fatherNode  jsonInfoTree中的父节点
 */
- (void)setUpJsonInfoTreeRecursivelyWithKey:(NSString *)key
                                withJsonObj:(id)obj
                                 withFatherNode:(JsonModelTreeNode *)fatherNode {
    if ([obj isKindOfClass:[NSArray class]]) {
        [self setUpJsonInfoTreeRecursivelyWithKey:key
                                        withArray:obj
                                     withFatherNode:fatherNode];
    }
    if ([obj isKindOfClass:[NSDictionary class]]) {
        [self setUpJsonInfoTreeRecursivelyWithKey:key
                                          withDic:obj
                                   withFatherNode:fatherNode];
    }
    if ([obj isKindOfClass:[NSString class]]) {
        if (![fatherNode.objTypeName isEqualToString:@"NSArray"]) {
            NSLog(@"Error: should not have NSString subnote except NSArray father!");
            return;
        }
    }
    if ([obj isKindOfClass:[NSNumber class]]) {
        if (![fatherNode.objTypeName isEqualToString:@"NSArray"]) {
            NSLog(@"Error: should not have NSNumber subnote except NSArray father!");
            return;
        }
    }
}


/**
 *  递归到每个节点写入到.h文件
 *
 *  @param  fileHandle  写入文件指针
 *  @param  node    当前节点
 */
- (void)writeClassesRecursivelyWithFileHandle:(NSFileHandle *)fileHandle
                                     withNode:(JsonModelTreeNode *)node {
    if ([self isSystemMetaType:node.objTypeName]) {
        //  如果是系统基本数据类型，那么返回
        return;
    }
    
    if (![node.objTypeName hasPrefix:@"NS"]) {
        //  jsonModel类型才新建类声明
        NSString *interfaceTemplate = @"\n@interface %@ : JSONModel\n\n";
        NSString *interfaceString = [NSString stringWithFormat:interfaceTemplate, node.objTypeName];
        [fileHandle writeData:[interfaceString dataUsingEncoding:NSUTF8StringEncoding]];
        
        for (JsonModelTreeNode *subNode in node.subContentNodes) {
            NSString *propertyTemplate = @"@property(nonatomic, strong) %@%@ *%@;\n";
            NSString *propertyString = [NSString stringWithFormat:propertyTemplate, subNode.objTypeName, [self getProtocolStringWithNode:subNode], subNode.objPropertyName];
            [fileHandle writeData:[propertyString dataUsingEncoding:NSUTF8StringEncoding]];
        }
        
        NSString *endString = @"\n@end\n\n";
        [fileHandle writeData:[endString dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    for (JsonModelTreeNode *subNode in node.subContentNodes) {
        [self writeClassesRecursivelyWithFileHandle:fileHandle
                                           withNode:subNode];
    }
}


/**
 *  递归到每个节点写入到.m文件
 *
 *  @param  fileHandle  写入文件指针
 *  @param  node    当前节点
 */
- (void)writeClassesImplementationRecursivelyWithFileHandle:(NSFileHandle *)fileHandle
                                                   withNode:(JsonModelTreeNode *)node {
    if ([self isSystemMetaType:node.objTypeName]) {
        //  如果是系统基本数据类型，那么返回
        return;
    }
    
    if (![node.objTypeName hasPrefix:@"NS"]) {
        //  jsonModel类型才新建类声明
        NSString *implementationTemplate = @"\n@implementation %@\n\n";
        NSString *implementationString = [NSString stringWithFormat:implementationTemplate, node.objTypeName];
        [fileHandle writeData:[implementationString dataUsingEncoding:NSUTF8StringEncoding]];

        NSString *propertyOptionalString = @"+ (BOOL)propertyIsOptional:(NSString *)propertyName {\n    return YES;\n}\n";
        [fileHandle writeData:[propertyOptionalString dataUsingEncoding:NSUTF8StringEncoding]];
        
        NSString *endString = @"\n@end\n\n";
        [fileHandle writeData:[endString dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    for (JsonModelTreeNode *subNode in node.subContentNodes) {
        [self writeClassesImplementationRecursivelyWithFileHandle:fileHandle
                                                         withNode:subNode];
    }
}

#pragma mark - Auxiliary Method
- (NSString *)getFormatedDateString {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yy-MM-dd"];
    return [dateFormatter stringFromDate:[NSDate date]];
}

/**
 *  根据NSURL获取文件名（不带扩展名）
 *
 *  @param  url     文件的NSURL对应地址
 */
- (NSString *)getFileNameWithoutPathExtensionWithFileURL:(NSURL *)url {
    NSArray *array = [url.lastPathComponent componentsSeparatedByString:@"."];
    if ([array.firstObject isKindOfClass:[NSString class]]
        && [array.firstObject length] > 0) {
        return array.firstObject;
    } else {
        return @"UnusualName";
    }
}


/**
 *  根据NSString的路径获取文件名（不带扩展名）
 *
 *  @param  path     文件的路径
 */
- (NSString *)getFileNameWithoutPathExtensionWithFilePath:(NSString *)path {
    NSURL *url = [NSURL URLWithString:path];
    return [self getFileNameWithoutPathExtensionWithFileURL:url];
}


/**
 *  获取当前机器桌面路径
 */
- (NSString *)getDesktopFilePath {
    NSArray *destopPathArray = [[NSFileManager defaultManager] URLsForDirectory:NSDesktopDirectory
                                                                      inDomains:NSAllDomainsMask];
    NSURL *fileURL = destopPathArray.firstObject;
    return fileURL.relativePath;
}


#pragma mark - Support Property Type
/**
 *  根据当前的节点类型，创建当前property的名称
 *
 *  @param  object  当前在jsonObj中的对象
 *  @param  currentNode     当前的节点
 *
 *  支持类型如下：
 *
 *  NSString
 *  NSNumber
 *  NSArray
 *  NSDictionary
 *
 *  1.1 添加了 NSNull支持
 */
- (NSString *)getObjTypeNameWithObject:(id)object
                              withNode:(JsonModelTreeNode *)currentNode {
    if ([object isKindOfClass:[NSString class]]) {
        return @"NSString";
    }
    if ([object isKindOfClass:[NSNumber class]]) {
        return @"NSNumber";
    }
    if ([object isKindOfClass:[NSArray class]]) {
        return @"NSArray";
    }
    if ([object isKindOfClass:[NSNull class]]) {
        return @"NSString";
    }
    if ([object isKindOfClass:[NSDictionary class]]) {
        //  正常情况下，父节点应该命名为****JsonModel
        NSString *jsonModelSuffixName = @"JsonModel";
        
        NSString *subNodeOfNSArray = @"";
        NSString *prefixFatherName = @"";
        if ([currentNode.fatherNode.objTypeName isEqualToString:@"NSArray"]) {
            subNodeOfNSArray = @"Item";
            prefixFatherName = [currentNode.fatherNode.fatherNode.objTypeName substringToIndex:currentNode.fatherNode.fatherNode.objTypeName.length - jsonModelSuffixName.length];
        } else {
            prefixFatherName = [currentNode.fatherNode.objTypeName substringToIndex:currentNode.fatherNode.objTypeName.length - jsonModelSuffixName.length];
        }
        
        NSString *finalTypeName = [NSString stringWithFormat:@"%@%@%@%@", prefixFatherName, currentNode.objPropertyName, subNodeOfNSArray, jsonModelSuffixName];
        [self.allJsonModelClassSet addObject:finalTypeName];
        return finalTypeName;
    }
    
    return nil;
}

/**
 *  判断是否为meta数据类型，即（NSString或者NSNumber，目前只有这两种）
 *
 *  @param  type    数据类型
 */
- (BOOL)isSystemMetaType:(NSString *)type {
    return [type hasPrefix:@"NS"] && ![type isEqualToString:@"NSArray"] && ![type isEqualToString:@"NSDictionary"];
}


/**
 *  获取当前node的所有protocol
 *
 *  @param  node    当前需要被提取protocol的节点
 *  @return 例： <ConvertOnDemand, NSString>
 */
- (NSString *)getProtocolStringWithNode:(JsonModelTreeNode *)node {
    if (![node.objTypeName isEqualToString:@"NSArray"]
        || 0 == node.objProtocols.count) {
        return @"";
    }
    if (1 == node.objProtocols.count) {
        return [NSString stringWithFormat:@" <%@>", node.objProtocols.firstObject];
    } else {
        return [NSString stringWithFormat:@" <%@>", [node.objProtocols componentsJoinedByString:@", "]];
    }
}

@end
