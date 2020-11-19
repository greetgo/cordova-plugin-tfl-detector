package com.cordovaplugintflite.customview.overlay;

import android.annotation.TargetApi;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.graphics.RectF;
import android.os.Build;
import android.util.AttributeSet;
import android.widget.LinearLayout;


public class CardOverlayView extends LinearLayout {
  private Bitmap bitmap;

  public CardOverlayView(Context context) {
    super(context);
  }

  public CardOverlayView(Context context, AttributeSet attrs) {
    super(context, attrs);
  }

  public CardOverlayView(Context context, AttributeSet attrs, int defStyleAttr) {
    super(context, attrs, defStyleAttr);
  }

  @TargetApi(Build.VERSION_CODES.LOLLIPOP)
  public CardOverlayView(Context context, AttributeSet attrs, int defStyleAttr, int defStyleRes) {
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

    RectF outerRectangle = new RectF(0, 0, getWidth(), getHeight());

    Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    paint.setColor(Color.parseColor("#002f6c"));
    paint.setAlpha(99);
    osCanvas.drawRect(outerRectangle, paint);

    paint.setColor(Color.TRANSPARENT);
    paint.setXfermode(new PorterDuffXfermode(PorterDuff.Mode.SRC_OUT));
//    osCanvas.drawOval(getWidth() * 0.1f, getHeight() * 0.1f, getWidth() * 0.9f, getHeight() * 0.14f + getWidth(), paint);

    float marginBottom = getResources().getDisplayMetrics().density * 56;

    float k = 0.95f;
    float wLayout = k * getWidth();
    float hLayout = wLayout / 1.58f;

    float left = (getWidth() - wLayout) / 2;
    float top = (getHeight() + marginBottom - hLayout) / 2;
    float right = left + wLayout;
    float bottom = top + hLayout;
    float rx = wLayout * 0.035f;
    osCanvas.drawRoundRect(left, top, right, bottom, rx, rx, paint);

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