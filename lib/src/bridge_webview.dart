import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'bridge.dart';

class DsBridgeWebView extends StatefulWidget {
  final BridgeCreatedCallback onDSBridgeCreated;

  DsBridgeWebView({
    super.key,
    required this.onDSBridgeCreated,
  });

  @override
  DsBridgeWebViewState createState() => DsBridgeWebViewState();
}

class DsBridgeWebViewState extends State<DsBridgeWebView> {
  final DsBridgeBasic dsBridge = DsBridgeBasic();

  late final WebViewController _controller;

  @override
  void initState() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }
    _controller = WebViewController.fromPlatformCreationParams(params);
    if (_controller.platform is WebKitWebViewController) {
      (_controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }

    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 DsBridge/1.0.0')
      ..addJavaScriptChannel(
        DsBridge.BRIDGE_NAME,
        onMessageReceived: (message) {
          var res = jsonDecode(message.message);
          dsBridge.javascriptInterface(res['method'], res['args']);
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) => NavigationDecision.navigate,
        onPageFinished: _onPageFinished,
      ))
      ..loadFlutterAsset(
          'packages/whiteboard_sdk_flutter/assets/whiteboardBridge/index.html');

    dsBridge.initController(_controller);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => WebViewWidget(
        controller: _controller,
      ),
    );
  }

  Future<void> _onPageFinished(String url) async {
    debugPrint('WebView Page finished loading: $url');
    if (url.endsWith('whiteboardBridge/index.html')) {
      await dsBridge.runCompatScript();
      widget.onDSBridgeCreated(dsBridge);
    }
  }
}

class DsBridgeBasic extends DsBridge {
  static const _compatDsScript = '''
      if (window.__dsbridge) {
          window._dsbridge = {}
          window._dsbridge.call = function (method, arg) {
              console.log(`call flutter webview \${method} \${arg}`);
              window.__dsbridge.postMessage(JSON.stringify({ 'method': method, 'args': arg }))
              return '{}';
          }
          console.log('wrapper flutter webview success');
      } else {
          console.log('window.__dsbridge undefine');
      }
  ''';

  late WebViewController _controller;

  Future<void> initController(WebViewController controller) async {
    _controller = controller;
  }

  Future<void> runCompatScript() async {
    try {
      await _controller.runJavaScript(_compatDsScript);
    } catch (e) {
      print('WebView bridge run compat script error $e');
    }
  }

  @override
  FutureOr<String?> evaluateJavascript(String javascript) async {
    try {
      return (await _controller.runJavaScriptReturningResult(javascript))
          as String?;
    } catch (e) {
      print('WebView bridge evaluateJavascript cause $e');
      return null;
    }
  }
}
