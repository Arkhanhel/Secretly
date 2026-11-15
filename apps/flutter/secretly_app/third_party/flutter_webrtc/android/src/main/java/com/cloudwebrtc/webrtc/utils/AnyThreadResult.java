package com.cloudwebrtc.webrtc.utils;

import android.os.Looper;
import android.os.Handler;
import android.util.Log;

import java.util.concurrent.atomic.AtomicBoolean;

import io.flutter.plugin.common.MethodChannel;

public final class AnyThreadResult implements MethodChannel.Result {
    final private MethodChannel.Result result;
    final private Handler handler = new Handler(Looper.getMainLooper());

    // Secretly (15.11.2026, Play Console: crash «Reply already submitted» in
    // getUserMedia after the permission result): a second answer to the same
    // call crashed the app. Only the first answer is delivered; later ones are
    // logged and dropped.
    final private AtomicBoolean replied = new AtomicBoolean(false);

    public AnyThreadResult(MethodChannel.Result result) {
        this.result = result;
    }

    @Override
    public void success(Object o) {
        if (!claim("success")) return;
        post(()->result.success(o));
    }

    @Override
    public void error(String s, String s1, Object o) {
        if (!claim("error " + s)) return;
        post(()->result.error(s, s1, o));
    }

    @Override
    public void notImplemented() {
        if (!claim("notImplemented")) return;
        post(result::notImplemented);
    }

    private boolean claim(String what) {
        if (replied.compareAndSet(false, true)) return true;
        Log.w("FlutterWebRTCPlugin", "AnyThreadResult: dropped a second reply (" + what + ")");
        return false;
    }

    private void post(Runnable r) {
        if(Looper.getMainLooper() == Looper.myLooper()){
            r.run();
        }else{
            handler.post(r);
        }
    }
}
