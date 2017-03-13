//
//  JsonModelTreeNode.h
//  JsonModelAutoMake
//
//  Created by yangjihang on 14/12/10.
//  Copyright (c) 2014年 yangjihang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JsonModelTreeNode : NSObject

/*
 *  举例：
 *  @property(nonatomic, strong) NSArray <ConvertOnDemand, Ignore> *dynamic;
 *  
 *  此时  objPropertyName为    dynamic
 *       objTypeName为       NSString
 *       objProtocols       为@[@"ConvertOnDemand", @"Ignore"]
 */

@property(nonatomic, strong) NSString *objPropertyName;
@property(nonatomic, strong) NSString *objTypeName;
@property(nonatomic, strong) NSMutableArray *objProtocols;

@property(nonatomic, strong) NSMutableArray *subContentNodes;
@property(nonatomic, weak) JsonModelTreeNode *fatherNode;

- (id)initNodeWithFatherNode:(JsonModelTreeNode *)fatherNode;

@end
