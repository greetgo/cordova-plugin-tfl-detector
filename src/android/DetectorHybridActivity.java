package com.cordovaplugintflite;

import android.graphics.Bitmap;
import android.graphics.Bitmap.Config;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.Paint.Style;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.os.SystemClock;
import android.util.Log;
import android.util.Size;
import android.util.TypedValue;
import android.widget.ImageView;
import android.widget.Toast;

import com.cordovaplugintflite.customview.OverlayView;
import com.cordovaplugintflite.customview.OverlayView.DrawCallback;
import com.cordovaplugintflite.env.BorderedText;
import com.cordovaplugintflite.env.ImageUtils;
import com.cordovaplugintflite.env.Logger;
import com.cordovaplugintflite.tflite.Classifier;
import com.cordovaplugintflite.tflite.YoloV4Classifier;
import com.cordovaplugintflite.tracking.MultiBoxTracker;

import java.io.IOException;
import java.util.LinkedList;
import java.util.List;
import java.util.Objects;

/**
 * An activity that uses a TensorFlowMultiBoxDetector and ObjectTracker to detect and then track
 * objects.
 */
public class DetectorHybridActivity extends CameraActivity {
  private static final Logger LOGGER = new Logger();

  private static final int TF_OD_API_INPUT_SIZE = 416;
  private static final boolean TF_OD_API_IS_QUANTIZED = true;
  private static final String TF_OD_API_MODEL_FILE = "yolov4full.tflite";

  private static final String TF_OD_API_LABELS_FILE = "file:///android_asset/coco.txt";

  private static final DetectorMode MODE = DetectorMode.TF_OD_API;
  private static final float MINIMUM_CONFIDENCE_TF_OD_API = 0.5f;
  private static final boolean MAINTAIN_ASPECT = false;
  //  private static final Size DESIRED_PREVIEW_SIZE = new Size(640, 480);
  private static final Size DESIRED_PREVIEW_SIZE = new Size(1280, 960);
  //  private static final Size DESIRED_PREVIEW_SIZE = new Size(1280, 960);
  private static final boolean SAVE_PREVIEW_BITMAP = false;
  private static final float TEXT_SIZE_DIP = 10;
  OverlayView trackingOverlay;
  private Integer sensorOrientation;

  private Classifier detector;

  private long lastProcessingTimeMs;
  private Bitmap rgbFrameBitmap = null;
  private Bitmap croppedBitmap = null;
  private Bitmap cropCopyBitmap = null;

  private boolean computingDetection = false;

  private long timestamp = 0;

  private Matrix frameToCropTransform;
  private Matrix cropToFrameTransform;

  private MultiBoxTracker tracker;

  private BorderedText borderedText;

  private ImageView overlayImageView;
  private Drawable overlayDrawableGreen;
  private Drawable overlayDrawableBlue;

  @Override
  public void onPreviewSizeChosen(final Size size, final int rotation) {

    String drawableName = "overlay_ellipse";
    String imageViewId = "selfie_layout";
    if (!"selfie".equals(overlay)) {
      drawableName = "overlay_card";
      imageViewId = "card_layout";
    }
    overlayImageView = view.findViewById(getResources().getIdentifier(imageViewId, "id", appResourcesPackage));
    overlayDrawableGreen = getResources().getDrawable(getResources().getIdentifier(drawableName + "_green", "drawable", appResourcesPackage));
    overlayDrawableBlue = getResources().getDrawable(getResources().getIdentifier(drawableName, "drawable", appResourcesPackage));

    final float textSizePx =
      TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, TEXT_SIZE_DIP, getResources().getDisplayMetrics());
    borderedText = new BorderedText(textSizePx);
    borderedText.setTypeface(Typeface.MONOSPACE);

    tracker = new MultiBoxTracker(getActivity());

    int cropSize = TF_OD_API_INPUT_SIZE;

