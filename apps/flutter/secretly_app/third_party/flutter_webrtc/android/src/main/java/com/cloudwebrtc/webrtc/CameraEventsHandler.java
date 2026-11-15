package com.cloudwebrtc.webrtc;

import android.util.Log;

import org.webrtc.CameraVideoCapturer;

class CameraEventsHandler implements CameraVideoCapturer.CameraEventsHandler {
    public enum CameraState {
        NEW,
        OPENING,
        OPENED,
        CLOSED,
        DISCONNECTED,
        ERROR,
        FREEZED
    }
    private final static String TAG = FlutterWebRTCPlugin.TAG;
    // Secretly (15.11.2026, Play Console: ANR «waitForCameraOpen»): the state is
    // written on the camera thread and read by the waiting thread, so it must be
    // volatile — a plain field could be cached and the wait never see OPENED.
    private volatile CameraState state = CameraState.NEW;
    private final Object stateLock = new Object();

    // Secretly: the original waits spun forever on the MAIN thread. A camera
    // held by another app never reports OPENED, and the app froze until Android
    // killed it (ANR). Bounded now: the caller carries on, and the camera starts
    // delivering frames if it opens later (WebRTC itself retries a busy camera).
    static final long OPEN_TIMEOUT_MS = 3000;
    static final long CLOSE_TIMEOUT_MS = 3000;

    /** @return true when the camera reported OPENED (or ERROR) within the limit. */
    public boolean waitForCameraOpen() {
        Log.d(TAG, "CameraEventsHandler.waitForCameraOpen");
        return waitFor(OPEN_TIMEOUT_MS, CameraState.OPENED);
    }

    public boolean waitForCameraClosed() {
        Log.d(TAG, "CameraEventsHandler.waitForCameraClosed");
        return waitFor(CLOSE_TIMEOUT_MS, CameraState.CLOSED);
    }

    private boolean waitFor(long timeoutMs, CameraState target) {
        final long deadline = System.currentTimeMillis() + timeoutMs;
        synchronized (stateLock) {
            while (state != target && state != CameraState.ERROR) {
                final long left = deadline - System.currentTimeMillis();
                if (left <= 0) {
                    Log.w(TAG, "CameraEventsHandler: no " + target + " within " + timeoutMs + " ms, state=" + state);
                    return false;
                }
                try {
                    stateLock.wait(left);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    return false;
                }
            }
        }
        return true;
    }

    private void setState(CameraState next) {
        synchronized (stateLock) {
            state = next;
            stateLock.notifyAll();
        }
    }

    // Camera error handler - invoked when camera can not be opened
    // or any camera exception happens on camera thread.
    @Override
    public void onCameraError(String errorDescription) {
        Log.d(TAG, String.format("CameraEventsHandler.onCameraError: errorDescription=%s", errorDescription));
        setState(CameraState.ERROR);
    }

    // Called when camera is disconnected.
    @Override
    public void onCameraDisconnected() {
        Log.d(TAG, "CameraEventsHandler.onCameraDisconnected");
        setState(CameraState.DISCONNECTED);
    }

    // Invoked when camera stops receiving frames
    @Override
    public void onCameraFreezed(String errorDescription) {
        Log.d(TAG, String.format("CameraEventsHandler.onCameraFreezed: errorDescription=%s", errorDescription));
        setState(CameraState.FREEZED);
    }

    // Callback invoked when camera is opening.
    @Override
    public void onCameraOpening(String cameraName) {
        Log.d(TAG, String.format("CameraEventsHandler.onCameraOpening: cameraName=%s", cameraName));
        setState(CameraState.OPENING);
    }

    // Callback invoked when first camera frame is available after camera is opened.
    @Override
    public void onFirstFrameAvailable() {
        Log.d(TAG, "CameraEventsHandler.onFirstFrameAvailable");
        setState(CameraState.OPENED);
    }

    // Callback invoked when camera closed.
    @Override
    public void onCameraClosed() {
        Log.d(TAG, "CameraEventsHandler.onFirstFrameAvailable");
        setState(CameraState.CLOSED);
    }
}
