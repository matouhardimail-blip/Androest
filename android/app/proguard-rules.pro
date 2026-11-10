# قواعد R8 لحظة تفعيل minifyEnabled true
# جسر JNI يصل إلى هذه الأصناف بالاسم، لذا يجب إبقاؤها.
-keep class com.write4me.llama_flutter_android.** { *; }

-keep class kotlin.jvm.functions.Function1
-keepclassmembers class * implements kotlin.jvm.functions.Function1 {
    public java.lang.Object invoke(java.lang.Object);
}

-keepclasseswithmembernames class * {
    native <methods>;
}
