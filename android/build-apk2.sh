#!/bin/bash
# بناء APK «منسّق الشعر» — المحاولة الثانية: تنزيل حزم SDK بـ curl مباشرة (sdkmanager تعثّر عند الوكيل)
set -e
exec > >(tee -a "$HOME/workspace/poem-formatter/android/build.log") 2>&1
echo "=== BUILD2 START $(date) ==="

PROJ="$HOME/workspace/poem-formatter/android"
SRC="$HOME/workspace/poem-formatter"
SDK="$HOME/android-sdk"
mkdir -p "$PROJ" "$SDK/platforms" "$SDK/build-tools"
export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(which java)")")")"
echo "JAVA_HOME=$JAVA_HOME"

# 1) حزم SDK بـ curl
cd /tmp
[ -f platform.zip ] || curl -L -o platform.zip "https://dl.google.com/android/repository/platform-34-ext7_r03.zip"
[ -f btools.zip ] || curl -L -o btools.zip "https://dl.google.com/android/repository/build-tools_r34-linux.zip"
rm -rf platx btx && mkdir platx btx
unzip -qo platform.zip -d platx
unzip -qo btools.zip -d btx
PF="$(find platx -maxdepth 2 -name android.jar -printf '%h\n' | head -1)"
BF="$(find btx -maxdepth 2 -name aapt2 -printf '%h\n' | head -1)"
echo "platform dir: $PF ; build-tools dir: $BF"
rm -rf "$SDK/platforms/android-34" "$SDK/build-tools/34.0.0"
mv "$PF" "$SDK/platforms/android-34"
mv "$BF" "$SDK/build-tools/34.0.0"
chmod -R +x "$SDK/build-tools/34.0.0"
AJAR="$SDK/platforms/android-34/android.jar"
BT="$SDK/build-tools/34.0.0"
ls -la "$AJAR" "$BT/aapt2" "$BT/d8" "$BT/zipalign" "$BT/apksigner"

# 2) هيكل المشروع
cd "$PROJ"
mkdir -p src/com/hilalsameer/munassiq res/values res/mipmap-mdpi res/mipmap-hdpi res/mipmap-xhdpi res/mipmap-xxhdpi res/mipmap-xxxhdpi assets/www gen classes dex
cp "$SRC/index.html" "$SRC/manifest.webmanifest" "$SRC/sw.js" "$SRC/icon.svg" assets/www/

cat > AndroidManifest.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.hilalsameer.munassiq"
    android:versionCode="1" android:versionName="1.0">
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
import android.os.Bundle;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

public class MainActivity extends Activity {
  private WebView w;
  @Override protected void onCreate(Bundle s){
    super.onCreate(s);
    w = new WebView(this);
    WebSettings st = w.getSettings();
    st.setJavaScriptEnabled(true);
    st.setDomStorageEnabled(true);
    w.setWebViewClient(new WebViewClient());
    setContentView(w);
    w.loadUrl("file:///android_asset/www/index.html");
  }
  @Override public void onBackPressed(){
    if (w != null && w.canGoBack()) w.goBack(); else super.onBackPressed();
  }
}
EOF

# 3) أيقونة المشغّل
python3 - <<'PYEOF'
from PIL import Image, ImageDraw
import math
S = 576
img = Image.new("RGB", (S, S), (15, 20, 25))
d = ImageDraw.Draw(img)
gold = (201, 162, 39); gold2 = (230, 198, 92)
for x0 in (150, 330):
    d.rounded_rectangle([x0, 110, x0 + 96, 466], radius=26, fill=gold)
pts = [(x, 500 + 16 * math.sin(x / 46.0)) for x in range(120, 457, 6)]
d.line(pts, fill=gold2, width=13)
for name, sz in [("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)]:
    img.resize((sz, sz), Image.LANCZOS).save(f"/home/hatch/workspace/poem-formatter/android/res/mipmap-{name}/ic_launcher.png")
print("icon ok")
PYEOF

# 4) البناء اليدوي
"$BT/aapt2" compile --dir res -o res.zip
"$BT/aapt2" link -o unsigned.apk -I "$AJAR" --manifest AndroidManifest.xml -A assets res.zip
javac -cp "$AJAR" -d classes src/com/hilalsameer/munassiq/MainActivity.java
"$BT/d8" --output dex $(find classes -name '*.class')
jar uf unsigned.apk -C dex classes.dex
"$BT/zipalign" -f 4 unsigned.apk aligned.apk

# 5) التوقيع
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
echo "=== BUILD2 OK ==="
