#!/bin/bash
# بناء APK «منسّق الشعر» — غلاف WebView حول ملفات المشروع نفسها، بتوقيع محلي
set -e
exec > >(tee -a "$HOME/workspace/poem-formatter/android/build.log") 2>&1
echo "=== BUILD START $(date) ==="

PROJ="$HOME/workspace/poem-formatter/android"
SRC="$HOME/workspace/poem-formatter"
SDK="$HOME/android-sdk"
mkdir -p "$PROJ" "$SDK"

# 1) جافا
if ! command -v java >/dev/null 2>&1; then
  echo "--- installing JDK via apt"
  apt-get update -qq && apt-get install -y -qq openjdk-17-jdk-headless || true
fi
if ! command -v java >/dev/null 2>&1; then
  echo "--- apt failed; downloading Temurin JDK"
  cd /tmp
  curl -L -o jdk.tar.gz "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse"
  mkdir -p "$HOME/jdk" && tar xzf jdk.tar.gz -C "$HOME/jdk" --strip-components=1
  export PATH="$HOME/jdk/bin:$PATH"
fi
export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(which java)")")")"
echo "JAVA_HOME=$JAVA_HOME"
java -version

# 2) أدوات أندرويد
if [ ! -x "$SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
  echo "--- downloading cmdline tools"
  cd /tmp
  curl -L -o cmdtools.zip "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
  mkdir -p "$SDK/cmdline-tools/latest"
  cd "$SDK/cmdline-tools/latest" && unzip -qo /tmp/cmdtools.zip && mv cmdline-tools/* . && rmdir cmdline-tools
fi
export PATH="$SDK/cmdline-tools/latest/bin:$SDK/build-tools/34.0.0:$PATH"
yes | sdkmanager --sdk_root="$SDK" --licenses >/dev/null 2>&1 || true
[ -f "$SDK/platforms/android-34/android.jar" ] || sdkmanager --sdk_root="$SDK" "platforms;android-34" "build-tools;34.0.0"
AJAR="$SDK/platforms/android-34/android.jar"
BT="$SDK/build-tools/34.0.0"
ls -la "$AJAR" "$BT/aapt2" "$BT/d8" "$BT/zipalign" "$BT/apksigner"

# 3) هيكل المشروع
cd "$PROJ"
mkdir -p src/com/hilalsameer/munassiq res/values res/mipmap-mdpi res/mipmap-hdpi res/mipmap-xhdpi res/mipmap-xxhdpi res/mipmap-xxxhdpi assets/www gen classes dex
cp "$SRC/index.html" "$SRC/manifest.webmanifest" "$SRC/sw.js" "$SRC/icon.svg" assets/www/

cat > AndroidManifest.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.hilalsameer.munassiq"
    android:versionCode="42" android:versionName="3.15">
  <uses-sdk android:minSdkVersion="24" android:targetSdkVersion="34"/>
  <uses-permission android:name="android.permission.INTERNET"/>
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
EOF

# 4) أيقونة المشغّل مرسومة بـ PIL: عمودان ذهبيان وموجة تطويل على سواد
python3 - <<'PYEOF'
from PIL import Image, ImageDraw
S = 576
img = Image.new("RGB", (S, S), (15, 20, 25))
d = ImageDraw.Draw(img)
gold = (201, 162, 39); gold2 = (230, 198, 92)
# عمودان
for x0 in (150, 330):
    d.rounded_rectangle([x0, 110, x0 + 96, 466], radius=26, fill=gold)
# موجة التطويل بينهما وأسفلهما
import math
pts = [(x, 500 + 16 * math.sin(x / 46.0)) for x in range(120, 457, 6)]
d.line(pts, fill=gold2, width=13)
img.save("/tmp/icon-576.png")
for name, sz in [("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)]:
    img.resize((sz, sz), Image.LANCZOS).save(f"/home/hatch/workspace/poem-formatter/android/res/mipmap-{name}/ic_launcher.png")
print("icon ok")
PYEOF

# 5) البناء اليدوي: aapt2 ثم javac ثم d8 ثم محاذاة وتوقيع
"$BT/aapt2" compile --dir res -o res.zip
"$BT/aapt2" link -o unsigned.apk -I "$AJAR" --manifest AndroidManifest.xml -A assets res.zip
javac -encoding UTF-8 -cp "$AJAR" -d classes src/com/hilalsameer/munassiq/MainActivity.java
"$BT/d8" --output dex $(find classes -name '*.class')
jar uf unsigned.apk -C dex classes.dex
"$BT/zipalign" -f 4 unsigned.apk aligned.apk

# 6) مفتاح التوقيع — يُولّد مرة واحدة ويبقى في مجلد المشروع لتوقيع كل تحديث قادم
if [ ! -f munassiq-release.keystore ]; then
  KSPASS="$(openssl rand -hex 12)"
  echo -n "$KSPASS" > keystore-password.txt
  keytool -genkeypair -keystore munassiq-release.keystore -alias munassiq \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$KSPASS" -keypass "$KSPASS" \
    -dname "CN=Hilal Sameer, O=munassiq-shir"
fi
KSPASS="$(cat keystore-password.txt)"
"$BT/apksigner" sign --ks munassiq-release.keystore --ks-pass "pass:$KSPASS" --key-pass "pass:$KSPASS" \
  --out "$SRC/munassiq-shir.apk" aligned.apk
"$BT/apksigner" verify --print-certs "$SRC/munassiq-shir.apk" | head -3
ls -la "$SRC/munassiq-shir.apk"
sha256sum "$SRC/munassiq-shir.apk"
echo "=== BUILD OK ==="
