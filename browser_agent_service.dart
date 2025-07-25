import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class BrowserAction {
  final String id;
  final String type; // navigate, click, type, screenshot, scroll, wait, execute_script
  final Map<String, dynamic> parameters;
  final DateTime timestamp;
  String status;
  Map<String, dynamic> result;

  BrowserAction({
    required this.id,
    required this.type,
    required this.parameters,
    required this.timestamp,
    this.status = 'pending',
    this.result = const {},
  });
}

class BrowserAgentTask {
  final String id;
  final String description;
  final List<BrowserAction> actions;
  final DateTime startTime;
  String status;
  String? currentActionId;
  Map<String, dynamic> context;

  BrowserAgentTask({
    required this.id,
    required this.description,
    required this.actions,
    required this.startTime,
    this.status = 'pending',
    this.currentActionId,
    this.context = const {},
  });
}

class BrowserAgentService extends ChangeNotifier {
  static final BrowserAgentService _instance = BrowserAgentService._internal();
  factory BrowserAgentService() => _instance;
  BrowserAgentService._internal();

  InAppWebViewController? _webViewController;
  bool _isAgentActive = false;
  bool _isProcessing = false;
  String _currentStatus = '';
  String _currentUrl = '';
  BrowserAgentTask? _currentTask;
  final List<BrowserAgentTask> _taskHistory = [];
  
  // Advanced capabilities
  Map<String, dynamic> _pageContext = {};
  List<String> _errorLog = [];
  bool _autoErrorRecovery = true;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  // Getters
  bool get isAgentActive => _isAgentActive;
  bool get isProcessing => _isProcessing;
  String get currentStatus => _currentStatus;
  String get currentUrl => _currentUrl;
  BrowserAgentTask? get currentTask => _currentTask;
  List<BrowserAgentTask> get taskHistory => List.unmodifiable(_taskHistory);
  Map<String, dynamic> get pageContext => Map.unmodifiable(_pageContext);
  List<String> get errorLog => List.unmodifiable(_errorLog);

