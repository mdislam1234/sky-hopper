# WorkManager 2.7.0 uses Room reflection to construct WorkDatabase_Impl.
# Room 2.2.5 keeps generated database class names but does not keep the
# no-argument constructor that Room.databaseBuilder() reflects on.
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
