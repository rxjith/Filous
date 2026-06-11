package com.filous.budgettracker

import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "filous/storage_access"
    private val requestPickDirectory = 4101
    private val requestSaveBackupFile = 4102
    private val requestPickRestoreFile = 4103

    private var pendingResult: MethodChannel.Result? = null
    private var pendingBackupContent: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickBackupDirectory" -> openBackupDirectoryPicker(result)
                "writeBackupFile" -> writeBackupFile(call, result)
                "saveBackupFile" -> saveBackupFile(call, result)
                "pickRestoreFile" -> pickRestoreFile(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        val result = pendingResult ?: return
        val uri = data?.data

        if (resultCode != RESULT_OK || uri == null) {
            result.success(null)
            clearPendingState()
            return
        }

        when (requestCode) {
            requestPickDirectory -> {
                tryTakePersistablePermissions(uri)
                result.success(uri.toString())
            }

            requestSaveBackupFile -> {
                try {
                    val content = pendingBackupContent
                    if (content == null) {
                        result.error("write_failed", "Backup content was missing.", null)
                    } else {
                        contentResolver.openOutputStream(uri, "wt")?.bufferedWriter()?.use {
                            it.write(content)
                        } ?: throw IllegalStateException("Could not open selected file for writing.")
                        result.success(uri.toString())
                    }
                } catch (error: Exception) {
                    result.error("write_failed", error.message, null)
                }
            }

            requestPickRestoreFile -> {
                try {
                    val content = contentResolver.openInputStream(uri)?.bufferedReader()?.use {
                        it.readText()
                    } ?: throw IllegalStateException("Could not open selected file.")
                    result.success(content)
                } catch (error: Exception) {
                    result.error("restore_read_failed", error.message, null)
                }
            }

            else -> result.notImplemented()
        }

        clearPendingState()
    }

    private fun openBackupDirectoryPicker(result: MethodChannel.Result) {
        if (!ensureNoPendingResult(result)) return

        pendingResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        startActivityForResult(intent, requestPickDirectory)
    }

    private fun saveBackupFile(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureNoPendingResult(result)) return

        val fileName = call.argument<String>("fileName")
        val content = call.argument<String>("content")
        if (fileName.isNullOrBlank() || content == null) {
            result.error("invalid_args", "fileName and content are required.", null)
            return
        }

        pendingResult = result
        pendingBackupContent = content
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_TITLE, fileName)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        }
        startActivityForResult(intent, requestSaveBackupFile)
    }

    private fun pickRestoreFile(result: MethodChannel.Result) {
        if (!ensureNoPendingResult(result)) return

        pendingResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain", "application/octet-stream"))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivityForResult(intent, requestPickRestoreFile)
    }

    private fun writeBackupFile(call: MethodCall, result: MethodChannel.Result) {
        val treeUriString = call.argument<String>("treeUri")
        val fileName = call.argument<String>("fileName")
        val content = call.argument<String>("content")

        if (treeUriString.isNullOrBlank() || fileName.isNullOrBlank() || content == null) {
            result.error("invalid_args", "treeUri, fileName and content are required.", null)
            return
        }

        try {
            val treeUri = Uri.parse(treeUriString)
            val pickedDir = DocumentFile.fromTreeUri(this, treeUri)
            if (pickedDir == null || !pickedDir.canWrite()) {
                result.error("directory_unavailable", "Selected backup folder is not writable.", null)
                return
            }

            pickedDir.findFile(fileName)?.delete()
            val outputFile = pickedDir.createFile("application/json", fileName)
            if (outputFile == null) {
                result.error("file_create_failed", "Could not create backup file.", null)
                return
            }

            contentResolver.openOutputStream(outputFile.uri, "wt")?.bufferedWriter()?.use {
                it.write(content)
            } ?: throw IllegalStateException("Could not open backup file for writing.")

            result.success(outputFile.uri.toString())
        } catch (error: Exception) {
            result.error("write_failed", error.message, null)
        }
    }

    private fun ensureNoPendingResult(result: MethodChannel.Result): Boolean {
        if (pendingResult != null) {
            result.error("busy", "Another storage action is already in progress.", null)
            return false
        }
        return true
    }

    private fun tryTakePersistablePermissions(uri: Uri) {
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        } catch (_: SecurityException) {
            // Some providers do not support persistable permission grants.
        }
    }

    private fun clearPendingState() {
        pendingResult = null
        pendingBackupContent = null
    }
}