  void setWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
  }

  void toggleAgent() {
    _isAgentActive = !_isAgentActive;
    if (!_isAgentActive) {
      _stopCurrentTask();
    }
    notifyListeners();
  }

  Future<void> executeTask(String taskDescription) async {
    if (!_isAgentActive || _webViewController == null) {
      throw Exception('Browser agent is not active or webview not initialized');
    }

    _isProcessing = true;
    _currentStatus = 'Analyzing task...';
    _retryCount = 0;
    notifyListeners();

    try {
      // Parse task and create actions
      final actions = await _parseTaskIntoActions(taskDescription);
      
      final task = BrowserAgentTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        description: taskDescription,
        actions: actions,
        startTime: DateTime.now(),
      );

      _currentTask = task;
      _updateStatus('Starting task execution...');

      // Execute actions sequentially
      for (final action in actions) {
        if (!_isAgentActive) break;
        
        task.currentActionId = action.id;
        await _executeAction(action);
        
        if (action.status == 'failed' && _autoErrorRecovery) {
          await _attemptErrorRecovery(action);
        }
      }

      task.status = 'completed';
      _taskHistory.add(task);
      _updateStatus('Task completed successfully');

    } catch (e) {
      _logError('Task execution failed: $e');
      _updateStatus('Task failed: $e');
      if (_currentTask != null) {
        _currentTask!.status = 'failed';
        _taskHistory.add(_currentTask!);
      }
    } finally {
      _isProcessing = false;
      _currentTask = null;
      notifyListeners();
    }
  }

  Future<List<BrowserAction>> _parseTaskIntoActions(String taskDescription) async {
    final task = taskDescription.toLowerCase();
    List<BrowserAction> actions = [];

    // Smart task parsing with common automation patterns
    if (task.contains('screenshot')) {
      actions.add(_createAction('screenshot', {}));
    }

    if (task.contains('navigate') || task.contains('go to') || task.contains('open')) {
      final urlPattern = RegExp(r'https?://[^\s]+|[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
      final match = urlPattern.firstMatch(taskDescription);
      if (match != null) {
        String url = match.group(0)!;
        if (!url.startsWith('http')) {
          url = 'https://$url';
        }
        actions.add(_createAction('navigate', {'url': url}));
      }
    }

    if (task.contains('search')) {
      final searchTerms = _extractSearchTerms(taskDescription);
      actions.addAll([
        _createAction('find_element', {'selector': 'input[type="search"], input[name*="search"], input[placeholder*="search"]'}),
        _createAction('type', {'text': searchTerms}),
        _createAction('key_press', {'key': 'Enter'}),
      ]);
    }

    if (task.contains('fill form') || task.contains('form')) {
      actions.add(_createAction('analyze_form', {}));
    }

    if (task.contains('book') || task.contains('reservation') || task.contains('ticket')) {
      actions.addAll(_createBookingActions(taskDescription));
    }

    if (task.contains('scroll')) {
      actions.add(_createAction('scroll', {'direction': 'down', 'pixels': 500}));
    }

    if (task.contains('click')) {
      final elementDesc = _extractElementDescription(taskDescription);
      actions.add(_createAction('smart_click', {'description': elementDesc}));
    }

    // If no specific actions identified, create a general analysis action
    if (actions.isEmpty) {
      actions.add(_createAction('analyze_page', {}));
    }

    return actions;
  }

  BrowserAction _createAction(String type, Map<String, dynamic> parameters) {
    return BrowserAction(
      id: '${type}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      parameters: parameters,
      timestamp: DateTime.now(),
    );
  }

  Future<void> _executeAction(BrowserAction action) async {
    _updateStatus('Executing: ${action.type}');
    action.status = 'executing';
    notifyListeners();

    try {
      switch (action.type) {
        case 'navigate':
          await _navigateToUrl(action.parameters['url']);
          break;
        case 'screenshot':
          await _takeScreenshot(action);
          break;
        case 'find_element':
          await _findElement(action);
          break;
        case 'click':
        case 'smart_click':
          await _clickElement(action);
          break;
        case 'type':
          await _typeText(action);
          break;
        case 'scroll':
          await _scrollPage(action);
          break;
        case 'wait':
          await _waitForCondition(action);
          break;
        case 'execute_script':
          await _executeScript(action);
          break;
        case 'analyze_page':
          await _analyzePage(action);
          break;
        case 'analyze_form':
          await _analyzeForm(action);
          break;
        case 'key_press':
          await _pressKey(action);
          break;
        default:
          throw Exception('Unknown action type: ${action.type}');
      }

      action.status = 'completed';
    } catch (e) {
      action.status = 'failed';
      action.result = {'error': e.toString()};
      _logError('Action ${action.type} failed: $e');
      rethrow;
    }
  }

  Future<void> _navigateToUrl(String url) async {
    await _webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    _currentUrl = url;
    await Future.delayed(const Duration(seconds: 2)); // Wait for page load
    notifyListeners();
  }

  Future<void> _takeScreenshot(BrowserAction action) async {
    final screenshot = await _webViewController!.takeScreenshot();
    action.result = {
      'screenshot': screenshot,
      'timestamp': DateTime.now().toIso8601String(),
      'url': _currentUrl,
    };
  }

  Future<void> _findElement(BrowserAction action) async {
    final selector = action.parameters['selector'] as String;
    
    // Enhanced element finding with multiple fallback strategies
    final script = '''
      function findElement(selector) {
        // Try direct selector first
        let element = document.querySelector(selector);
        if (element) return {found: true, selector: selector};
        
        // Try common input variations
        const inputSelectors = [
          'input[type="search"]',
          'input[name*="search"]',
          'input[placeholder*="search"]',
          'input[class*="search"]',
          'input[id*="search"]',
          '[role="searchbox"]',
          '.search-input',
          '#search',
          '.search-field'
        ];
        
        for (let sel of inputSelectors) {
          element = document.querySelector(sel);
          if (element) return {found: true, selector: sel, fallback: true};
        }
        
        return {found: false, error: 'Element not found'};
      }
      
      findElement('$selector');
    ''';

    final result = await _webViewController!.evaluateJavascript(source: script);
    action.result = result ?? {'found': false, 'error': 'Script execution failed'};
  }

  Future<void> _clickElement(BrowserAction action) async {
    String script;
    
    if (action.parameters.containsKey('selector')) {
      final selector = action.parameters['selector'] as String;
      script = '''
        const element = document.querySelector('$selector');
        if (element) {
          element.scrollIntoView({behavior: 'smooth', block: 'center'});
          setTimeout(() => element.click(), 500);
          true;
        } else {
          false;
        }
      ''';
    } else {
      // Smart clicking based on description
      final description = action.parameters['description'] as String? ?? '';
      script = '''
        function smartClick(description) {
          const desc = description.toLowerCase();
          let elements = [];
          
          // Search for buttons and links with matching text
          const clickables = document.querySelectorAll('button, a, input[type="submit"], input[type="button"], [role="button"], .btn, .button');
          
          for (let el of clickables) {
            const text = (el.textContent || el.value || el.title || el.ariaLabel || '').toLowerCase();
            if (text.includes(desc) || desc.includes(text)) {
              elements.push(el);
            }
          }
          
          if (elements.length > 0) {
            const element = elements[0];
            element.scrollIntoView({behavior: 'smooth', block: 'center'});
            setTimeout(() => element.click(), 500);
            return {clicked: true, element: element.tagName, text: element.textContent};
          }
          
          return {clicked: false, error: 'No matching clickable element found'};
        }
        
        smartClick('$description');
      ''';
    }

    final result = await _webViewController!.evaluateJavascript(source: script);
    action.result = result ?? {'clicked': false, 'error': 'Click failed'};
  }

  Future<void> _typeText(BrowserAction action) async {
    final text = action.parameters['text'] as String;
    final selector = action.parameters['selector'] as String? ?? 'input:focus, textarea:focus';
    
    final script = '''
      function typeText(selector, text) {
        let element = document.querySelector(selector);
        
        // If no element found with selector, try to find active element
        if (!element) {
          element = document.activeElement;
        }
        
        // Try to find any input/textarea if still no element
        if (!element || !['INPUT', 'TEXTAREA'].includes(element.tagName)) {
          element = document.querySelector('input, textarea');
        }
        
        if (element) {
          element.focus();
          element.value = text;
          
          // Trigger events to simulate real typing
          element.dispatchEvent(new Event('input', { bubbles: true }));
          element.dispatchEvent(new Event('change', { bubbles: true }));
          
          return {typed: true, value: text, element: element.tagName};
        }
        
        return {typed: false, error: 'No input element found'};
      }
      
      typeText('$selector', '$text');
    ''';

    final result = await _webViewController!.evaluateJavascript(source: script);
    action.result = result ?? {'typed': false, 'error': 'Type failed'};
  }

  Future<void> _scrollPage(BrowserAction action) async {
    final direction = action.parameters['direction'] as String? ?? 'down';
    final pixels = action.parameters['pixels'] as int? ?? 500;
    
    final script = '''
      window.scrollBy(0, ${direction == 'down' ? pixels : -pixels});
      {scrolled: true, direction: '$direction', pixels: $pixels, currentY: window.pageYOffset}
    ''';

    final result = await _webViewController!.evaluateJavascript(source: script);
    action.result = result ?? {'scrolled': false};
  }

  Future<void> _waitForCondition(BrowserAction action) async {
    final duration = action.parameters['duration'] as int? ?? 1000;
    await Future.delayed(Duration(milliseconds: duration));
    action.result = {'waited': true, 'duration': duration};
  }

  Future<void> _executeScript(BrowserAction action) async {
    final script = action.parameters['script'] as String;
    final result = await _webViewController!.evaluateJavascript(source: script);
    action.result = {'executed': true, 'result': result};
  }

  Future<void> _analyzePage(BrowserAction action) async {
    final script = '''
      function analyzePage() {
        const analysis = {
          title: document.title,
          url: window.location.href,
          forms: document.forms.length,
          links: document.links.length,
          images: document.images.length,
          inputs: document.querySelectorAll('input, textarea, select').length,
          buttons: document.querySelectorAll('button, input[type="submit"], input[type="button"]').length,
          viewport: {
            width: window.innerWidth,
            height: window.innerHeight
          },
          scroll: {
            top: window.pageYOffset,
            left: window.pageXOffset,
            maxY: document.body.scrollHeight,
            maxX: document.body.scrollWidth
          }
        };
        
        // Detect common page types
        const bodyText = document.body.textContent.toLowerCase();
        if (bodyText.includes('search') || document.querySelector('[type="search"]')) {
          analysis.pageType = 'search';
        } else if (bodyText.includes('booking') || bodyText.includes('reservation')) {
          analysis.pageType = 'booking';
        } else if (bodyText.includes('ticket') || bodyText.includes('event')) {
          analysis.pageType = 'ticketing';
        } else if (analysis.forms > 0) {
          analysis.pageType = 'form';
        } else {
          analysis.pageType = 'content';
        }
        
        return analysis;
      }
      
      analyzePage();
    ''';

    final result = await _webViewController!.evaluateJavascript(source: script);
    action.result = result ?? {'analyzed': false};
    _pageContext = action.result;
  }

  Future<void> _analyzeForm(BrowserAction action) async {
    final script = '''
      function analyzeForms() {
        const forms = Array.from(document.forms);
        const formAnalysis = [];
        
        forms.forEach((form, index) => {
          const inputs = Array.from(form.querySelectorAll('input, textarea, select'));
          const formData = {
            index: index,
            action: form.action,
            method: form.method,
            inputs: inputs.map(input => ({
              type: input.type,
              name: input.name,
              placeholder: input.placeholder,
              required: input.required,
              id: input.id,
              label: input.labels?.[0]?.textContent || ''
            }))
          };
          formAnalysis.push(formData);
        });
        
        return {forms: formAnalysis, count: forms.length};
      }
      
      analyzeForms();
    ''';

    final result = await _webViewController!.evaluateJavascript(source: script);
    action.result = result ?? {'forms': [], 'count': 0};
  }

  Future<void> _pressKey(BrowserAction action) async {
    final key = action.parameters['key'] as String;
    
    final script = '''
      const event = new KeyboardEvent('keydown', {
        key: '$key',
        code: '$key',
        keyCode: ${_getKeyCode(key)},
        which: ${_getKeyCode(key)},
        bubbles: true
      });
      
      const activeElement = document.activeElement || document.body;
      activeElement.dispatchEvent(event);
      
      if ('$key' === 'Enter') {
        const enterEvent = new KeyboardEvent('keypress', {
          key: 'Enter',
          code: 'Enter',
          keyCode: 13,
          which: 13,
          bubbles: true
        });
        activeElement.dispatchEvent(enterEvent);
      }
      
      {pressed: true, key: '$key'};
    ''';

    final result = await _webViewController!.evaluateJavascript(source: script);
    action.result = result ?? {'pressed': false};
  }

  int _getKeyCode(String key) {
    switch (key.toLowerCase()) {
      case 'enter': return 13;
      case 'escape': return 27;
      case 'space': return 32;
      case 'tab': return 9;
      default: return key.codeUnitAt(0);
    }
  }

  List<BrowserAction> _createBookingActions(String taskDescription) {
    // Smart booking flow detection
    return [
      _createAction('analyze_page', {}),
      _createAction('find_element', {'selector': 'input[type="date"], input[name*="date"], .date-picker'}),
      _createAction('find_element', {'selector': 'select[name*="passenger"], input[name*="guest"], input[type="number"]'}),
      _createAction('smart_click', {'description': 'search book find available'}),
    ];
  }

  String _extractSearchTerms(String taskDescription) {
    final patterns = [
      RegExp(r'search for (.+)', caseSensitive: false),
      RegExp(r'find (.+)', caseSensitive: false),
      RegExp(r'look for (.+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(taskDescription);
      if (match != null) {
        return match.group(1)!.trim();
      }
    }

    return taskDescription;
  }

  String _extractElementDescription(String taskDescription) {
    final patterns = [
      RegExp(r'click (?:on )?(.+)', caseSensitive: false),
      RegExp(r'press (.+)', caseSensitive: false),
      RegExp(r'tap (.+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(taskDescription);
      if (match != null) {
        return match.group(1)!.trim();
      }
    }

    return 'button';
  }

  Future<void> _attemptErrorRecovery(BrowserAction failedAction) async {
    if (_retryCount >= _maxRetries) return;

    _retryCount++;
    _updateStatus('Attempting error recovery (${_retryCount}/$_maxRetries)...');

    // Wait before retry
    await Future.delayed(Duration(seconds: _retryCount));

    // Try different approaches based on action type
    switch (failedAction.type) {
      case 'find_element':
        // Try alternative selectors
        await _executeAction(_createAction('execute_script', {
          'script': '''
            // Scroll to top and wait for elements to load
            window.scrollTo(0, 0);
            setTimeout(() => {
              // Try to find any input element
              const inputs = document.querySelectorAll('input, textarea, [contenteditable="true"]');
              if (inputs.length > 0) {
                inputs[0].focus();
              }
            }, 1000);
            {recovery: true, inputs_found: document.querySelectorAll('input, textarea').length};
          '''
        }));
        break;

      case 'click':
      case 'smart_click':
        // Try clicking with coordinates
        await _executeAction(_createAction('execute_script', {
          'script': '''
            // Simulate click in center of viewport
            const centerX = window.innerWidth / 2;
            const centerY = window.innerHeight / 2;
            document.elementFromPoint(centerX, centerY)?.click();
            {recovery: true, clicked_center: true};
          '''
        }));
        break;
    }

    // Retry the original action
    failedAction.status = 'retrying';
    await _executeAction(failedAction);
  }

  void _updateStatus(String status) {
    _currentStatus = status;
    notifyListeners();
  }

  void _logError(String error) {
    _errorLog.add('${DateTime.now().toIso8601String()}: $error');
    if (_errorLog.length > 50) {
      _errorLog.removeAt(0);
    }
  }

  void _stopCurrentTask() {
    _isProcessing = false;
    _currentTask = null;
    _currentStatus = '';
    notifyListeners();
  }

  // Preset automation methods for common tasks
  Future<void> searchForTickets(String event, String location, DateTime date) async {
    await executeTask(
      'Search for $event tickets in $location on ${date.day}/${date.month}/${date.year}'
    );
  }

  Future<void> fillBookingForm(Map<String, String> formData) async {
    final formText = formData.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
    
    await executeTask('Fill booking form with $formText');
  }

  Future<void> automateWebsite(String website, String task) async {
    await executeTask('Navigate to $website and $task');
  }

  void clearHistory() {
    _taskHistory.clear();
    _errorLog.clear();
    notifyListeners();
  }
}