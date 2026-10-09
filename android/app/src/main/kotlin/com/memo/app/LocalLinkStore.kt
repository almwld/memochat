package com.memo.app

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/** Durable, app-private history and outbox for the isolated local peer channel. */
class LocalLinkStore(context: Context) : SQLiteOpenHelper(
    context.applicationContext,
    "memochat_local_link.db",
    null,
    1
) {
    data class Message(
        val id: String,
        val text: String,
        val incoming: Boolean,
        val status: String,
        val createdAt: Long
    )

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """CREATE TABLE messages (
                id TEXT PRIMARY KEY NOT NULL,
                body TEXT NOT NULL,
                incoming INTEGER NOT NULL,
                status TEXT NOT NULL,
                created_at INTEGER NOT NULL
            )"""
        )
        db.execSQL("CREATE INDEX messages_outbox ON messages(incoming, status, created_at)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit

    @Synchronized
    fun saveOutgoing(id: String, body: String) {
        val values = ContentValues().apply {
            put("id", id)
            put("body", body)
            put("incoming", 0)
            put("status", "queued")
            put("created_at", System.currentTimeMillis())
        }
        writableDatabase.insertWithOnConflict("messages", null, values, SQLiteDatabase.CONFLICT_IGNORE)
    }

    @Synchronized
    fun pendingOutgoing(): List<Message> {
        val result = mutableListOf<Message>()
        readableDatabase.query(
            "messages",
            arrayOf("id", "body", "incoming", "status", "created_at"),
            "incoming = 0 AND status != ?",
            arrayOf("delivered"),
            null,
            null,
            "created_at ASC"
        ).use { cursor ->
            while (cursor.moveToNext()) {
                result.add(
                    Message(
                        id = cursor.getString(0),
                        text = cursor.getString(1),
                        incoming = cursor.getInt(2) != 0,
                        status = cursor.getString(3),
                        createdAt = cursor.getLong(4)
                    )
                )
            }
        }
        return result
    }

    @Synchronized
    fun markSending(id: String) = updateStatus(id, "sending")

    @Synchronized
    fun markQueued(id: String) = updateStatus(id, "queued")

    @Synchronized
    fun markDelivered(id: String) = updateStatus(id, "delivered")

    @Synchronized
    fun saveIncoming(id: String, body: String): Boolean {
        val values = ContentValues().apply {
            put("id", id)
            put("body", body)
            put("incoming", 1)
            put("status", "received")
            put("created_at", System.currentTimeMillis())
        }
        return writableDatabase.insertWithOnConflict(
            "messages", null, values, SQLiteDatabase.CONFLICT_IGNORE
        ) != -1L
    }

    @Synchronized
    fun history(): List<Map<String, Any?>> {
        val result = mutableListOf<Map<String, Any?>>()
        readableDatabase.query(
            "messages",
            arrayOf("id", "body", "incoming", "status", "created_at"),
            null,
            null,
            null,
            null,
            "created_at ASC"
        ).use { cursor ->
            while (cursor.moveToNext()) {
                val incoming = cursor.getInt(2) != 0
                result.add(
                    mapOf(
                        "id" to cursor.getString(0),
                        "text" to cursor.getString(1),
                        "incoming" to incoming,
                        "delivered" to (cursor.getString(3) == "delivered"),
                        "status" to cursor.getString(3),
                        "createdAt" to cursor.getLong(4)
                    )
                )
            }
        }
        return result
    }

    private fun updateStatus(id: String, status: String) {
        val values = ContentValues().apply { put("status", status) }
        writableDatabase.update("messages", values, "id = ?", arrayOf(id))
    }
}
