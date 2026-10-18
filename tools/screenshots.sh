#!/bin/bash
# CI 上のシミュレータで各画面のスクリーンショットを撮る（macOS 上で実行）
set -euo pipefail
APP="build/Build/Products/Debug-iphonesimulator/ITPass.app"
BUNDLE="com.xelaods.itpass"
OUT="shots"
mkdir -p "$OUT"

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
c=[x for k,v in d.items() if "iOS" in k for x in v if x["name"].startswith("iPhone") and "Pro" in x["name"] and "Max" not in x["name"]]
c=c or [x for k,v in d.items() if "iOS" in k for x in v if x["name"].startswith("iPhone")]
print(c[-1]["udid"])')
echo "device: $UDID"
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 || true
xcrun simctl install "$UDID" "$APP"

shot() {
  local name="$1"; local wait="$2"; shift 2
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BUNDLE" "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null
  echo "shot $name"
}

shot 01-onboarding 5
shot 02-home 5 -demo
shot 03-learn 5 -demo -demoTab learn
shot 04-exam 5 -demo -demoTab exam
shot 05-records 5 -demo -demoTab records
shot 05b-records-bottom 6 -demo -demoTab records -demoScroll bottom
shot 03b-learn-bottom 6 -demo -demoTab learn -demoScroll bottom
shot 06-quiz 6 -demo -demoOpen quiz
shot 06b-quiz-answered 7 -demo -demoOpen quizAnswered
shot 07-cards 6 -demo -demoOpen cards
shot 08-exam-session 6 -demo -demoOpen exam
shot 09-time-attack 9 -demo -demoOpen timeAttack
shot 10-survival 9 -demo -demoOpen survival
shot 11-true-false 9 -demo -demoOpen trueFalse
shot 12-match 9 -demo -demoOpen match
shot 15-exam-result 9 -demo -demoOpen examDone
shot 16-time-attack-over 72 -demo -demoOpen timeAttack
xcrun simctl ui "$UDID" appearance dark
shot 13-home-dark 5 -demo
shot 14-quiz-dark 6 -demo -demoOpen quiz
ls -la "$OUT"