    try {
      detector =
        YoloV4Classifier.create(
          getActivity().getAssets(),
          TF_OD_API_MODEL_FILE,
          TF_OD_API_LABELS_FILE,
          TF_OD_API_IS_QUANTIZED);
//            detector = TFLiteObjectDetectionAPIModel.create(
//                    getAssets(),
//                    TF_OD_API_MODEL_FILE,
//                    TF_OD_API_LABELS_FILE,
//                    TF_OD_API_INPUT_SIZE,
//                    TF_OD_API_IS_QUANTIZED);
    } catch (final IOException e) {
      e.printStackTrace();
      LOGGER.e(e, "Exception initializing classifier!");
      Toast toast =
        Toast.makeText(
          getActivity().getApplicationContext(), "Classifier could not be initialized", Toast.LENGTH_SHORT);
      toast.show();
      getActivity().finish();
    }

    previewWidth = size.getWidth();
    previewHeight = size.getHeight();

    sensorOrientation = rotation - getScreenOrientation();
    LOGGER.i("Camera orientation relative to screen canvas: %d", sensorOrientation);

    LOGGER.i("Initializing at size %dx%d", previewWidth, previewHeight);
    rgbFrameBitmap = Bitmap.createBitmap(previewWidth, previewHeight, Config.ARGB_8888);
    croppedBitmap = Bitmap.createBitmap(cropSize, cropSize, Config.ARGB_8888);

    if (sensorOrientation % 90 != 0) {
      int height = (int) (h0 * previewHeight);
      int width = Math.min((int) (w0 * previewWidth), (int) (height * 1.58));

      frameToCropTransform =
        ImageUtils.getTransformationMatrix(
          width, height,
          cropSize, cropSize,
          sensorOrientation, MAINTAIN_ASPECT);
    } else {
      int width = (int) (h0 * previewWidth);
      int height = Math.min((int) (w0 * previewHeight), (int) (width * 1.58));

      frameToCropTransform =
        ImageUtils.getTransformationMatrix(
          width, height,
          cropSize, cropSize,
          sensorOrientation, MAINTAIN_ASPECT);
    }

    cropToFrameTransform = new Matrix();
    frameToCropTransform.invert(cropToFrameTransform);

    trackingOverlay = (OverlayView) getActivity().findViewById(getResources().getIdentifier("tracking_overlay", "id", appResourcesPackage));
    trackingOverlay.addCallback(
      new DrawCallback() {
        @Override
        public void drawCallback(final Canvas canvas) {
          tracker.draw(canvas);
          if (isDebug()) {
            tracker.drawDebug(canvas);
          }
        }
      });

