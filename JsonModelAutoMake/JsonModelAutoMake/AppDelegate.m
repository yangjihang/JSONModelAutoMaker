//
//  AppDelegate.m
//  JsonModelAutoMake
//
//  Created by yangjihang on 14/12/9.
//  Copyright (c) 2014年 yangjihang. All rights reserved.
//

#import "AppDelegate.h"
#import "JsonModelTreeNode.h"

//  HeaderFileNameKey in resultDictionary
NSString * const HeaderFileNameKey = @"autoGenerateHeaderFileNameKey";
//  SourceFileNameKey in resultDictionary
NSString * const ResourceFileNameKey = @"autoGenerateResourceFileNameKey";

@interface AppDelegate () 

@property (weak) IBOutlet NSWindow *window;

//  Found all *.json format file on the Desktop and save filePath in Array
@property(nonatomic, strong) NSMutableArray *allJsonFilePathArray;

//  the rootNode for current file in JSONInfoTree
@property(nonatomic, strong) JsonModelTreeNode *currentFileRootNode;
//  save all protocols of current JSONInfoTree into set
@property(nonatomic, strong) NSMutableSet *allProtocolSet;
//  save all classNames of current JSONInfoTree into set
@property(nonatomic, strong) NSMutableSet *allJsonModelClassSet;

//  template for file info (such as author, date and so on)
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
            //  check if it is NSDictionary class
            return;
        }
        NSDictionary *dic = jsonObj;
        if (0 == dic.count) {
            //  check if it is an empty dictionary
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
 *  iterates all *.json file on the Desktop, generate JSONModel file on Desktop
 */
- (void)generateJsonModelAccordingToJsonFileFromDesktop {
    //  read all *.json file on Desktop and save path into allJsonFilePathArray
    [self readAndRecordAllJsonFilePath];
    
    //  iterates json files, create header file and source file
    for (NSURL *url in self.allJsonFilePathArray) {
        _currentFileRootNode = nil;
        _allJsonFilePathArray = nil;
        _allJsonModelClassSet = nil;
        
        [self generateHeaderAndResourceFileWithJsonFileURL:url];
    }
}


/**
 *  read all *.json file and save path into allJsonFilePathArray
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
 *  generate .h and .m file according to NSURL
 *
 *  @param  url     JSON file url on Desktop
 */
- (void)generateHeaderAndResourceFileWithJsonFileURL:(NSURL *)url {
    NSError *error;
    NSData *jsonData = [NSData dataWithContentsOfURL:url];
    id jsonObj = [NSJSONSerialization JSONObjectWithData:jsonData
                                                 options:0
                                                   error:&error];
    if (![jsonObj isKindOfClass:[NSDictionary class]]) {
        //  check NSDictionary class type
        return;
    }
    NSDictionary *dic = jsonObj;
    if (0 == dic.count) {
        //  check if it is an empty dictionary
        return;
    }

    [self generateHeaderAndResourceFileWithJsonFileURL:url
                                           withJsonObj:jsonObj];
}

/**
 *  generate .h and .m file according to NSURL
 *
 *  @param  url         JSON file url on Desktop
 *  @param  jsonObj     meta NSDictionary object used to save .h and .m filename
 */
- (void)generateHeaderAndResourceFileWithJsonFileURL:(NSURL *)url
                                         withJsonObj:(id)jsonObj {
    NSDictionary *dic = jsonObj;
    
    //  create empty .h and .m file
    NSMutableDictionary *resultMutableDic = [NSMutableDictionary dictionary];
    if (![self createEmptyHeaderAndResourceFileWithURL:url
                                        withDictionary:resultMutableDic]) {
        //  return if fail to create file
        return;
    }
    
    NSString *headerFileFullPath = [[self getDesktopFilePath] stringByAppendingPathComponent:[resultMutableDic objectForKey:HeaderFileNameKey]];
    NSString *sourceFileFullPath = [[self getDesktopFilePath] stringByAppendingPathComponent:[resultMutableDic objectForKey:ResourceFileNameKey]];

    /*
     *  analyze object recursively and generate jsonInfoTree
     */
    [self setUpJsonInfoTreeRecursivelyWithKey:[self getFileNameWithoutPathExtensionWithFilePath:headerFileFullPath]
                                  withJsonObj:dic
                               withFatherNode:nil];
    
    //  delete root classname in set, then use the set to make pre-declaration
    [self.allJsonModelClassSet removeObject:self.currentFileRootNode.objTypeName];
    
    /*
     *  add info to header file according to jsonInfoTree
     */
    //  prepare classes pre-declaration
    NSArray *array = [self.allJsonModelClassSet allObjects];
    NSString *classString = @"";
    NSString *classDeclareTemplate = @"\n@class %@;\n";
    if (1 == array.count) {
        classString = [NSString stringWithFormat:classDeclareTemplate, array.firstObject];
    } else {
        classString = [NSString stringWithFormat:classDeclareTemplate, [array componentsJoinedByString:@", "]];
    }
    
    //  prepare protocols pre-declaration
    NSString *protocolTemplate = @"\n@protocol %@ <NSObject>\n@end\n";

    //  open .h fileHandle and ready to add info to header file
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:headerFileFullPath];
    [fileHandle truncateFileAtOffset:[fileHandle seekToEndOfFile]];
    
    //  write classes pre-declaration
    NSData *data = [classString dataUsingEncoding:NSUTF8StringEncoding];
    [fileHandle writeData:data];
    
    //  write protocols pre-declaration
    for (NSString *protocolName in self.allProtocolSet) {
        NSString *dataString = [NSString stringWithFormat:protocolTemplate, protocolName];
        NSData *data = [dataString dataUsingEncoding:NSUTF8StringEncoding];
        [fileHandle writeData:data];
    }
    
    //  write every class info to header file recursively
    [self writeClassesRecursivelyWithFileHandle:fileHandle
                                       withNode:self.currentFileRootNode];
    
    //  close .h file's fileHandle
    [fileHandle closeFile];
    
    
    /*
     *  add info to source file according to jsonInfoTree
     */
    NSFileHandle *sourceFileHandle = [NSFileHandle fileHandleForWritingAtPath:sourceFileFullPath];
    [sourceFileHandle truncateFileAtOffset:[sourceFileHandle seekToEndOfFile]];
    
    //  write classes implementation to source file
    [self writeClassesImplementationRecursivelyWithFileHandle:sourceFileHandle
                                                     withNode:self.currentFileRootNode];

    //  close .m file's fileHandle
    [sourceFileHandle closeFile];
}


