//
//  B3DGUITouchable.h
//  Bane3D
//
//  Created by Andreas Hanft on 28.04.11.
//
//
//  Copyright (C) 2012 Andreas Hanft (talantium.net)
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included
//  in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
//  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
//

#import <UIKit/UIKit.h>
#import <Bane3D/SceneGraph/Visible/2D/GUI/B3DGUIImage.h>
#import <Bane3D/Core/B3DConstants.h>


@interface B3DGUITouchable : B3DGUIImage
{
    @protected
        UITouch*				_touches[B3DGUITouchableTouchesCount];
        BOOL                    _touchInside[B3DGUITouchableTouchesCount];
        uint                    _touchCount;
}

@property (nonatomic, readonly) BOOL        touched;
@property (nonatomic, readonly) BOOL        multitouched;
@property (nonatomic, readonly) uint        touchCount;

@property (nonatomic, assign)   BOOL        multitouchEnabled;

@property (weak, nonatomic, readonly) UITouch*    firstTouch;
@property (weak, nonatomic, readonly) UITouch*    secondTouch;
@property (weak, nonatomic, readonly) UITouch*    thirdTouch;

- (BOOL) rectContainsTouch:(UITouch*)touch forView:(UIView*)view;

@end
