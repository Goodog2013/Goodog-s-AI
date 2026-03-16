class WebSearchResult {
  const WebSearchResult({
    required this.title,
    required this.url,
    required this.snippet,
    this.isError = false,
  });

  final String title;
  final String url;
  final String snippet;
  final bool isError;
}