/**
 *  create empty .h and .m file
 *
 *  @param  url         JSON file url on the Desktop
 *  @param  resultDic   key:HeaderFileNameKey,ResourceFileNameKey
 *                      value:"real header fileName", "real source fileName"
 */
- (BOOL)createEmptyHeaderAndResourceFileWithURL:(NSURL *)url
                                 withDictionary:(NSMutableDictionary *)resultDic {
    /*
     *  first of all, create header file
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
        //  fail to create .h file
        return NO;
    }
    
    /*
     *  create source file according to header file
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
 *  create whole jsonInfoTree recursively pass a dictionary
 *
 *  @param  key     key in pair
 *  @param  dic     value in pair
 *  for example:     "yooo"  :   {
                                 "yeah"  :   "1",
                                 "fuck"  :   "2"
                                 }
        in the example
        param key is "yooo", dic is {"yeah":"1","fuck":"2"}
 *  @param  fatherNode  fatherNode of currentNode in the jsonInfoTree
 */
- (void)setUpJsonInfoTreeRecursivelyWithKey:(NSString *)key
                                    withDic:(NSDictionary *)dic
                             withFatherNode:(JsonModelTreeNode *)fatherNode {
    if (nil == fatherNode) {
        //  create the Root Node
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
            //  if it is NSArray type, then generate its protocol according to NSArray's first object
            [subNode.objProtocols addObject:@"ConvertOnDemand"];
            [self setUpJsonInfoTreeRecursivelyWithKey:keyName
                                            withArray:value
                                       withFatherNode:subNode];
        } else if (![self isSystemMetaType:subNode.objTypeName] && subNode.objTypeName.length > 0) {
            //  if it is NSDictionary type, then go on recursion
            [self setUpJsonInfoTreeRecursivelyWithKey:keyName
                                              withDic:value
                                       withFatherNode:subNode];
        }
    }
}


/**
 *  create whole jsonInfoTree recursively pass an array type
 *
 *  @param  key     key in pair
 *  @param  dic     value in pair
 *
 *  for example:     "yooo"  :  ["yeah", "fuck"]
    in the example
    param key is "yooo", array is ["yeah", "fuck"]
 *
 *  @param  fatherNode  fatherNode of currentNode in the jsonInfoTree
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
 *  create whole jsonInfoTree recursively
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
