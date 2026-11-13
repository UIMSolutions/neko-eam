# kotlinx.serialization: keep generated serializers of the DTOs
-keepattributes *Annotation*, InnerClasses
-keep,includedescriptorclasses class neko.eam.mobile.data.**$$serializer { *; }
-keepclassmembers class neko.eam.mobile.data.** { *** Companion; }
-keepclasseswithmembers class neko.eam.mobile.data.** { kotlinx.serialization.KSerializer serializer(...); }
