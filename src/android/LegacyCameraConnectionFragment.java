package com.cordovaplugintflite;

import android.app.Fragment;
import android.content.res.Resources;
import android.graphics.SurfaceTexture;
import android.hardware.Camera;
import android.hardware.Camera.CameraInfo;
import android.media.ImageReader;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Size;
import android.util.SparseIntArray;
import android.view.LayoutInflater;
import android.view.Surface;
import android.view.TextureView;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;

import com.cordovaplugintflite.customview.AutoFitTextureView;
import com.cordovaplugintflite.env.ImageUtils;
import com.cordovaplugintflite.env.Logger;

import java.io.IOException;
import java.util.List;

public class LegacyCameraConnectionFragment extends Fragment implements ImageReader.OnImageAvailableListener {

  @Override
  public void onImageAvailable(ImageReader reader) {

  }

  public interface CameraPreviewListener {
    void onPictureTaken(String originalPicture);
    void onPictureTakenError(String message);
    void onSnapshotTaken(String originalPicture);
    void onSnapshotTakenError(String message);
    void onFocusSet(int pointX, int pointY);
    void onFocusSetError(String message);
    void onBackButton();
    void onCameraStarted();
    void onStartRecordVideo();
    void onStartRecordVideoError(String message);
    void onStopRecordVideo(String file);
    void onStopRecordVideoError(String error);
  }

  private static final String TAG = "LegacyCameraConnection";
  private CameraPreviewListener eventListener;
  public String defaultCamera;
  private int numberOfCameras;

  public boolean tapToTakePicture;
  public boolean dragEnabled;
  public boolean tapToFocus;
  public boolean disableExifHeaderStripping;
  public boolean storeToFile;
  public boolean toBack;

  public int width;
  public int height;
  public int x;
  public int y;

  private int cameraCurrentlyLocked;
  private int defaultCameraId;
  private View view;
  private Resources resources;
  private String appResourcesPackage;

  public FrameLayout mainLayout;
  public FrameLayout frameContainerLayout;

  private static final Logger LOGGER = new Logger();
  /** Conversion from screen rotation to JPEG orientation. */
  private static final SparseIntArray ORIENTATIONS = new SparseIntArray();

  static {
    ORIENTATIONS.append(Surface.ROTATION_0, 90);
    ORIENTATIONS.append(Surface.ROTATION_90, 0);
    ORIENTATIONS.append(Surface.ROTATION_180, 270);
    ORIENTATIONS.append(Surface.ROTATION_270, 180);
  }

  private Camera camera;
  private Camera.PreviewCallback imageListener;
  private Size desiredSize;
  /** The layout identifier to inflate for this Fragment. */
  private int layout;
  /** An {@link AutoFitTextureView} for camera preview. */
  private AutoFitTextureView textureView;
  /**
   * {@link TextureView.SurfaceTextureListener} handles several lifecycle events on a {@link
   * TextureView}.
   */
  private final TextureView.SurfaceTextureListener surfaceTextureListener =
          new TextureView.SurfaceTextureListener() {
            @Override
            public void onSurfaceTextureAvailable(
                    final SurfaceTexture texture, final int width, final int height) {

              int index = getCameraId();
              camera = Camera.open(index);

              try {
                Camera.Parameters parameters = camera.getParameters();
                List<String> focusModes = parameters.getSupportedFocusModes();
                if (focusModes != null
                        && focusModes.contains(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE)) {
                  parameters.setFocusMode(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE);
                }
                List<Camera.Size> cameraSizes = parameters.getSupportedPreviewSizes();
                Size[] sizes = new Size[cameraSizes.size()];
                int i = 0;
                for (Camera.Size size : cameraSizes) {
                  sizes[i++] = new Size(size.width, size.height);
                }
                Size previewSize =
                        CameraConnectionFragment.chooseOptimalSize(
                                sizes, desiredSize.getWidth(), desiredSize.getHeight());
                parameters.setPreviewSize(previewSize.getWidth(), previewSize.getHeight());
                camera.setDisplayOrientation(90);
                camera.setParameters(parameters);
                camera.setPreviewTexture(texture);
              } catch (IOException exception) {
                camera.release();
              }

              camera.setPreviewCallbackWithBuffer(imageListener);
              Camera.Size s = camera.getParameters().getPreviewSize();
              camera.addCallbackBuffer(new byte[ImageUtils.getYUVByteSize(s.height, s.width)]);

              textureView.setAspectRatio(s.height, s.width);

              camera.startPreview();
            }

            @Override
            public void onSurfaceTextureSizeChanged(
                    final SurfaceTexture texture, final int width, final int height) {}

            @Override
            public boolean onSurfaceTextureDestroyed(final SurfaceTexture texture) {
              return true;
            }

            @Override
            public void onSurfaceTextureUpdated(final SurfaceTexture texture) {}
          };
  /** An additional thread for running tasks that shouldn't block the UI. */
  private HandlerThread backgroundThread;

  public LegacyCameraConnectionFragment(
    final Camera.PreviewCallback imageListener, final Resources resources, String appResourcesPackage, final Size desiredSize) {
    this.imageListener = imageListener;
    this.resources = resources;
    this.appResourcesPackage = appResourcesPackage;
    this.layout = resources.getIdentifier("camera_activity", "layout", this.appResourcesPackage);
    this.desiredSize = desiredSize;
  }

  public LegacyCameraConnectionFragment() {
//    this.layout = R.layout.camera_activity;
//    this.desiredSize = new Size(640, 480);
  }

  @Override
  public View onCreateView(
          final LayoutInflater inflater, final ViewGroup container, final Bundle savedInstanceState) {
    return inflater.inflate(layout, container, false);
  }

  @Override
  public void onViewCreated(final View view, final Bundle savedInstanceState) {
    textureView = (AutoFitTextureView) view.findViewById(getResources().getIdentifier("texture", "id", appResourcesPackage));
  }

  @Override
  public void onActivityCreated(final Bundle savedInstanceState) {
    super.onActivityCreated(savedInstanceState);
  }

  @Override
  public void onResume() {
    super.onResume();
    startBackgroundThread();
    // When the screen is turned off and turned back on, the SurfaceTexture is already
    // available, and "onSurfaceTextureAvailable" will not be called. In that case, we can open
    // a camera and start preview from here (otherwise, we wait until the surface is ready in
    // the SurfaceTextureListener).

    if (textureView.isAvailable()) {
      camera.startPreview();
    } else {
      textureView.setSurfaceTextureListener(surfaceTextureListener);
    }
  }

  @Override
  public void onPause() {
    stopCamera();
    stopBackgroundThread();
    super.onPause();
  }

  /** Starts a background thread and its {@link Handler}. */
  private void startBackgroundThread() {
    backgroundThread = new HandlerThread("CameraBackground");
    backgroundThread.start();
  }

  /** Stops the background thread and its {@link Handler}. */
  private void stopBackgroundThread() {
    backgroundThread.quitSafely();
    try {
      backgroundThread.join();
      backgroundThread = null;
    } catch (final InterruptedException e) {
      LOGGER.e(e, "Exception!");
    }
  }

  protected void stopCamera() {
    if (camera != null) {
      camera.stopPreview();
      camera.setPreviewCallback(null);
      camera.release();
      camera = null;
    }
  }

  private int getCameraId() {
    CameraInfo ci = new CameraInfo();
    for (int i = 0; i < Camera.getNumberOfCameras(); i++) {
      Camera.getCameraInfo(i, ci);
      if (ci.facing == CameraInfo.CAMERA_FACING_BACK) return i;
    }
    return -1; // No camera found
  }
}
