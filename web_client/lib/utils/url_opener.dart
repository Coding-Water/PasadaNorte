import 'url_opener_stub.dart'
    if (dart.library.html) 'url_opener_web.dart' as impl;

void openUrlInNewTab(String url) => impl.openUrlInNewTab(url);
