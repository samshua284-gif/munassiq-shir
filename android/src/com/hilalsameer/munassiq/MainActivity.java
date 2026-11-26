package com.hilalsameer.munassiq;
import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Base64;
import android.webkit.JavascriptInterface;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;
import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;

public class MainActivity extends Activity {
  private WebView w;
  @Override protected void onCreate(Bundle s){
    super.onCreate(s);
    w = new WebView(this);
    WebSettings st = w.getSettings();
    st.setJavaScriptEnabled(true);
    st.setDomStorageEnabled(true);
    w.addJavascriptInterface(new SaveBridge(), "AndroidSave");
    w.addJavascriptInterface(new RepoBridge(), "AndroidRepo");
    w.setWebViewClient(new WebViewClient());
    setContentView(w);
    w.loadUrl("file:///android_asset/www/index.html");
  }

  public class SaveBridge {
    @JavascriptInterface public void savePng(final String dataUrl){
      try {
        String b64 = dataUrl.substring(dataUrl.indexOf(",") + 1);
        byte[] bytes = Base64.decode(b64, Base64.DEFAULT);
        String name = "qasida-" + System.currentTimeMillis() + ".png";
        if (Build.VERSION.SDK_INT >= 29) {
          ContentValues v = new ContentValues();
          v.put(MediaStore.Images.Media.DISPLAY_NAME, name);
          v.put(MediaStore.Images.Media.MIME_TYPE, "image/png");
          v.put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/Munassiq");
          Uri uri = getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, v);
          OutputStream out = getContentResolver().openOutputStream(uri);
          out.write(bytes); out.close();
        } else {
          File dir = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "Munassiq");
          dir.mkdirs();
          File f = new File(dir, name);
          FileOutputStream out = new FileOutputStream(f);
          out.write(bytes); out.close();
          MediaScannerConnection.scanFile(MainActivity.this, new String[]{ f.getAbsolutePath() }, new String[]{ "image/png" }, null);
        }
        toast("حُفظت الصورة في الاستيديو");
      } catch (Exception e) {
        toast("تعذّر حفظ الصورة");
      }
    }
    private void toast(final String msg){
      runOnUiThread(new Runnable(){ public void run(){ Toast.makeText(MainActivity.this, msg, Toast.LENGTH_LONG).show(); } });
    }
  }

  public class RepoBridge {
    static final String URL = "https://github.com/samshua284-gif/munassiq-shir";
    @JavascriptInterface public void open(){
      try { startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(URL))); }
      catch (Exception e) { toast2("تعذّر فتح المتصفح"); }
    }
    @JavascriptInterface public void copy(){
      ClipboardManager cm = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
      cm.setPrimaryClip(ClipData.newPlainText("repo", URL));
      toast2("نُسخ رابط المستودع — الصقه أين تشاء");
    }
    private void toast2(final String msg){
      runOnUiThread(new Runnable(){ public void run(){ Toast.makeText(MainActivity.this, msg, Toast.LENGTH_LONG).show(); } });
    }
  }
  @Override public void onBackPressed(){
    if (w != null && w.canGoBack()) w.goBack(); else super.onBackPressed();
  }
}
