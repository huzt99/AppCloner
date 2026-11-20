package com.example.appcloner

import android.content.pm.ApplicationInfo
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp

data class AppItem(val label: String, val pkg: String)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val apps = packageManager.getInstalledApplications(0)
            .filter { it.flags and ApplicationInfo.FLAG_SYSTEM == 0 && it.packageName != packageName }
            .map { AppItem(packageManager.getApplicationLabel(it).toString(), it.packageName) }
            .sortedBy { it.label }
        setContent {
            CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                MaterialTheme { Root(apps) }
            }
        }
    }
}

@Composable
fun Root(apps: List<AppItem>) {
    var selected by remember { mutableStateOf<AppItem?>(null) }
    selected?.let { ClonesScreen(it) { selected = null } } ?: PickerScreen(apps) { selected = it }
}

@Composable
fun CompatBadge(c: Compat) {
    val (text, color) = when (c) {
        Compat.OK -> "متوافق" to MaterialTheme.colorScheme.primary
        Compat.RISKY -> "قد يُحظر" to MaterialTheme.colorScheme.tertiary
        Compat.BLOCKED -> "غير مدعوم" to MaterialTheme.colorScheme.error
    }
    Text(text, color = color, style = MaterialTheme.typography.labelMedium)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PickerScreen(apps: List<AppItem>, onPick: (AppItem) -> Unit) {
    var query by remember { mutableStateOf("") }
    Scaffold(topBar = { TopAppBar(title = { Text("اختيار التطبيق") }) }) { pad ->
        Column(Modifier.padding(pad).padding(horizontal = 16.dp)) {
            OutlinedTextField(query, { query = it }, Modifier.fillMaxWidth(), placeholder = { Text("ابحث عن تطبيق") }, singleLine = true)
            LazyColumn {
                items(apps.filter { it.label.contains(query, true) }) { app ->
                    val c = CompatChecker.check(app.pkg)
                    ListItem(
                        headlineContent = { Text(app.label) },
                        trailingContent = { CompatBadge(c) },
                        modifier = Modifier.clickable(enabled = c != Compat.BLOCKED) { onPick(app) }
                    )
                    HorizontalDivider()
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ClonesScreen(app: AppItem, onBack: () -> Unit) {
    var clones by remember { mutableStateOf(CloneManager.clones(app.pkg)) }
    Scaffold(topBar = {
        TopAppBar(title = { Text(app.label) },
            navigationIcon = { IconButton(onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "رجوع") } })
    }) { pad ->
        Column(Modifier.padding(pad).padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("${clones.size} من ${CloneManager.MAX} نسخ")
            clones.forEach { id ->
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text("النسخة ${id + 1}", Modifier.weight(1f))
                    OutlinedButton({ CloneManager.launch(app.pkg, id) }) { Text("تشغيل") }
                    IconButton({ CloneManager.remove(app.pkg, id); clones = CloneManager.clones(app.pkg) }) {
                        Icon(Icons.Default.Delete, "حذف")
                    }
                }
                HorizontalDivider()
            }
            Button(
                onClick = { CloneManager.add(app.pkg); clones = CloneManager.clones(app.pkg) },
                enabled = clones.size < CloneManager.MAX,
                modifier = Modifier.fillMaxWidth()
            ) { Icon(Icons.Default.Add, null); Spacer(Modifier.width(8.dp)); Text("إضافة نسخة") }
        }
    }
}
