//
//  ABI22_0_0AIRGoogleMapPolyline.m
//
//  Created by Nick Italiano on 10/22/16.
//
#import <UIKit/UIKit.h>
#import "ABI22_0_0AIRGoogleMapPolyline.h"
#import "ABI22_0_0AIRMapCoordinate.h"
#import "ABI22_0_0AIRGoogleMapMarker.h"
#import "ABI22_0_0AIRGoogleMapMarkerManager.h"
#import <GoogleMaps/GoogleMaps.h>
#import <ReactABI22_0_0/ABI22_0_0RCTUtils.h>

@implementation ABI22_0_0AIRGoogleMapPolyline

- (instancetype)init
{
  if (self = [super init]) {
    _polyline = [[GMSPolyline alloc] init];
  }
  return self;
}

-(void)setCoordinates:(NSArray<ABI22_0_0AIRMapCoordinate *> *)coordinates
{
  _coordinates = coordinates;
  
  GMSMutablePath *path = [GMSMutablePath path];
  for(int i = 0; i < coordinates.count; i++)
  {
    [path addCoordinate:coordinates[i].coordinate];
  }
  
   _polyline.path = path;
}

-(void)setStrokeColor:(UIColor *)strokeColor
{
  _strokeColor = strokeColor;
  _polyline.strokeColor = strokeColor;
}

-(void)setStrokeWidth:(double)strokeWidth
{
  _strokeWidth = strokeWidth;
  _polyline.strokeWidth = strokeWidth;
}

-(void)setFillColor:(UIColor *)fillColor
{
  _fillColor = fillColor;
  _polyline.spans = @[[GMSStyleSpan spanWithColor:fillColor]];
}

-(void)setGeodesic:(BOOL)geodesic
{
  _geodesic = geodesic;
  _polyline.geodesic = geodesic;
}

-(void)setTitle:(NSString *)title
{
  _title = title;
  _polyline.title = _title;
}

-(void) setZIndex:(int)zIndex
{
  _zIndex = zIndex;
  _polyline.zIndex = zIndex;
}

@end
