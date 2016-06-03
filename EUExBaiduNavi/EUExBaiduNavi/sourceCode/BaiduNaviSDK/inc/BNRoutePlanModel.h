//
//  BNaviRoutePlanModel.h
//  OfflineNavi
//
//  Created by Baidu on 4/11/13.
//  Copyright (c) 2013 baidu. All rights reserved.
//
//  路线规划节点数据结构类


#import <Foundation/Foundation.h>

/**
 * 坐标系类型
 */
typedef enum
{
    BNCoordinate_OriginalGPS = 0,/**< 原始的经纬度坐标 */
    BNCoordinate_BaiduMapSDK = 1,/**< 从百度地图中获取的sdk */
}BNCoordinate_Type;

/**
 * 坐标对象
 */
@interface BNPosition : NSObject

/**
 * 经度
 */
@property(nonatomic,assign)double x;

/**
 *  纬度
 */
@property(nonatomic,assign)double y;

/**
 *  坐标系类型，默认是BNCoordinate_OriginalGPS
 */
@property(nonatomic,assign)BNCoordinate_Type eType;

@end

/**
 *  路径规划节点对象
 */
@interface BNRoutePlanNode : NSObject
/**
 *  节点位置（经纬度信息）
 */
@property(nonatomic,retain)BNPosition* pos;
/**
 *  节点描述信息
 */
@property(nonatomic,copy)NSString* title;
/**
 *  节点地址信息
 */
@property(nonatomic,copy)NSString* address;

@end

/**
 *  分时段规划，路线的时间对象
 */
@interface BNaviCalcRouteTime : NSObject
/**
 *  小时，24小时制，0-23
 */
@property(nonatomic,assign)int unHour;
/**
 *  分钟，0-59
 */
@property(nonatomic,assign)int unMin;

@end


/**
 *  每个路段信息
 */
@interface BNRouteItem : NSObject

/**
 *  机动类型
 */
//@property(nonatomic,assign)BNavi_Maneuver_Kind_Enum eManeuverKind;

/**
 *  路名
 */
@property(nonatomic,copy)NSString* nextRoadName;

/**
 *  长度，单位米
 */
@property(nonatomic,assign)int nLength;

/**
 *  时间，单位秒
 */
@property(nonatomic,assign)int nTime;

/**
 *  交叉路口坐标
 */
@property(nonatomic,retain)BNPosition* crossPos;

/**
 *  在路线中的显示点索引
 */
@property(nonatomic,assign)int nShapePointIdx;

/**
 *  脱产Link和正北方向的夹角，单位度
 */
@property(nonatomic,assign)int unOutLinkAngle;

//-(id)initWithNE_RouteInfoItem_t:(const NE_RouteInfoItem_t&)stRouteInfoItem;
@end

/**
 *  路线详情信息
 */
@interface BNRouteDetailInfo : NSObject

/**
 *  总长度，单位米
 */
@property(nonatomic,assign)int unLength;

/**
 *  总时间，单位秒
 */
@property(nonatomic,assign)int unPasstime;

/**
 *  路段详情列表,每一个元素是BNaviRouteItem类型
 */
@property(nonatomic,retain)NSArray*  routeItemList;

/**
 *  是否包含收费路段
 */
@property(nonatomic,assign)BOOL bTolled;

//-(id)initWithRouteInfo:(const NE_RouteInfo_t&)stRouteInfo;
@end




