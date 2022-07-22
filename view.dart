package com.lykluk.lykluk;
import android.graphics.Bitmap;
import android.media.Image;
import android.os.Build;
import android.util.DisplayMetrics;
import android.util.Size;
import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.view.Surface;
import android.view.SurfaceView;
import android.view.View;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.camera.core.AspectRatio;
import androidx.camera.core.CameraProvider;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageAnalysis;
import androidx.camera.core.ImageCapture;
import androidx.camera.core.ImageProxy;
import androidx.camera.core.Preview;
import androidx.camera.core.VideoCapture;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.view.PreviewView;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.lifecycle.LifecycleOwner;

import com.google.common.util.concurrent.ListenableFuture;

import org.w3c.dom.Text;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Map;
import java.util.concurrent.ExecutionException;

import ai.deepar.ar.DeepAR;
import ai.deepar.ar.DeepARImageFormat;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.systemchannels.PlatformChannel;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;

import ai.deepar.ar.ARErrorType;
import ai.deepar.ar.AREventListener;
import ai.deepar.ar.CameraResolutionPreset;
import ai.deepar.ar.DeepAR;


class DeepArView  extends ActivityCompat implements MethodChannel.MethodCallHandler, ActivityCompat.OnRequestPermissionsResultCallback, PlatformView, AREventListener {
    private Context context;
    private DeepAR deepAR;
    private int cameraSelector= CameraSelector.LENS_FACING_FRONT;
    SurfaceView previewView;
    VideoCapture videoCapture;
    ImageAnalysis imageAnalysis;
    private static final int NUMBER_OF_BUFFERS=2;
    private ByteBuffer[] buffers;
    private int currentBuffer = 0;
    ProcessCameraProvider cameraProvider;
    private ListenableFuture<ProcessCameraProvider> CameraProvider;



    DeepArView(@NonNull Context context, int id, Object args, BinaryMessenger messenger){
        this.context=context;
        SetPreviewView();
        checkPermissions();
        new MethodChannel(messenger, "camerachannel").setMethodCallHandler(this);
        deepAR= new DeepAR(context);
        deepAR.setLicenseKey("f3826e4a6b3cc71ac441d5cea16bb6c962e6bd85b767e1867e1950434a9e752058245fc69ebf1fc7");
        deepAR.initialize(context,this);

    }

    @Override
    public void onMethodCall(@NonNull MethodCall methodCall, @NonNull MethodChannel.Result result) {
        if(methodCall.method.equals("flipcamera")){
            if(cameraSelector==CameraSelector.LENS_FACING_BACK){
                cameraSelector=CameraSelector.LENS_FACING_FRONT;
            }
            else{
                cameraSelector=CameraSelector.LENS_FACING_BACK;
            }
            // starting camerax to flip the camera
            startCameraX( cameraProvider);
        }

        else{
            System.out.println("noting ye");
        }
    }

    void InitializeView(){

        CameraProvider= ProcessCameraProvider.getInstance(context);
        CameraProvider.addListener(()->{
            try{
                cameraProvider=CameraProvider.get();
                startCameraX(cameraProvider);
            }
            catch (InterruptedException ex){

            }
            catch (ExecutionException ex){

            }
        },getMainExecutor(context));

    }
    //start the camera x

