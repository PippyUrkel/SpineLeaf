import 'dart:core';

void main() {
  String html = '<img class="ir" src="images/alice02a.gif" alt="The White Rabbit"/>';
  final blockPattern = RegExp(
    r'<(p|h[1-6]|div|blockquote|ul|ol|hr|img|pre|figure|figcaption|svg|image)(\s[^>]*)?>(.*?)</\1>|<(hr|img|br|image)(\s[^>]*)?\s*/?>',
    caseSensitive: false,
    dotAll: true,
  );
  for (final match in blockPattern.allMatches(html)) {
    final tag = (match.group(1) ?? match.group(4) ?? '').toLowerCase();
    final attrs = match.group(2) ?? match.group(5) ?? '';
    print("tag: $tag");
    print("attrs: $attrs");
    
    final srcMatch = RegExp(r'''(?:src|href|xlink:href)=["']([^"']*)["']''', caseSensitive: false).firstMatch(attrs);
    print("src: ${srcMatch?.group(1)}");
  }
}
