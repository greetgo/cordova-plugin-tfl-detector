package com.cordovaplugintflite.customview;

import com.cordovaplugintflite.tflite.Classifier.Recognition;

import java.util.List;

public interface ResultsView {
  public void setResults(final List<Recognition> results);
}