    tracker.setFrameConfiguration(previewWidth, previewHeight, sensorOrientation);
  }

  @Override
  protected void processImage() {
    ++timestamp;
    final long currTimestamp = timestamp;
    trackingOverlay.postInvalidate();

    // No mutex needed as this method is not reentrant.
    if (computingDetection) {
      readyForNextImage();
      return;
    }
    computingDetection = true;
    LOGGER.i("Preparing image " + currTimestamp + " for detection in bg thread.");

    rgbFrameBitmap.setPixels(getRgbBytes(), 0, previewWidth, 0, 0, previewWidth, previewHeight);

    int w = rgbFrameBitmap.getWidth();
    int h = rgbFrameBitmap.getHeight();
    Bitmap rgbFrameBitmapCustom;
    if (sensorOrientation % 90 != 0) {
      int height = (int) (h0 * h);
      int y = (int) (y0 * h);
      int width = Math.min((int) (w0 * w), (int) (height * 1.58));
      int x = ((int) (w0 * w) - width) / 2;
      rgbFrameBitmapCustom = Bitmap.createBitmap(rgbFrameBitmap, x, y, width, height);
    } else {
      int width = (int) (h0 * w);
      int x = (int) (y0 * w);
      int height = Math.min((int) (w0 * h), (int) (width * 1.58));
      int y = ((int) (w0 * h) - height) / 2;
      rgbFrameBitmapCustom = Bitmap.createBitmap(rgbFrameBitmap, x, y, width, height);
    }

    readyForNextImage();

    final Canvas canvas = new Canvas(croppedBitmap);
    canvas.drawBitmap(rgbFrameBitmapCustom, frameToCropTransform, null);
    // For examining the actual TF input.
    if (SAVE_PREVIEW_BITMAP) {
      ImageUtils.saveBitmap(croppedBitmap);
    }

    runInBackground(
      new Runnable() {
        @Override
        public void run() {
          LOGGER.i("Running detection on image " + currTimestamp);
          final long startTime = SystemClock.uptimeMillis();
          final List<Classifier.Recognition> results = detector.recognizeImage(croppedBitmap);
          lastProcessingTimeMs = SystemClock.uptimeMillis() - startTime;

          Log.e("CHECK", "run: " + results.size());

          cropCopyBitmap = Bitmap.createBitmap(croppedBitmap);
          final Canvas canvas = new Canvas(cropCopyBitmap);
          final Paint paint = new Paint();
          paint.setColor(Color.RED);
          paint.setStyle(Style.STROKE);
          paint.setStrokeWidth(2.0f);

          final List<Classifier.Recognition> mappedRecognitions =
            new LinkedList<Classifier.Recognition>();

//          if (results.isEmpty()) eventListener.onObjectDetected(null);

          String detectedObject = null;
          float max = 0;
          for (final Classifier.Recognition result : results) {
//          if (results.size() > 0) {
//            final Classifier.Recognition result = results.get(0);

            final RectF location = result.getLocation();
            if (location != null && result.getConfidence() >= MINIMUM_CONFIDENCE_TF_OD_API) {
              canvas.drawRect(location, paint);

              cropToFrameTransform.mapRect(location);

              result.setLocation(location);
              mappedRecognitions.add(result);

              if (result.getConfidence() > max) {
                max = result.getConfidence();
                detectedObject = result.getTitle();
              }

//              eventListener.onObjectDetected(result.getTitle());
//              LOGGER.i("Detected object: " + result.getTitle());
//              break;
            }
          }

          eventListener.onObjectDetected(detectedObject);

          String finalDetectedObject = detectedObject;
          if (getActivity() != null) {
            getActivity().runOnUiThread(new Runnable() {

              @Override
              public void run() {
                if (Objects.equals(finalDetectedObject, overlay)) {
                  overlayImageView.setImageDrawable(overlayDrawableGreen);
                } else {
                  overlayImageView.setImageDrawable(overlayDrawableBlue);
                }
              }
            });
          }

          //uncomment line below to enable bounding-box tracker
//          tracker.trackResults(mappedRecognitions, currTimestamp);
//          LOGGER.i("Detected object: " + detectedObject);
          trackingOverlay.postInvalidate();

          computingDetection = false;

//          getActivity().runOnUiThread(
//            new Runnable() {
//              @Override
//              public void run() {
//                showFrameInfo(previewWidth + "x" + previewHeight);
//                showCropInfo(cropCopyBitmap.getWidth() + "x" + cropCopyBitmap.getHeight());
//                showInference(lastProcessingTimeMs + "ms");
//              }
//            });
        }
      });
  }

  @Override
  protected int getLayoutId() {
    return getResources().getIdentifier("camera_activity", "layout", appResourcesPackage);
  }

  @Override
  protected Size getDesiredPreviewFrameSize() {
    return DESIRED_PREVIEW_SIZE;
  }

  // Which detection model to use: by default uses Tensorflow Object Detection API frozen
  // checkpoints.
  private enum DetectorMode {
    TF_OD_API;
  }

  @Override
  protected void setUseNNAPI(final boolean isChecked) {
    runInBackground(() -> detector.setUseNNAPI(isChecked));
  }

  @Override
  protected void setNumThreads(final int numThreads) {
    runInBackground(() -> detector.setNumThreads(numThreads));
  }
}
