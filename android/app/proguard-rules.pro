# The C++ worker looks up these classes and methods by exact JNI name.
# R8 cannot see those references and otherwise renames/removes them.
-keep class io.github.ialexpovad.povad.PovadUsbHost { *; }
-keep class io.github.ialexpovad.povad.UsbSession { *; }
-keep class * implements io.github.ialexpovad.povad.UsbSession { *; }
-keep class io.github.ialexpovad.povad.PovadBleHost { *; }
-keep class io.github.ialexpovad.povad.BleSession { *; }
