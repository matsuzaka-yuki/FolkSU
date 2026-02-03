package me.weishu.kernelsu.ui.screen

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.core.content.edit
import androidx.lifecycle.compose.dropUnlessResumed
import androidx.activity.compose.LocalActivity
import me.weishu.kernelsu.R
import me.weishu.kernelsu.ui.component.ExpressiveColumn
import me.weishu.kernelsu.ui.component.ExpressiveRadioItem
import me.weishu.kernelsu.ui.navigation3.LocalNavigator
import java.util.Locale

private val languages = listOf(
    "system" to R.string.settings_language_follow_system,
    "en" to R.string.language_english,
    "zh-CN" to R.string.language_simplified_chinese,
    "zh-TW" to R.string.language_traditional_chinese,
    "ja" to R.string.language_japanese
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LanguageSettingsScreen() {
    val navigator = LocalNavigator.current
    val context = LocalContext.current
    val activity = LocalActivity.current as Activity
    val prefs = context.getSharedPreferences("settings", Context.MODE_PRIVATE)

    var selectedIndex by rememberSaveable {
        val savedLang = prefs.getString("app_language", "system")
        val index = languages.indexOfFirst { it.first == savedLang }.coerceAtLeast(0)
        mutableIntStateOf(index)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(
                        onClick = dropUnlessResumed {
                            navigator.pop()
                        }
                    ) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null) }
                },
                title = { Text(stringResource(R.string.settings_language)) },
                windowInsets = WindowInsets.safeDrawing.only(WindowInsetsSides.Top + WindowInsetsSides.Horizontal)
            )
        },
        contentWindowInsets = WindowInsets.safeDrawing.only(WindowInsetsSides.Top + WindowInsetsSides.Horizontal)
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
        ) {
            Spacer(modifier = Modifier.height(8.dp))

            ExpressiveColumn(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                content = languages.mapIndexed { index, (_, stringRes) ->
                    {
                        ExpressiveRadioItem(
                            title = stringResource(id = stringRes),
                            selected = selectedIndex == index,
                            onClick = {
                                if (selectedIndex != index) {
                                    selectedIndex = index
                                    val langCode = languages[index].first
                                    prefs.edit { putString("app_language", langCode) }
                                    setLocale(activity)
                                }
                            }
                        )
                    }
                }
            )
        }
    }
}

private fun setLocale(activity: Activity) {
    // Restart activity to apply language change
    val intent = Intent(activity, activity::class.java)
    intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
    activity.finish()
    activity.startActivity(intent)
}
