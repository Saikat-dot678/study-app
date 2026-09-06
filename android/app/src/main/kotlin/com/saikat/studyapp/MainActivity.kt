package com.saikat.studyapp

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.Locale
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val storageWorker = Executors.newSingleThreadExecutor()
    private val channelName = "study.app/storage"
    private val requestTree = 7001
    private val requestFiles = 7002
    private val prefs by lazy { getSharedPreferences("study_app_storage", MODE_PRIVATE) }
    private var channel: MethodChannel? = null
    private var pendingTreeResult: MethodChannel.Result? = null
    private var pendingImportResult: MethodChannel.Result? = null
    private var pendingImportDestination: String = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        storageWorker.execute { handleShareIntent(intent) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).also { methodChannel ->
            methodChannel.setMethodCallHandler { call, result ->
                val work = Runnable {
                    try {
                        when (call.method) {
                            "readMetadata" -> result.success(readMetadata())
                            "writeMetadata" -> {
                                writeMetadata(call.argument<String>("json") ?: "", call.argument<Int>("slot") ?: 0)
                                result.success(null)
                            }
                            "getLibraryState" -> result.success(libraryState())
                            "pickLibraryFolder" -> pickLibraryFolder(result)
                            "forgetLibrary" -> {
                                prefs.edit().remove("tree_uri").apply()
                                result.success(null)
                            }
                            "listEntries" -> result.success(listEntries(call.argument<String>("path") ?: ""))
                            "searchEntries" -> result.success(searchEntries(call.argument<String>("query") ?: ""))
                            "pickAndImportFiles" -> pickAndImportFiles(call.argument<String>("destination") ?: "", result)
                            "createFolder" -> result.success(createFolder(call.argument<String>("parent") ?: "", call.argument<String>("name") ?: ""))
                            "createNote" -> result.success(createNote(call.argument<String>("parent") ?: "", call.argument<String>("title") ?: "Untitled note", call.argument<String>("body") ?: ""))
                            "renameEntry" -> result.success(renameEntry(call.argument<String>("path") ?: "", call.argument<String>("name") ?: ""))
                            "moveEntry" -> result.success(moveEntry(call.argument<String>("source") ?: "", call.argument<String>("destination") ?: ""))
                            "deleteEntry" -> {
                                val path = call.argument<String>("path") ?: ""
                                result.success(path.isNotBlank() && path != ".studyapp" && !path.startsWith(".studyapp/") && (resolve(path)?.delete() ?: false))
                            }
                            "entryUri" -> result.success(entryUri(call.argument<String>("path") ?: ""))
                            "prepareEntry" -> result.success(prepareEntry(call.argument<String>("path") ?: ""))
                            "openEntry" -> {
                                openEntry(call.argument<String>("path") ?: "")
                                result.success(null)
                            }
                            "shareEntry" -> {
                                shareEntry(call.argument<String>("path") ?: "")
                                result.success(null)
                            }
                            else -> result.notImplemented()
                        }
                    } catch (error: Exception) {
                        result.error("storage_error", error.message ?: "Storage operation failed", null)
                    }
                }
                if (call.method in setOf("pickLibraryFolder", "pickAndImportFiles", "openEntry", "shareEntry")) work.run()
                else storageWorker.execute(work)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        storageWorker.execute { handleShareIntent(intent) }
    }

    override fun onDestroy() {
        storageWorker.shutdown()
        super.onDestroy()
    }

    @Deprecated("Deprecated in Android API; FlutterActivity still forwards activity results through this method.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            requestTree -> finishTreeSelection(resultCode, data)
            requestFiles -> finishFileImport(resultCode, data)
        }
    }

    private fun pickLibraryFolder(result: MethodChannel.Result) {
        if (pendingTreeResult != null) {
            result.error("busy", "A folder picker is already open", null)
            return
        }
        pendingTreeResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        }
        startActivityForResult(intent, requestTree)
    }

    private fun finishTreeSelection(resultCode: Int, data: Intent?) {
        val result = pendingTreeResult ?: return
        pendingTreeResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(libraryState())
            return
        }
        val uri = data.data!!
        val flags = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        try {
            contentResolver.takePersistableUriPermission(uri, flags)
        } catch (_: SecurityException) {
        }
        prefs.edit().putString("tree_uri", uri.toString()).apply()
        storageWorker.execute {
            try {
                prepareRoot()
                val flushed = flushPendingShares()
                if (flushed.isNotEmpty()) notifyShared(flushed)
                result.success(libraryState())
            } catch (error: Exception) { result.error("storage_error", error.message, null) }
        }
    }

    private fun pickAndImportFiles(destination: String, result: MethodChannel.Result) {
        if (root() == null) {
            result.error("no_library", "Choose a library folder first", null)
            return
        }
        if (pendingImportResult != null) {
            result.error("busy", "A file picker is already open", null)
            return
        }
        pendingImportDestination = destination
        pendingImportResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivityForResult(intent, requestFiles)
    }

    private fun finishFileImport(resultCode: Int, data: Intent?) {
        val result = pendingImportResult ?: return
        pendingImportResult = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<String>())
            return
        }
        val uris = mutableListOf<Uri>()
        data.data?.let(uris::add)
        data.clipData?.let { clip ->
            for (index in 0 until clip.itemCount) uris.add(clip.getItemAt(index).uri)
        }
        val destination = pendingImportDestination
        storageWorker.execute {
            try {
                val target = resolveFolder(destination)
                    ?: throw IllegalStateException("Destination folder is unavailable")
                val imported = uris.distinct().mapNotNull { copyUriInto(it, target) }
                if (imported.size != uris.distinct().size) {
                    result.error("partial_import", "Imported ${imported.size} of ${uris.distinct().size} files. Check access to the remaining files.", null)
                } else result.success(imported)
            } catch (error: Exception) { result.error("storage_error", error.message, null) }
        }
    }

    private fun readMetadata(): List<String> {
        val folder = root()?.findFile(".studyapp") ?: return emptyList()
        return (0..1).mapNotNull { slot ->
            folder.findFile("workspace-$slot.json")?.let { file ->
                contentResolver.openInputStream(file.uri)?.bufferedReader()?.use { it.readText() }
                    ?: throw IllegalStateException("Cannot read metadata")
            }
        }
    }

    private fun writeMetadata(json: String, slot: Int) {
        require(slot in 0..1)
        val root = root() ?: throw IllegalStateException("Library unavailable")
        val folder = root.findFile(".studyapp") ?: root.createDirectory(".studyapp")
            ?: throw IllegalStateException("Cannot create metadata folder")
        val file = folder.findFile("workspace-$slot.json") ?: folder.createFile("application/json", "workspace-$slot.json")
            ?: throw IllegalStateException("Cannot create metadata")
        (contentResolver.openOutputStream(file.uri, "wt") ?: throw IllegalStateException("Cannot save metadata"))
            .bufferedWriter().use { it.write(json) }
    }

    private fun libraryState(): Map<String, Any?> {
        val root = root()
        return mapOf(
            "connected" to (root != null && root.canRead()),
            "name" to root?.name,
            "uri" to prefs.getString("tree_uri", null),
            "pendingShares" to pendingShareDir().listFiles()?.size.orZero()
        )
    }

    private fun root(): DocumentFile? {
        val uriText = prefs.getString("tree_uri", null) ?: return null
        return try {
            DocumentFile.fromTreeUri(this, Uri.parse(uriText))?.takeIf { it.exists() && it.isDirectory }
        } catch (_: Exception) {
            null
        }
    }

    private fun prepareRoot() {
        val root = root() ?: return
        listOf("Inbox").forEach { name ->
            if (root.findFile(name) == null) root.createDirectory(name)
        }
        val appDir = root.findFile(".studyapp") ?: root.createDirectory(".studyapp")
        if (appDir != null && appDir.findFile("library.json") == null) {
            val marker = appDir.createFile("application/json", "library.json")
            marker?.uri?.let { uri ->
                contentResolver.openOutputStream(uri, "wt")?.bufferedWriter()?.use { writer ->
                    writer.write("{\"schemaVersion\":1,\"app\":\"study_app\"}")
                }
            }
        }
    }

    private fun listEntries(path: String): List<Map<String, Any?>> {
        val folder = resolveFolder(path) ?: return emptyList()
        return folder.listFiles()
            .filter { it.name != ".studyapp" }
            .map { entryMap(it, joinPath(path, it.name ?: "Untitled")) }
    }

    private fun searchEntries(query: String): List<Map<String, Any?>> {
        val root = root() ?: return emptyList()
        val normalized = query.trim().lowercase(Locale.getDefault())
        val results = mutableListOf<Map<String, Any?>>()
        val pending = java.util.ArrayDeque<Pair<DocumentFile, String>>()
        pending.add(root to "")
        while (pending.isNotEmpty()) {
            val (folder, parentPath) = pending.removeFirst()
            for (child in folder.listFiles()) {
                val name = child.name ?: "Untitled"
                if (name == ".studyapp") continue
                val path = joinPath(parentPath, name)
                if (normalized.isEmpty() || path.lowercase(Locale.ROOT).contains(normalized)) results.add(entryMap(child, path))
                if (child.isDirectory) pending.add(child to path)
            }
        }
        return results
    }

    private fun entryMap(file: DocumentFile, path: String): Map<String, Any?> = mapOf(
        "name" to (file.name ?: "Untitled"),
        "path" to path,
        "isDirectory" to file.isDirectory,
        "mime" to file.type,
        "size" to if (file.isDirectory) 0L else file.length(),
        "lastModified" to file.lastModified()
    )

    private fun resolve(path: String): DocumentFile? {
        if (path.isBlank()) return root()
        require(path.split('/').none { it == "." || it == ".." || it.contains('\\') }) { "Invalid library path" }
        var current = root() ?: return null
        for (part in splitPath(path)) {
            current = current.findFile(part) ?: return null
        }
        return current
    }

    private fun resolveFolder(path: String): DocumentFile? = resolve(path)?.takeIf { it.isDirectory }

    private fun createFolder(parent: String, name: String): Boolean {
        val clean = sanitizeName(name)
        if (clean.isBlank()) return false
        val folder = resolveFolder(parent) ?: return false
        if (folder.findFile(clean) != null) return false
        return folder.createDirectory(clean) != null
    }

    private fun createNote(parent: String, title: String, body: String): Boolean {
        val folder = resolveFolder(parent) ?: return false
        var clean = sanitizeName(title).ifBlank { "Untitled note" }
        if (!clean.lowercase(Locale.getDefault()).endsWith(".md")) clean += ".md"
        clean = uniqueName(folder, clean)
        val file = folder.createFile("text/markdown", clean) ?: return false
        contentResolver.openOutputStream(file.uri, "wt")?.bufferedWriter()?.use { writer ->
            writer.write("# ${clean.removeSuffix(".md")}\n\n")
            writer.write(body)
        } ?: return false
        return true
    }

    private fun renameEntry(path: String, name: String): Boolean {
        if (path.isBlank() || path == ".studyapp" || path.startsWith(".studyapp/")) return false
        val file = resolve(path) ?: return false
        val clean = sanitizeName(name)
        val parent = resolveFolder(path.substringBeforeLast('/', "")) ?: return false
        if (parent.findFile(clean) != null) return false
        if (clean.isBlank()) return false
        return file.renameTo(clean)
    }

    private fun moveEntry(sourcePath: String, destinationPath: String): Boolean {
        if (sourcePath.isBlank()) return false
        if (destinationPath == sourcePath || destinationPath.startsWith("$sourcePath/")) return false
        val source = resolve(sourcePath) ?: return false
        val destination = resolveFolder(destinationPath) ?: return false
        if (sourcePath.substringBeforeLast('/', "") == destinationPath) return true
        if (destination.findFile(source.name ?: "") != null) return false
        val copied = copyDocument(source, destination)
        return copied && source.delete()
    }

    private fun copyDocument(source: DocumentFile, destination: DocumentFile): Boolean {
        val sourceName = source.name ?: "Untitled"
        val name = uniqueName(destination, sourceName)
        if (source.isDirectory) {
            val newFolder = destination.createDirectory(name) ?: return false
            for (child in source.listFiles()) {
                if (!copyDocument(child, newFolder)) {
                    newFolder.delete()
                    return false
                }
            }
            return true
        }
        val target = destination.createFile(source.type ?: "application/octet-stream", name) ?: return false
        return try {
            (contentResolver.openInputStream(source.uri) ?: throw IllegalStateException("Cannot read source")).use { input ->
                (contentResolver.openOutputStream(target.uri, "w") ?: throw IllegalStateException("Cannot write destination")).use { output -> input.copyTo(output) }
            }
            true
        } catch (_: Exception) {
            target.delete()
            false
        }
    }

    private fun entryUri(path: String): String {
        val file = resolve(path) ?: throw IllegalArgumentException("File is unavailable")
        if (file.isDirectory) throw IllegalArgumentException("Folders do not have a playable URI")
        return file.uri.toString()
    }

    private fun prepareEntry(path: String): String {
        val file = resolve(path) ?: throw IllegalArgumentException("File is unavailable")
        if (file.isDirectory) throw IllegalArgumentException("Folders cannot be previewed")

        val previewDir = File(cacheDir, "study_previews").apply { mkdirs() }
        val staleBefore = System.currentTimeMillis() - 7L * 24L * 60L * 60L * 1000L
        previewDir.listFiles()?.filter { it.lastModified() < staleBefore }?.forEach { it.delete() }

        val cleanName = sanitizeName(file.name ?: "preview").ifBlank { "preview" }
        val cacheKey = java.security.MessageDigest.getInstance("SHA-256")
            .digest(file.uri.toString().toByteArray()).joinToString("") { "%02x".format(it) }
        val cacheFile = File(previewDir, "${cacheKey}_$cleanName")
        val sourceModified = file.lastModified()
        val cacheIsFresh = cacheFile.exists() &&
            cacheFile.length() == file.length() &&
            (sourceModified > 0L && cacheFile.lastModified() >= sourceModified)

        if (!cacheIsFresh) {
            try {
                contentResolver.openInputStream(file.uri)?.use { input ->
                    FileOutputStream(cacheFile, false).use { output -> input.copyTo(output) }
                } ?: throw IllegalStateException("Could not read the selected file")
                if (sourceModified > 0L) cacheFile.setLastModified(sourceModified)
            } catch (error: Exception) {
                cacheFile.delete()
                throw error
            }
        }
        return cacheFile.absolutePath
    }

    private fun openEntry(path: String) {
        val file = resolve(path) ?: throw IllegalArgumentException("File is unavailable")
        if (file.isDirectory) return
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(file.uri, file.type ?: "*/*")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            startActivity(Intent.createChooser(intent, "Open with"))
        } catch (_: Exception) {
            throw IllegalStateException("No app on this phone can open this file type")
        }
    }

    private fun shareEntry(path: String) {
        val file = resolve(path) ?: throw IllegalArgumentException("File is unavailable")
        if (file.isDirectory) throw IllegalArgumentException("Share individual files, not folders")
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = file.type ?: "*/*"
            putExtra(Intent.EXTRA_STREAM, file.uri)
            clipData = ClipData.newUri(contentResolver, file.name ?: "Study material", file.uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, "Share study material"))
    }

    private fun copyUriInto(sourceUri: Uri, destination: DocumentFile): String? {
        var target: DocumentFile? = null
        return try {
            val displayName = queryDisplayName(sourceUri) ?: "Imported file"
            val name = uniqueName(destination, sanitizeName(displayName).ifBlank { "Imported file" })
            val mime = contentResolver.getType(sourceUri) ?: guessMime(name)
            val outputFile = destination.createFile(mime, name) ?: return null
            target = outputFile
            (contentResolver.openInputStream(sourceUri) ?: throw IllegalStateException("Cannot read source")).use { input ->
                (contentResolver.openOutputStream(outputFile.uri, "w") ?: throw IllegalStateException("Cannot write destination")).use { output -> input.copyTo(output) }
            }
            outputFile.name ?: name
        } catch (_: Exception) {
            target?.delete()
            null
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) return cursor.getString(index)
            }
        }
        return uri.lastPathSegment?.substringAfterLast('/')
    }

    private fun uniqueName(folder: DocumentFile, desired: String): String {
        if (folder.findFile(desired) == null) return desired
        val dot = desired.lastIndexOf('.')
        val hasExtension = dot > 0 && dot < desired.length - 1
        val base = if (hasExtension) desired.substring(0, dot) else desired
        val extension = if (hasExtension) desired.substring(dot) else ""
        var index = 2
        while (folder.findFile("$base ($index)$extension") != null) index++
        return "$base ($index)$extension"
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent == null || (intent.action != Intent.ACTION_SEND && intent.action != Intent.ACTION_SEND_MULTIPLE)) return
        val imported = mutableListOf<String>()
        @Suppress("DEPRECATION")
        if (intent.action == Intent.ACTION_SEND) {
            val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            if (uri != null) receiveSharedUri(uri)?.let(imported::add)
            else intent.getStringExtra(Intent.EXTRA_TEXT)?.takeIf { it.isNotBlank() }?.let { text ->
                receiveSharedText(text)?.let(imported::add)
            }
        } else {
            @Suppress("DEPRECATION")
            val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM).orEmpty()
            uris.forEach { uri -> receiveSharedUri(uri)?.let(imported::add) }
        }
        if (imported.isNotEmpty()) notifyShared(imported)
    }

    private fun receiveSharedUri(uri: Uri): String? {
        val root = root()
        if (root != null) {
            val inbox = root.findFile("Inbox") ?: root.createDirectory("Inbox")
            if (inbox != null) return copyUriInto(uri, inbox)
        }
        return stageSharedUri(uri)
    }

    private fun receiveSharedText(text: String): String? {
        val root = root()
        if (root != null) {
            val inbox = root.findFile("Inbox") ?: root.createDirectory("Inbox")
            if (inbox != null) {
                val name = uniqueName(inbox, "Shared text.txt")
                val target = inbox.createFile("text/plain", name) ?: return null
                contentResolver.openOutputStream(target.uri, "wt")?.bufferedWriter()?.use { it.write(text) }
                return target.name ?: name
            }
        }
        val pending = File(pendingShareDir(), "${System.currentTimeMillis()}_Shared text.txt")
        pending.writeText(text)
        return pending.name.substringAfter('_')
    }

    private fun stageSharedUri(uri: Uri): String? {
        var pending: File? = null
        return try {
            val displayName = sanitizeName(queryDisplayName(uri) ?: "Shared file").ifBlank { "Shared file" }
            val outputFile = File(pendingShareDir(), "${java.util.UUID.randomUUID()}_$displayName")
            pending = outputFile
            (contentResolver.openInputStream(uri) ?: throw IllegalStateException("Cannot read shared file")).use { input ->
                FileOutputStream(outputFile).use { output -> input.copyTo(output) }
            }
            displayName
        } catch (_: Exception) {
            pending?.delete()
            null
        }
    }

    private fun pendingShareDir(): File = File(filesDir, "pending_shares").apply { mkdirs() }

    private fun flushPendingShares(): List<String> {
        val root = root() ?: return emptyList()
        val inbox = root.findFile("Inbox") ?: root.createDirectory("Inbox") ?: return emptyList()
        val names = mutableListOf<String>()
        pendingShareDir().listFiles()?.sortedBy { it.lastModified() }?.forEach { file ->
            val original = file.name.substringAfter('_', file.name)
            val name = uniqueName(inbox, sanitizeName(original))
            val target = inbox.createFile(guessMime(name), name)
            if (target != null) {
                try {
                    FileInputStream(file).use { input ->
                        (contentResolver.openOutputStream(target.uri, "w") ?: throw IllegalStateException("Could not write shared file")).use { output -> input.copyTo(output) }
                    }
                    file.delete()
                    names.add(target.name ?: name)
                } catch (_: Exception) {
                    target.delete()
                }
            }
        }
        return names
    }

    private fun notifyShared(names: List<String>) {
        runOnUiThread { channel?.invokeMethod("shareReceived", names) }
    }

    private fun sanitizeName(value: String): String = value
        .replace('/', '_')
        .replace('\\', '_')
        .replace(Regex("[\\u0000-\\u001F]"), "")
        .trim()

    private fun splitPath(path: String): List<String> = path
        .split('/')
        .filter { it.isNotEmpty() && it != "." && it != ".." }

    private fun joinPath(parent: String, child: String): String = if (parent.isBlank()) child else "$parent/$child"

    private fun guessMime(name: String): String {
        val extension = name.substringAfterLast('.', "").lowercase(Locale.getDefault())
        return when (extension) {
            "pdf" -> "application/pdf"
            "epub" -> "application/epub+zip"
            "ppt" -> "application/vnd.ms-powerpoint"
            "pptx" -> "application/vnd.openxmlformats-officedocument.presentationml.presentation"
            "odp" -> "application/vnd.oasis.opendocument.presentation"
            "doc" -> "application/msword"
            "docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            "odt" -> "application/vnd.oasis.opendocument.text"
            "xls" -> "application/vnd.ms-excel"
            "xlsx" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            "ods" -> "application/vnd.oasis.opendocument.spreadsheet"
            "csv" -> "text/csv"
            "txt", "md" -> "text/plain"
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "webp" -> "image/webp"
            "mp3" -> "audio/mpeg"
            "m4a" -> "audio/mp4"
            "wav" -> "audio/wav"
            "mp4", "m4v" -> "video/mp4"
            "webm" -> "video/webm"
            "mkv" -> "video/x-matroska"
            "zip" -> "application/zip"
            else -> "application/octet-stream"
        }
    }

    private fun Int?.orZero(): Int = this ?: 0
}
