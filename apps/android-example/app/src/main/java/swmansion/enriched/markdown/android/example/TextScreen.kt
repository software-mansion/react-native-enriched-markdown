package swmansion.enriched.markdown.android.example

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText

@Composable
fun TextScreen(
  markdown: String,
  modifier: Modifier = Modifier,
) {
  val context = LocalContext.current

  Column(
    modifier =
      modifier
        .fillMaxSize()
        .background(Color.White)
        .verticalScroll(rememberScrollState())
        .padding(horizontal = 16.dp, vertical = 16.dp),
  ) {
    EnrichedMarkdownText(
      markdown = markdown,
      modifier = Modifier.fillMaxWidth(),
      onLinkPress = { url ->
        runCatching {
          context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
        }
      },
    )
  }
}