    private void startCameraX(ProcessCameraProvider cameraProvider){
        cameraProvider.unbindAll();
        //image selector use cases
        CameraSelector selector=new CameraSelector.Builder()
                .requireLensFacing(cameraSelector)
                .build();

        buffers = new ByteBuffer[NUMBER_OF_BUFFERS];
        int width=previewView.getWidth();
        int height=previewView.getHeight();
        for (int i = 0; i < NUMBER_OF_BUFFERS; i++) {
            buffers[i] = ByteBuffer.allocateDirect(width * height * 3);
            buffers[i].order(ByteOrder.nativeOrder());
            buffers[i].position(0);
        }

        imageAnalysis =
                new ImageAnalysis.Builder()
                        // enable the following line if RGBA output is needed.
                        .setTargetRotation(Surface.ROTATION_90)
                        .setTargetResolution(new Size(previewView.getWidth(), previewView.getHeight()))
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build();


        //image analysis callback analyzer
        imageAnalysis.setAnalyzer(getMainExecutor(context), new ImageAnalysis.Analyzer() {
            @Override
            public void analyze(@NonNull ImageProxy image) {

                byte[] byteData;
                ByteBuffer yBuffer = image.getPlanes()[0].getBuffer();
                ByteBuffer uBuffer = image.getPlanes()[1].getBuffer();
                ByteBuffer vBuffer = image.getPlanes()[2].getBuffer();

                int ySize = yBuffer.remaining();
                int uSize = uBuffer.remaining();
                int vSize = vBuffer.remaining();

                byteData = new byte[ySize + uSize + vSize];
                yBuffer.get(byteData, 0, ySize);
                vBuffer.get(byteData, ySize, vSize);
                uBuffer.get(byteData, ySize + vSize, uSize);

                buffers[currentBuffer].put(byteData);
                buffers[currentBuffer].position(0);
                if (deepAR != null) {
                    deepAR.receiveFrame(buffers[currentBuffer],
                            image.getWidth(), image.getHeight(),
                            image.getImageInfo().getRotationDegrees(),
                            cameraSelector == CameraSelector.LENS_FACING_FRONT,
                            DeepARImageFormat.YUV_420_888,
                            image.getPlanes()[1].getPixelStride()
                    );
                }
                currentBuffer = (currentBuffer + 1) % NUMBER_OF_BUFFERS;
                image.close();

            }
        });

        //deepar pass it view into a previewview holder to buffer it analyze frames
        deepAR.setRenderSurface(previewView.getHolder().getSurface(),previewView.getWidth(),previewView.getHeight());
        cameraProvider.bindToLifecycle((LifecycleOwner)context,selector,imageAnalysis);


    }



    private void recordVideo(){
        if(videoCapture!=null){

        }
    }
    //set and create previewview for the camera x{height and width to match parent}
    void SetPreviewView(){
        previewView=new SurfaceView(context);
        // previewView.setLayoutParams(new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
    }


    //override interphase or callback
    @Nullable
    @Override
    public View getView() {

        return  previewView;
    }

    @Override
    public void onFlutterViewAttached(@NonNull View flutterView) {
        PlatformView.super.onFlutterViewAttached(flutterView);
    }




    void checkPermissions(){
        if(ActivityCompat.checkSelfPermission(context, Manifest.permission.CAMERA)== PackageManager.PERMISSION_DENIED){
            requestPermissions((Activity) context,new String[]{Manifest.permission.CAMERA},1);

        }
        else{
            InitializeView();

        }
    }





    @Override
    public void onFlutterViewDetached() {
        PlatformView.super.onFlutterViewDetached();
    }

    @Override
    public void dispose() {

    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        if(requestCode==1&&grantResults.length>0){
            for(int x=0; x<grantResults.length; x++){
                if(grantResults[x]!=PackageManager.PERMISSION_GRANTED){
                    Toast.makeText(context,"Permission Not Yet Granted",Toast.LENGTH_LONG).show();
                    return;
                }
            }
            InitializeView();

        }
    }



    //start of deepar plugin
    @Override
    public void screenshotTaken(Bitmap bitmap) {

    }

    @Override
    public void videoRecordingStarted() {

    }

    @Override
    public void videoRecordingFinished() {

    }

    @Override
    public void videoRecordingFailed() {

    }

    @Override
    public void videoRecordingPrepared() {

    }

    @Override
    public void shutdownFinished() {

    }

    @Override
    public void initialized() {

    }

    @Override
    public void faceVisibilityChanged(boolean b) {

    }

    @Override
    public void imageVisibilityChanged(String s, boolean b) {

    }

    @Override
    public void frameAvailable(Image image) {

    }

    @Override
    public void error(ARErrorType arErrorType, String s) {

    }

    @Override
    public void effectSwitched(String s) {

    }



    //end of deepar
}
