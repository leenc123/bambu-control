@echo off
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=
pushd D:\python_project\bambu-control\bambu_lab_app
flutter precache --android
popd
