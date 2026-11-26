#!/bin/bash
# بناء APK «منسّق الشعر» — الإصدار 1.1: جسر حفظ الصورة + نسخ بلا جدول (منع العكس والمربعات)
set -e
exec > >(tee -a "$HOME/workspace/poem-formatter/android/build.log") 2>&1
echo "=== BUILD5 (APK 1.2) START $(date) ==="

PROJ="$HOME/workspace/poem-formatter/android"
SRC="$HOME/workspace/poem-formatter"
SDK="$HOME/android-sdk"
export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(which java)")")")"
AJAR="$SDK/platforms/android-34/android.jar"
BT="$SDK/build-tools/34.0.0"
ls -la "$AJAR" "$BT/aapt2"

cd "$PROJ"
mkdir -p src/com/hilalsameer/munassiq res/values res/mipmap-mdpi res/mipmap-hdpi res/mipmap-xhdpi res/mipmap-xxhdpi res/mipmap-xxxhdpi assets/www gen classes dex
cp "$SRC/index.html" "$SRC/manifest.webmanifest" "$SRC/sw.js" "$SRC/icon.svg" assets/www/

cat > AndroidManifest.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.hilalsameer.munassiq"
    android:versionCode="3" android:versionName="1.2">
  <uses-sdk android:minSdkVersion="24" android:targetSdkVersion="34"/>
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>
  <application android:label="@string/app_name" android:icon="@mipmap/ic_launcher"
      android:theme="@android:style/Theme.Material.NoActionBar" android:allowBackup="true">
    <activity android:name=".MainActivity" android:exported="true"
        android:configChanges="orientation|screenSize|keyboardHidden">
      <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
      </intent-filter>
    </activity>
  </application>
</manifest>
EOF

cat > res/values/strings.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources><string name="app_name">منسّق الشعر</string></resources>
EOF

cat > src/com/hilalsameer/munassiq/MainActivity.java <<'EOF'
package com.hilalsameer.munassiq;
import android.app.Activity;
import android.content.ContentValues;
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
    w.setWebViewClient(new WebViewClient());
    w.addJavascriptInterface(new SaveBridge(), "AndroidSave");
    setContentView(w);
    w.loadUrl("file:///android_asset/www/index.html");
  }
  @Override public void onBackPressed(){
    if (w != null && w.canGoBack()) w.goBack(); else super.onBackPressed();
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
}
EOF

"$BT/aapt2" compile --dir res -o res.zip
"$BT/aapt2" link -o unsigned.apk -I "$AJAR" --manifest AndroidManifest.xml -A assets res.zip
javac -encoding UTF-8 -cp "$AJAR" -d classes src/com/hilalsameer/munassiq/MainActivity.java
"$BT/d8" --min-api 24 --lib "$AJAR" --output dex $(find classes -name '*.class')
jar uf unsigned.apk -C dex classes.dex
"$BT/zipalign" -f 4 unsigned.apk aligned.apk

KSPASS="$(cat keystore-password.txt)"
"$BT/apksigner" sign --ks munassiq-release.keystore --ks-pass "pass:$KSPASS" --key-pass "pass:$KSPASS" \
  --out "$SRC/munassiq-shir.apk" aligned.apk
"$BT/apksigner" verify --print-certs "$SRC/munassiq-shir.apk" | head -3
"$BT/aapt2" dump badging "$SRC/munassiq-shir.apk" 2>/dev/null | grep -E "package:|application-label:" | head -2
ls -la "$SRC/munassiq-shir.apk"
sha256sum "$SRC/munassiq-shir.apk"
echo "=== BUILD5 OK ==="
