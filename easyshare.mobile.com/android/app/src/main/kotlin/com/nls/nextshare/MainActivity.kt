package com.nls.nextshare

import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "nextshare/downloads"
    private val platformChannelName = "nextshare/platform_files"
    private val folderPickerRequestCode = 7312
    private var pendingFolderResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "getAvailableBytes" -> {
                        val directory = Environment.getExternalStoragePublicDirectory(
                            Environment.DIRECTORY_DOWNLOADS
                        )
                        result.success(directory.usableSpace)
                    }
                    "saveToDownloads" -> {
                        val path = call.argument<String>("path")
                        val name = call.argument<String>("name")
                        val relativeDirectory = call.argument<String>("relativeDirectory")
                        if (path == null || name == null) {
                            result.error("ARG", "Missing path/name", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val saved = saveToDownloads(path, name, relativeDirectory)
                            if (saved == null) {
                                result.error("SAVE", "Failed to save", null)
                            } else {
                                result.success(saved)
                            }
                        } catch (e: Exception) {
                            result.error("SAVE", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, platformChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installedApps" -> {
                        try {
                            result.success(installedApps())
                        } catch (e: Exception) {
                            result.error("APPS", e.message, null)
                        }
                    }
                    "pickFolder" -> {
                        if (pendingFolderResult != null) {
                            result.error("BUSY", "A folder picker is already open", null)
                            return@setMethodCallHandler
                        }
                        pendingFolderResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
                            )
                        }
                        startActivityForResult(intent, folderPickerRequestCode)
                    }
                    "openPath" -> {
                        val path = call.argument<String>("path")
                        result.success(path != null && openPath(path))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != folderPickerRequestCode) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingFolderResult
        pendingFolderResult = null
        val treeUri = data?.data
        if (resultCode != RESULT_OK || treeUri == null) {
            result?.success(null)
            return
        }
        try {
            val flags = (data?.flags ?: 0) and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            contentResolver.takePersistableUriPermission(treeUri, flags)
        } catch (_: Exception) {
            // The temporary picker permission remains valid for this import.
        }
        Thread {
            try {
                val files = importDocumentTree(treeUri)
                runOnUiThread { result?.success(files) }
            } catch (error: Exception) {
                runOnUiThread {
                    result?.error(
                        "FOLDER",
                        error.message ?: "The selected folder could not be read",
                        null
                    )
                }
            }
        }.start()
    }

    private fun importDocumentTree(treeUri: Uri): List<Map<String, Any>> {
        val treeDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
        val rootDocumentUri = DocumentsContract.buildDocumentUriUsingTree(
            treeUri,
            treeDocumentId
        )
        val rootName = queryDocumentName(rootDocumentUri) ?: "Shared folder"
        val safeRootName = sanitizeName(rootName)
        val outputRoot = File(cacheDir, "nextshare_folders/${System.currentTimeMillis()}")
        outputRoot.mkdirs()
        val files = mutableListOf<Map<String, Any>>()
        importDocument(
            treeUri = treeUri,
            documentUri = rootDocumentUri,
            relativePath = safeRootName,
            outputRoot = outputRoot,
            output = files
        )
        return files
    }

    private fun importDocument(
        treeUri: Uri,
        documentUri: Uri,
        relativePath: String,
        outputRoot: File,
        output: MutableList<Map<String, Any>>
    ) {
        val mimeType = queryDocumentMimeType(documentUri)
        if (mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
            val documentId = DocumentsContract.getDocumentId(documentUri)
            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
                treeUri,
                documentId
            )
            val projection = arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME
            )
            contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
                val idIndex = cursor.getColumnIndexOrThrow(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID
                )
                val nameIndex = cursor.getColumnIndexOrThrow(
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME
                )
                while (cursor.moveToNext()) {
                    val childId = cursor.getString(idIndex)
                    val childName = sanitizeName(cursor.getString(nameIndex) ?: "file")
                    val childUri = DocumentsContract.buildDocumentUriUsingTree(
                        treeUri,
                        childId
                    )
                    importDocument(
                        treeUri,
                        childUri,
                        "$relativePath/$childName",
                        outputRoot,
                        output
                    )
                }
            }
            return
        }

        val destination = File(outputRoot, relativePath)
        destination.parentFile?.mkdirs()
        contentResolver.openInputStream(documentUri)?.use { input ->
            FileOutputStream(destination).use { outputStream ->
                input.copyTo(outputStream)
            }
        } ?: throw IllegalStateException("Cannot open $relativePath")
        output.add(
            mapOf(
                "path" to destination.absolutePath,
                "relativePath" to relativePath,
                "size" to destination.length()
            )
        )
    }

    private fun queryDocumentName(uri: Uri): String? {
        return queryDocumentValue(uri, DocumentsContract.Document.COLUMN_DISPLAY_NAME)
    }

    private fun queryDocumentMimeType(uri: Uri): String? {
        return queryDocumentValue(uri, DocumentsContract.Document.COLUMN_MIME_TYPE)
    }

    private fun queryDocumentValue(uri: Uri, column: String): String? {
        contentResolver.query(uri, arrayOf(column), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst() && !cursor.isNull(0)) {
                return cursor.getString(0)
            }
        }
        return null
    }

    private fun sanitizeName(name: String): String {
        val sanitized = name.replace(Regex("[\\\\/:*?\"<>|\\u0000-\\u001F]"), "_").trim()
        return sanitized.ifBlank { "file" }
    }

    private fun saveToDownloads(
        path: String,
        name: String,
        relativeDirectory: String?
    ): String? {
        val inputFile = File(path)
        if (!inputFile.exists()) return null

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, "application/octet-stream")
                put(MediaStore.Downloads.IS_PENDING, 1)
                val cleanDirectory = relativeDirectory
                    ?.replace('\\', '/')
                    ?.split('/')
                    ?.filter { it.isNotBlank() && it != "." && it != ".." }
                    ?.joinToString("/")
                put(
                    MediaStore.Downloads.RELATIVE_PATH,
                    if (cleanDirectory.isNullOrBlank()) {
                        Environment.DIRECTORY_DOWNLOADS
                    } else {
                        "${Environment.DIRECTORY_DOWNLOADS}/$cleanDirectory"
                    }
                )
            }
            val resolver = applicationContext.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: return null
            resolver.openOutputStream(uri)?.use { out ->
                FileInputStream(inputFile).use { input ->
                    input.copyTo(out)
                }
            } ?: return null

            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            uri.toString()
        } else {
            val downloads = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS
            )
            val cleanDirectory = relativeDirectory
                ?.replace('\\', '/')
                ?.split('/')
                ?.filter { it.isNotBlank() && it != "." && it != ".." }
                ?.joinToString(File.separator)
            val dir = if (cleanDirectory.isNullOrBlank()) {
                downloads
            } else {
                File(downloads, cleanDirectory)
            }
            if (!dir.exists()) dir.mkdirs()
            var outFile = File(dir, name)
            if (outFile.exists()) {
                val extensionIndex = name.lastIndexOf('.')
                val base = if (extensionIndex > 0) name.substring(0, extensionIndex) else name
                val extension = if (extensionIndex > 0) name.substring(extensionIndex) else ""
                var index = 1
                while (outFile.exists()) {
                    outFile = File(dir, "$base ($index)$extension")
                    index++
                }
            }
            FileInputStream(inputFile).use { input ->
                FileOutputStream(outFile).use { out ->
                    input.copyTo(out)
                }
            }
            outFile.absolutePath
        }
    }

    private fun installedApps(): List<Map<String, Any>> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolveInfos = packageManager.queryIntentActivities(intent, 0)
        val seen = mutableSetOf<String>()
        return resolveInfos.mapNotNull { resolveInfo ->
            val info = resolveInfo.activityInfo.applicationInfo
            if (!seen.add(info.packageName)) return@mapNotNull null
            val apk = File(info.sourceDir)
            if (!apk.exists()) return@mapNotNull null
            val iconBytes = try {
                val drawable = packageManager.getApplicationIcon(info)
                val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96
                val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96
                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
                ByteArrayOutputStream().use { output ->
                    bitmap.compress(Bitmap.CompressFormat.PNG, 90, output)
                    output.toByteArray()
                }
            } catch (_: Exception) {
                null
            }
            mutableMapOf<String, Any>(
                "name" to packageManager.getApplicationLabel(info).toString(),
                "packageName" to info.packageName,
                "apkPath" to info.sourceDir,
                "size" to apk.length()
            ).apply {
                if (iconBytes != null) put("icon", iconBytes)
            }
        }
    }

    private fun openPath(path: String): Boolean {
        return try {
            val uri = if (path.startsWith("content://")) {
                Uri.parse(path)
            } else {
                val file = File(path)
                if (!file.exists()) return false
                FileProvider.getUriForFile(
                    this,
                    "${applicationContext.packageName}.fileprovider",
                    file
                )
            }
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, contentResolver.getType(uri) ?: "*/*")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, "Open with"))
            true
        } catch (_: Exception) {
            false
        }
    }
}
