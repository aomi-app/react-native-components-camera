import * as React from 'react';
import * as PropTypes from 'prop-types';
import {
  NativeEventEmitter,
  NativeModules,
  Platform,
  requireNativeComponent,
  UIManager,
  ViewPropTypes,
} from 'react-native';
import { Component } from 'react';
import type { Props, OrientationType, QualityType } from './Props';

let CameraManager =
  NativeModules.AMCameraView || NativeModules.SitbCamera2Module;

const { AMCameraView, AMCamera2View }: any = UIManager;

let constants = (AMCameraView || AMCamera2View).Constants;

let CameraFacing = constants.CameraFacing;
let Orientation: OrientationType = constants.Orientation;
let Quality: QualityType = constants.Quality;

let event = new NativeEventEmitter(CameraManager);
let RCTCamera: any;

/**
 * 安卓相机版本
 * 4 使用
 * 5 安卓5.0相机
 * 设置安卓相机版本
 * @param cameraVersion 版本
 */
export function setCameraVersion(cameraVersion: number) {
  if (cameraVersion === 4) {
    CameraManager = NativeModules.SitbCameraView;
    constants = AMCameraView.Constants;
    RCTCamera = requireNativeComponent('SitbCameraView');
  } else if (cameraVersion === 5) {
    CameraManager = NativeModules.SitbCamera2View;
    constants = AMCamera2View.Constants;
    RCTCamera = requireNativeComponent('SitbCamera2View');
  }
  CameraFacing = constants.CameraFacin;
  Orientation = constants.Orientation;
  Quality = constants.Quality;
  event = new NativeEventEmitter(CameraManager);
}

/**
 * @author 田尘殇Sean(sean.snow@live.com)
 * @date 16/6/22
 */
class Camera extends Component<Props, any> {
  static propTypes = {
    ...ViewPropTypes,

    barCodeTypes: PropTypes.array,

    /**
     * 前置相机还是后置相机
     * CameraFacing.back
     * CameraFacing.front
     */
    cameraFacing: PropTypes.oneOfType([PropTypes.number, PropTypes.string]),

    /**
     * Android 需要，该值不需要传递，如果传递了onCaptureOutputBuffer则该值为true
     */
    needCaptureOutputBuffer: PropTypes.bool,

    /**
     * 相机方向
     * Orientation.auto
     * Orientation.landscapeLeft
     * Orientation.landscapeRight
     * Orientation.portrait
     * Orientation.portraitUpsideDown
     */
    orientation: PropTypes.oneOfType([PropTypes.number, PropTypes.string]),
    /**
     * 质量设置
     */
    quality: PropTypes.oneOfType([PropTypes.string, PropTypes.number]),

    onBarCodeRead: PropTypes.func,

    /**
     * 一个回调函数
     * 当需要实时获取预览的图片数据
     */
    onCaptureOutputBuffer: PropTypes.func,
  };

  static defaultProps = {
    cameraFacing: CameraFacing.back,
    orientation: Orientation.auto,
    quality: Quality.high,
  };

  /**
   * 检查是否有相机权限
   * ios only
   */
  static checkVideoAuthorizationStatus = Platform.select<any>({
    ios: CameraManager.checkVideoAuthorizationStatus,
  });
  /**
   * 检查是否有麦克风权限
   * ios only
   */
  static checkAudioAuthorizationStatus = Platform.select<any>({
    ios: CameraManager.checkAudioAuthorizationStatus,
  });

  componentDidMount() {
    if (Platform.OS === 'android') {
      event.addListener('captureOutputBuffer', this.handleCaptureOutputBuffer);
    }
  }

  componentWillUnmount() {
    if (Platform.OS === 'android') {
      event.removeListener(
        'captureOutputBuffer',
        this.handleCaptureOutputBuffer,
      );
    }
  }

  // capture(option: any) {
  //   // return capture(option);
  // }

  handleCaptureOutputBuffer(event: any) {
    this.props.onCaptureOutputBuffer &&
    this.props.onCaptureOutputBuffer(event.nativeEvent.buffer);
  }

  render() {
    const { onCaptureOutputBuffer, ...other } = this.props;
    return (
      <RCTCamera
        {...other}
        needCaptureOutputBuffer={!!onCaptureOutputBuffer}
        onCaptureOutputBuffer={
          onCaptureOutputBuffer ? this.handleCaptureOutputBuffer : null
        }
      />
    );
  }
}

if (AMCameraView) {
  RCTCamera = requireNativeComponent('AMCameraView');
} else if (AMCamera2View) {
  RCTCamera = requireNativeComponent('AMCamera2View');
}

export { Camera as default, Orientation, CameraFacing, Quality };
