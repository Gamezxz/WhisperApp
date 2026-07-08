using System.Text.RegularExpressions;

namespace WhisperWin
{
    /// Strips sound-event annotations that STT engines insert, e.g. (เสียงลม) (wind) [applause] *laughs*
    /// Ported from DictationController.stripSoundAnnotations in the macOS version.
    public static class TextCleaner
    {
        private static readonly string[] Patterns =
        {
            @"\([^\)]*\)",   // ( ... )
            "（[^）]*）",      // （ ... ） fullwidth
            @"\[[^\]]*\]",   // [ ... ]
            "【[^】]*】",      // 【 ... 】
            @"\*[^*]*\*",    // * ... *
            "‹[^›]*›",
            "«[^»]*»",
        };

        public static string StripSoundAnnotations(string text)
        {
            if (string.IsNullOrEmpty(text)) return "";
            var result = text;
            foreach (var p in Patterns)
                result = Regex.Replace(result, p, " ");
            result = Regex.Replace(result, @"\s{2,}", " ");
            result = Regex.Replace(result, @"\s+([,.!?])", "$1");
            return result.Trim();
        }
    }
}
