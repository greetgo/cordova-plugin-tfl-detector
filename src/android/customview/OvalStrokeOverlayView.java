package com.cordovaplugintflite.customview;

import android.annotation.TargetApi;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.os.Build;
import android.util.AttributeSet;
import android.widget.LinearLayout;

public class OvalStrokeOverlayView extends LinearLayout {
  private Bitmap bitmap;

  public OvalStrokeOverlayView(Context context) {
    super(context);
  }

  public OvalStrokeOverlayView(Context context, AttributeSet attrs) {
    super(context, attrs);
  }

  public OvalStrokeOverlayView(Context context, AttributeSet attrs, int defStyleAttr) {
    super(context, attrs, defStyleAttr);
  }

  @TargetApi(Build.VERSION_CODES.LOLLIPOP)
  public OvalStrokeOverlayView(Context context, AttributeSet attrs, int defStyleAttr, int defStyleRes) {
    super(context, attrs, defStyleAttr, defStyleRes);
  }

  @Override
  protected void dispatchDraw(Canvas canvas) {
    super.dispatchDraw(canvas);

    if (bitmap == null) {
      createWindowFrame();
    }
    canvas.drawBitmap(bitmap, 0, 0, null);
  }

  protected void createWindowFrame() {
    bitmap = Bitmap.createBitmap(getWidth(), getHeight(), Bitmap.Config.ARGB_8888);
    Canvas osCanvas = new Canvas(bitmap);

    Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    paint.setStrokeWidth(8);
    paint.setStyle(Paint.Style.STROKE);
    paint.setColor(Color.GREEN);
    paint.setXfermode(new PorterDuffXfermode(PorterDuff.Mode.SRC_OUT));
    osCanvas.drawOval(getWidth() * 0.1f, getHeight() * 0.1f, getWidth() * 0.9f, getHeight() * 0.14f + getWidth(), paint);
  }

  @Override
  public boolean isInEditMode() {
    return true;
  }

  @Override
  protected void onLayout(boolean changed, int l, int t, int r, int b) {
    super.onLayout(changed, l, t, r, b);
    bitmap = null;
  }
}