using System.Collections;
using System.Collections.Generic;
using System.Web.Script.Serialization;

namespace WhisperWin
{
    /// Thin helpers over JavaScriptSerializer for navigating untyped JSON responses.
    public static class Json
    {
        public static JavaScriptSerializer Serializer()
        {
            return new JavaScriptSerializer { MaxJsonLength = 32 * 1024 * 1024 };
        }

        public static Dictionary<string, object> ParseObject(string json)
        {
            try { return Serializer().Deserialize<Dictionary<string, object>>(json); }
            catch { return null; }
        }

        public static object Get(Dictionary<string, object> obj, string key)
        {
            object v;
            return obj != null && obj.TryGetValue(key, out v) ? v : null;
        }

        public static Dictionary<string, object> AsObject(object o)
        {
            return o as Dictionary<string, object>;
        }

        public static IEnumerable<object> AsArray(object o)
        {
            var e = o as IEnumerable;
            if (e == null || o is string) yield break;
            foreach (var item in e) yield return item;
        }

        public static string AsString(object o)
        {
            return o as string;
        }
    }
}
