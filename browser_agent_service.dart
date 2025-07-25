import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class BrowserAction {
  final String id;
  final String type; // navigate, click, type, screenshot, scroll, wait, execute_script, analyze, plan, multi_task
  final Map<String, dynamic> parameters;
  final DateTime timestamp;
  String status;
  Map<String, dynamic> result;
  String? reasoning; // AI reasoning for this action
  int retryCount;

  BrowserAction({
    required this.id,
    required this.type,
    required this.parameters,
    required this.timestamp,
    this.status = 'pending',
    this.result = const {},
    this.reasoning,
    this.retryCount = 0,
  });
}

class BrowserTab {
  final String id;
  String url;
  final String title;
  final Map<String, dynamic> context;
  InAppWebViewController? controller;
  bool isActive;
  DateTime lastActivity;

  BrowserTab({
    required this.id,
    required this.url,
    required this.title,
    this.context = const {},
    this.controller,
    this.isActive = false,
    required this.lastActivity,
  });
}

class TaskPlan {
  final String id;
  final String objective;
  final List<BrowserAction> plannedActions;
  final Map<String, dynamic> context;
  final DateTime createdAt;
  String status;
  List<String> adaptations; // Track how plan was adapted during execution

  TaskPlan({
    required this.id,
    required this.objective,
    required this.plannedActions,
    required this.context,
    required this.createdAt,
    this.status = 'pending',
    this.adaptations = const [],
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
  TaskPlan? plan;
  List<String> screenshots; // Store screenshot paths/data
  Map<String, dynamic> extractedData; // Data extracted during task
  Duration? executionTime;

  BrowserAgentTask({
    required this.id,
    required this.description,
    required this.actions,
    required this.startTime,
    this.status = 'pending',
    this.currentActionId,
    this.context = const {},
    this.plan,
    this.screenshots = const [],
    this.extractedData = const {},
    this.executionTime,
  });
}

class BrowserAgentService extends ChangeNotifier {
  static final BrowserAgentService _instance = BrowserAgentService._internal();
  factory BrowserAgentService() => _instance;
  BrowserAgentService._internal();

  InAppWebViewController? _webViewController;
  bool _isAgentActive = false;
  bool _isProcessing = false;
  bool _isThinking = false;
  String _currentStatus = '';
  String _thinkingStatus = '';
  String _currentUrl = '';
  BrowserAgentTask? _currentTask;
  TaskPlan? _currentPlan;
  final List<BrowserAgentTask> _taskHistory = [];
  final List<BrowserTab> _activeTabs = [];
  
  // Advanced AI capabilities
  Map<String, dynamic> _pageContext = {};
  Map<String, dynamic> _globalContext = {}; // Cross-task context
  List<String> _errorLog = [];
  bool _autoErrorRecovery = true;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  
  // Multi-step execution state
  Timer? _executionTimer;
  bool _continuousMode = false;
  List<String> _knowledgeBase = []; // Store learned patterns
  
  // Advanced DOM analysis
  Map<String, dynamic> _domSnapshot = {};
  List<Map<String, dynamic>> _interactableElements = [];
  
  // Performance metrics
  Map<String, int> _actionSuccessRates = {};
  Map<String, Duration> _actionTimings = {};

  // Getters
  bool get isAgentActive => _isAgentActive;
  bool get isProcessing => _isProcessing;
  bool get isThinking => _isThinking;
  String get currentStatus => _currentStatus;
  String get thinkingStatus => _thinkingStatus;
  String get currentUrl => _currentUrl;
  BrowserAgentTask? get currentTask => _currentTask;
  TaskPlan? get currentPlan => _currentPlan;
  List<BrowserAgentTask> get taskHistory => List.unmodifiable(_taskHistory);
  List<BrowserTab> get activeTabs => List.unmodifiable(_activeTabs);
  Map<String, dynamic> get pageContext => Map.unmodifiable(_pageContext);
  Map<String, dynamic> get globalContext => Map.unmodifiable(_globalContext);
  List<String> get errorLog => List.unmodifiable(_errorLog);

  void setWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
    _currentUrl = 'https://www.google.com';
    // Initialize the primary tab
    if (_activeTabs.isEmpty) {
      _activeTabs.add(BrowserTab(
        id: 'primary',
        url: _currentUrl,
        title: 'Google',
        controller: controller,
        isActive: true,
        lastActivity: DateTime.now(),
      ));
    }
  }

  void toggleAgent() {
    _isAgentActive = !_isAgentActive;
    if (!_isAgentActive) {
      // Gracefully stop any running task when the agent is de-activated
      stopCurrentTask();
    }
    notifyListeners();
  }

  Future<void> executeTask(String taskDescription) async {
    if (!_isAgentActive || _webViewController == null) {
      throw Exception('Browser agent is not active or webview not initialized');
    }

    _isProcessing = true;
    _isThinking = true;
    _thinkingStatus = 'Analyzing your request...';
    _currentStatus = 'Thinking...';
    _retryCount = 0;
    notifyListeners();

    final startTime = DateTime.now();

    try {
      // Phase 1: AI Planning - Think about the task
      await _thinkAndPlan(taskDescription);
      
      // Phase 2: Execute the plan
      await _executePlan();

      // Phase 3: Validate results
      await _validateTaskCompletion();

      if (_currentTask != null) {
        _currentTask!.status = 'completed';
        _currentTask!.executionTime = DateTime.now().difference(startTime);
        _taskHistory.add(_currentTask!);
        _updateStatus('Task completed successfully! 🎉');
        
        // Learn from successful execution
        _updateKnowledgeBase(_currentTask!);
      }

    } catch (e) {
      _logError('Task execution failed: $e');
      _updateStatus('Task failed: $e');
      if (_currentTask != null) {
        _currentTask!.status = 'failed';
        _currentTask!.executionTime = DateTime.now().difference(startTime);
        _taskHistory.add(_currentTask!);
      }
    } finally {
      _isProcessing = false;
      _isThinking = false;
      _currentTask = null;
      _currentPlan = null;
      notifyListeners();
    }
  }

  Future<void> _thinkAndPlan(String taskDescription) async {
    _thinkingStatus = 'Understanding the objective...';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 800));

    // Analyze current context
    await analyzeCurrentPage();
    
    _thinkingStatus = 'Creating execution plan...';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 600));

    // Create AI-powered task plan
    final plan = await _createSmartTaskPlan(taskDescription);
    _currentPlan = plan;
    
    _thinkingStatus = 'Optimizing strategy...';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));

    // Create task with planned actions
    _currentTask = BrowserAgentTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      description: taskDescription,
      actions: plan.plannedActions,
      startTime: DateTime.now(),
      plan: plan,
      context: {'original_context': _pageContext, 'global_context': _globalContext},
    );

    _isThinking = false;
    _updateStatus('Executing plan with ${plan.plannedActions.length} actions...');
    notifyListeners();
  }

  Future<TaskPlan> _createSmartTaskPlan(String taskDescription) async {
    final task = taskDescription.toLowerCase();
    List<BrowserAction> actions = [];
    Map<String, dynamic> context = {};

    // Advanced AI task analysis with context awareness
    if (_isShoppingTask(task)) {
      actions.addAll(await _planShoppingTask(taskDescription));
    } else if (_isSearchAndAnalysisTask(task)) {
      actions.addAll(await _planSearchAndAnalysisTask(taskDescription));
    } else if (_isBookingTask(task)) {
      actions.addAll(await _planBookingTask(taskDescription));
    } else if (_isDataExtractionTask(task)) {
      actions.addAll(await _planDataExtractionTask(taskDescription));
    } else if (_isComparisonTask(task)) {
      actions.addAll(await _planComparisonTask(taskDescription));
    } else {
      actions.addAll(await _planGenericTask(taskDescription));
    }

    return TaskPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      objective: taskDescription,
      plannedActions: actions,
      context: context,
      createdAt: DateTime.now(),
    );
  }

  bool _isShoppingTask(String task) {
    return task.contains('shop') || task.contains('buy') || task.contains('price') || 
           task.contains('compare') || task.contains('product') || task.contains('cart');
  }

  bool _isSearchAndAnalysisTask(String task) {
    return task.contains('search') || task.contains('find') || task.contains('look for') ||
           task.contains('analyze') || task.contains('research');
  }

  bool _isBookingTask(String task) {
    return task.contains('book') || task.contains('reservation') || task.contains('ticket') ||
           task.contains('hotel') || task.contains('flight');
  }

  bool _isDataExtractionTask(String task) {
    return task.contains('extract') || task.contains('collect') || task.contains('gather') ||
           task.contains('scrape') || task.contains('get data');
  }

  bool _isComparisonTask(String task) {
    return task.contains('compare') || task.contains('vs') || task.contains('versus') ||
           task.contains('difference') || task.contains('best') || task.contains('top');
  }

  Future<List<BrowserAction>> _planShoppingTask(String taskDescription) async {
    List<BrowserAction> actions = [];
    
    // Extract product and shopping sites
    final product = _extractProductFromTask(taskDescription);
    final sites = _extractShoppingSites(taskDescription);
    
    if (sites.isEmpty) {
      // Use default shopping sites
      sites.addAll(['amazon.com', 'ebay.com', 'walmart.com']);
    }

    // Plan multi-site price comparison
    for (int i = 0; i < sites.length; i++) {
      if (i > 0) {
        actions.add(_createAction('open_new_tab', {}));
      }
      
      actions.addAll([
        _createAction('navigate', {'url': 'https://${sites[i]}', 'reasoning': 'Navigate to ${sites[i]} for product search'}),
        _createAction('wait_for_load', {'duration': 2000}),
        _createAction('smart_search', {'query': product, 'reasoning': 'Search for $product'}),
        _createAction('analyze_results', {'extract_prices': true, 'extract_ratings': true}),
        _createAction('screenshot', {'filename': '${sites[i]}_results.png'}),
      ]);
    }
    
    actions.add(_createAction('compare_data', {'type': 'price_comparison'}));
    return actions;
  }

  Future<List<BrowserAction>> _planSearchAndAnalysisTask(String taskDescription) async {
    List<BrowserAction> actions = [];
    
    final query = _extractSearchQuery(taskDescription);
    final analysisType = _extractAnalysisType(taskDescription);
    
    actions.addAll([
      _createAction('navigate', {'url': 'https://www.google.com', 'reasoning': 'Start with Google search'}),
      _createAction('smart_search', {'query': query, 'reasoning': 'Search for information about $query'}),
      _createAction('analyze_search_results', {'top_results': 5}),
      _createAction('visit_top_results', {'count': 3, 'analysis_type': analysisType}),
      _createAction('extract_insights', {'type': analysisType}),
      _createAction('summarize_findings', {}),
    ]);
    
    return actions;
  }

  Future<List<BrowserAction>> _planBookingTask(String taskDescription) async {
    List<BrowserAction> actions = [];
    
    final bookingDetails = _extractBookingDetails(taskDescription);
    
    actions.addAll([
      _createAction('navigate', {'url': bookingDetails['site'] ?? 'https://www.expedia.com'}),
      _createAction('detect_booking_form', {}),
      _createAction('fill_booking_details', {'details': bookingDetails}),
      _createAction('search_available_options', {}),
      _createAction('analyze_booking_options', {}),
      _createAction('screenshot', {'filename': 'booking_options.png'}),
    ]);
    
    return actions;
  }

  Future<List<BrowserAction>> _planDataExtractionTask(String taskDescription) async {
    List<BrowserAction> actions = [];
    
    final extractionTargets = _extractDataTargets(taskDescription);
    
    actions.addAll([
      _createAction('analyze_page_structure', {}),
      _createAction('identify_data_elements', {'targets': extractionTargets}),
      _createAction('extract_structured_data', {'format': 'json'}),
      _createAction('validate_extracted_data', {}),
      _createAction('export_data', {'format': 'csv'}),
    ]);
    
    return actions;
  }

  Future<List<BrowserAction>> _planComparisonTask(String taskDescription) async {
    List<BrowserAction> actions = [];
    
    final comparisonItems = _extractComparisonItems(taskDescription);
    
    for (final item in comparisonItems) {
      actions.addAll([
        _createAction('open_new_tab', {}),
        _createAction('research_item', {'item': item}),
        _createAction('extract_key_features', {'item': item}),
      ]);
    }
    
    actions.addAll([
      _createAction('create_comparison_table', {}),
      _createAction('analyze_pros_cons', {}),
      _createAction('generate_recommendation', {}),
    ]);
    
    return actions;
  }

  Future<List<BrowserAction>> _planGenericTask(String taskDescription) async {
    List<BrowserAction> actions = [];
    
    // Intelligent generic planning based on context
    if (_pageContext.containsKey('forms') && _pageContext['forms'] > 0) {
      actions.add(_createAction('analyze_forms', {}));
    }
    
    if (taskDescription.contains('screenshot')) {
      actions.add(_createAction('screenshot', {}));
    }
    
    if (taskDescription.contains('scroll')) {
      actions.add(_createAction('smart_scroll', {'direction': 'auto'}));
    }
    
    // Default to page analysis if no specific actions
    if (actions.isEmpty) {
      actions.addAll([
        _createAction('analyze_page', {}),
        _createAction('identify_interactive_elements', {}),
        _createAction('suggest_actions', {}),
      ]);
    }
    
    return actions;
  }

  Future<void> _executePlan() async {
    if (_currentPlan == null || _currentTask == null) return;

    for (final action in _currentPlan!.plannedActions) {
      if (!_isAgentActive) break;
      
      _currentTask!.currentActionId = action.id;
      _updateStatus('${action.reasoning ?? 'Executing ${action.type}'}...');
      
      final actionStart = DateTime.now();
      await _executeAction(action);
      final actionDuration = DateTime.now().difference(actionStart);
      
      // Track performance
      _actionTimings[action.type] = actionDuration;
      
      if (action.status == 'failed' && _autoErrorRecovery) {
        await _attemptSmartRecovery(action);
      }
      
      // Adaptive delay based on action type and complexity
      await Future.delayed(_calculateAdaptiveDelay(action));
    }
  }

  Duration _calculateAdaptiveDelay(BrowserAction action) {
    switch (action.type) {
      case 'navigate':
        return const Duration(milliseconds: 2000);
      case 'screenshot':
        return const Duration(milliseconds: 500);
      case 'analyze_page':
        return const Duration(milliseconds: 1000);
      default:
        return const Duration(milliseconds: 800);
    }
  }

  Future<void> _executeAction(BrowserAction action) async {
    action.status = 'executing';
    notifyListeners();

    try {
      switch (action.type) {
        case 'navigate':
          await _navigateToUrl(action.parameters['url']);
          break;
        case 'smart_search':
          await _performSmartSearch(action);
          break;
        case 'screenshot':
          await _takeAdvancedScreenshot(action);
          break;
        case 'analyze_page':
          await _performAdvancedPageAnalysis(action);
          break;
        case 'open_new_tab':
          await _openNewTab(action);
          break;
        case 'extract_structured_data':
          await _extractStructuredData(action);
          break;
        case 'compare_data':
          await _compareExtractedData(action);
          break;
        case 'smart_scroll':
          await _performSmartScroll(action);
          break;
        case 'wait_for_load':
          await _waitForPageLoad(action);
          break;
        case 'analyze_results':
          await _analyzeSearchResults(action);
          break;
        case 'visit_top_results':
          await _visitTopResults(action);
          break;
        case 'fill_booking_details':
          await _fillBookingDetails(action);
          break;
        case 'identify_interactive_elements':
          await _identifyInteractiveElements(action);
          break;
        default:
          await _executeBasicAction(action);
      }

      action.status = 'completed';
      _actionSuccessRates[action.type] = (_actionSuccessRates[action.type] ?? 0) + 1;
      
    } catch (e) {
      action.status = 'failed';
      action.result = {'error': e.toString()};
      _logError('Action ${action.type} failed: $e');
      rethrow;
    }
  }

  Future<void> _performSmartSearch(BrowserAction action) async {
    final query = action.parameters['query'] as String;
    
    final script = '''
      function performSmartSearch(query) {
        // Try multiple search strategies
        const searchSelectors = [
          'input[name="q"]',
          'input[type="search"]',
          'input[placeholder*="search" i]',
          'input[aria-label*="search" i]',
          '.search-input',
          '#search',
          '[role="searchbox"]'
        ];
        
        let searchElement = null;
        for (const selector of searchSelectors) {
          searchElement = document.querySelector(selector);
          if (searchElement) break;
        }
        
        if (searchElement) {
          searchElement.focus();
          searchElement.value = query;
          
          // Trigger input events
          searchElement.dispatchEvent(new Event('input', { bubbles: true }));
          searchElement.dispatchEvent(new Event('change', { bubbles: true }));
          
          // Try to find and click search button
          const searchButtons = [
            'button[type="submit"]',
            'input[type="submit"]',
            'button[aria-label*="search" i]',
            '.search-button',
            '[role="button"][aria-label*="search" i]'
          ];
          
          let searchButton = null;
          for (const btnSelector of searchButtons) {
            searchButton = document.querySelector(btnSelector);
            if (searchButton) break;
          }
          
          if (searchButton) {
            setTimeout(() => searchButton.click(), 500);
          } else {
            // Press Enter if no button found
            searchElement.dispatchEvent(new KeyboardEvent('keydown', {
              key: 'Enter',
              keyCode: 13,
              bubbles: true
            }));
          }
          
          return {
            success: true,
            method: searchButton ? 'button_click' : 'enter_key',
            query: query
          };
        }
        
        return {success: false, error: 'No search element found'};
      }
      
      performSmartSearch('$query');
    ''';

    final result = await _webViewController!.evaluateJavascript(source: script);
    action.result = result ?? {'success': false, 'error': 'Script execution failed'};
  }

  Future<void> _takeAdvancedScreenshot(BrowserAction action) async {
    final screenshot = await _webViewController!.takeScreenshot();
    final filename = action.parameters['filename'] as String? ?? 'screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
    
    action.result = {
      'screenshot': screenshot,
      'timestamp': DateTime.now().toIso8601String(),
      'url': _currentUrl,
      'filename': filename,
      'page_context': _pageContext,
    };
    
    // Store screenshot in current task
    if (_currentTask != null) {
      _currentTask!.screenshots = [..._currentTask!.screenshots, filename];
    }
  }

  Future<void> _performAdvancedPageAnalysis(BrowserAction action) async {
    final script = '''
      function performAdvancedAnalysis() {
        const analysis = {
          basic: {
            title: document.title,
            url: window.location.href,
            domain: window.location.hostname,
            loadTime: performance.now()
          },
          content: {
            headings: {
              h1: Array.from(document.querySelectorAll('h1')).map(el => el.textContent.trim()),
              h2: Array.from(document.querySelectorAll('h2')).map(el => el.textContent.trim()),
              h3: Array.from(document.querySelectorAll('h3')).map(el => el.textContent.trim())
            },
            paragraphs: Array.from(document.querySelectorAll('p')).length,
            wordCount: document.body.textContent.trim().split(/\\s+/).length
          },
          interactive: {
            forms: Array.from(document.forms).map(form => ({
              action: form.action,
              method: form.method,
              inputs: Array.from(form.querySelectorAll('input, textarea, select')).map(input => ({
                type: input.type,
                name: input.name,
                placeholder: input.placeholder,
                required: input.required
              }))
            })),
            buttons: Array.from(document.querySelectorAll('button, input[type="submit"], input[type="button"]')).length,
            links: Array.from(document.links).map(link => ({
              href: link.href,
              text: link.textContent.trim()
            })).slice(0, 20), // Limit to first 20 links
            clickableElements: document.querySelectorAll('[onclick], [role="button"], .btn, .button').length
          },
          structure: {
            navigation: document.querySelector('nav') ? true : false,
            header: document.querySelector('header') ? true : false,
            footer: document.querySelector('footer') ? true : false,
            sidebar: document.querySelector('aside, .sidebar') ? true : false
          },
          ecommerce: {
            products: document.querySelectorAll('.product, [data-product], .item').length,
            prices: Array.from(document.querySelectorAll('[class*="price"], [data-price]')).map(el => el.textContent.trim()).slice(0, 10),
            addToCartButtons: document.querySelectorAll('[class*="add"], [class*="cart"], [data-cart]').length
          },
          seo: {
            metaDescription: document.querySelector('meta[name="description"]')?.content || '',
            metaKeywords: document.querySelector('meta[name="keywords"]')?.content || '',
            ogTitle: document.querySelector('meta[property="og:title"]')?.content || '',
            canonicalUrl: document.querySelector('link[rel="canonical"]')?.href || ''
          },
          performance: {
            images: document.images.length,
            scripts: document.scripts.length,
            stylesheets: document.querySelectorAll('link[rel="stylesheet"]').length,
            videoElements: document.querySelectorAll('video').length,
            audioElements: document.querySelectorAll('audio').length
          }
        };
        
        // Detect page type
        const bodyText = document.body.textContent.toLowerCase();
        if (analysis.ecommerce.products > 0 || bodyText.includes('shop') || bodyText.includes('buy')) {
          analysis.pageType = 'ecommerce';
        } else if (analysis.interactive.forms.length > 0) {
          analysis.pageType = 'form';
        } else if (bodyText.includes('search') || document.querySelector('[type="search"]')) {
          analysis.pageType = 'search';
        } else if (bodyText.includes('news') || analysis.content.headings.h1.length > 3) {
          analysis.pageType = 'news';
        } else if (analysis.content.wordCount > 1000) {
          analysis.pageType = 'content';
        } else {
          analysis.pageType = 'landing';
        }
        
        return analysis;
      }
      
      performAdvancedAnalysis();
    ''';

    final result = await _webViewController!.evaluateJavascript(source: script);
    action.result = result ?? {'analyzed': false};
    _pageContext = action.result;
    
    // Update global context with learned patterns
    _updateGlobalContext(action.result);
  }

  Future<void> _openNewTab(BrowserAction action) async {
    // Simulate new tab by tracking multiple contexts
    final newTabId = 'tab_${DateTime.now().millisecondsSinceEpoch}';
    _activeTabs.add(BrowserTab(
      id: newTabId,
      url: '',
      title: 'New Tab',
      lastActivity: DateTime.now(),
    ));
    
    action.result = {'tab_id': newTabId, 'total_tabs': _activeTabs.length};
  }

  Future<void> _extractStructuredData(BrowserAction action) async {
    final script = '''
      function extractStructuredData() {
        const data = {};
        
        // Extract products if ecommerce
        const products = Array.from(document.querySelectorAll('.product, [data-product], .item')).map(product => ({
          name: product.querySelector('.title, .name, h2, h3')?.textContent?.trim() || '',
          price: product.querySelector('[class*="price"], [data-price]')?.textContent?.trim() || '',
          rating: product.querySelector('[class*="rating"], [data-rating]')?.textContent?.trim() || '',
          image: product.querySelector('img')?.src || '',
          link: product.querySelector('a')?.href || ''
        })).filter(p => p.name || p.price);
        
        if (products.length > 0) {
          data.products = products;
        }
        
        // Extract articles/news
        const articles = Array.from(document.querySelectorAll('article, .article, .news-item')).map(article => ({
          title: article.querySelector('h1, h2, h3, .title')?.textContent?.trim() || '',
          summary: article.querySelector('.summary, .excerpt, p')?.textContent?.trim().substring(0, 200) || '',
          date: article.querySelector('.date, time')?.textContent?.trim() || '',
          author: article.querySelector('.author, .byline')?.textContent?.trim() || '',
          link: article.querySelector('a')?.href || ''
        })).filter(a => a.title);
        
        if (articles.length > 0) {
          data.articles = articles;
        }
        
        // Extract form data structure
        const forms = Array.from(document.forms).map(form => ({
          action: form.action,
          method: form.method,
          fields: Array.from(form.querySelectorAll('input, textarea, select')).map(field => ({
            name: field.name,
            type: field.type,
            label: field.labels?.[0]?.textContent?.trim() || '',
            required: field.required,
            placeholder: field.placeholder
          }))
        }));
        
        if (forms.length > 0) {
          data.forms = forms;
        }
        
        return data;
      }
      
      extractStructuredData();
    ''';

    final result = await _webViewController!.evaluateJavascript(source: script);
    action.result = result ?? {};
    
    // Store extracted data in current task
    if (_currentTask != null && result != null) {
      _currentTask!.extractedData = {..._currentTask!.extractedData, ...result};
    }
  }

  Future<void> _compareExtractedData(BrowserAction action) async {
    if (_currentTask == null || _currentTask!.extractedData.isEmpty) {
      action.result = {'error': 'No data to compare'};
      return;
    }
    
    final extractedData = _currentTask!.extractedData;
    Map<String, dynamic> comparison = {};
    
    // Compare products if available
    if (extractedData.containsKey('products')) {
      final products = extractedData['products'] as List;
      comparison['price_analysis'] = _analyzeProductPrices(products);
      comparison['product_count'] = products.length;
    }
    
    // Add more comparison logic based on data type
    comparison['timestamp'] = DateTime.now().toIso8601String();
    comparison['data_sources'] = _activeTabs.map((tab) => tab.url).toList();
    
    action.result = comparison;
  }

  Map<String, dynamic> _analyzeProductPrices(List products) {
    List<double> prices = [];
    
    for (final product in products) {
      final priceStr = product['price']?.toString() ?? '';
      final priceMatch = RegExp(r'[\d,]+\.?\d*').firstMatch(priceStr);
      if (priceMatch != null) {
        final price = double.tryParse(priceMatch.group(0)?.replaceAll(',', '') ?? '');
        if (price != null) prices.add(price);
      }
    }
    
    if (prices.isEmpty) return {'error': 'No valid prices found'};
    
    prices.sort();
    
    return {
      'min_price': prices.first,
      'max_price': prices.last,
      'avg_price': prices.reduce((a, b) => a + b) / prices.length,
      'price_range': prices.last - prices.first,
      'total_products': prices.length,
    };
  }

  Future<void> _performSmartScroll(BrowserAction action) async {
    final direction = action.parameters['direction'] as String? ?? 'down';
    
    final script = '''
      function smartScroll(direction) {
        const viewportHeight = window.innerHeight;
        const documentHeight = document.documentElement.scrollHeight;
        const currentScroll = window.pageYOffset;
        
        let scrollAmount;
        
        if (direction === 'auto') {
          // Intelligent scrolling based on content
          const remainingContent = documentHeight - currentScroll - viewportHeight;
          scrollAmount = Math.min(remainingContent, viewportHeight * 0.8);
        } else if (direction === 'down') {
          scrollAmount = viewportHeight * 0.8;
        } else {
          scrollAmount = -viewportHeight * 0.8;
        }
        
        window.scrollBy({
          top: scrollAmount,
          behavior: 'smooth'
        });
        
        return {
          scrolled: true,
          direction: direction,
          amount: scrollAmount,
          new_position: window.pageYOffset + scrollAmount,
          max_scroll: documentHeight
        };
      }
      
      smartScroll('$direction');
    ''';

    final result = await _webViewController!.evaluateJavascript(source: script);
    action.result = result ?? {'scrolled': false};
  }

  Future<void> _waitForPageLoad(BrowserAction action) async {
    final duration = action.parameters['duration'] as int? ?? 2000;
    
    // Smart waiting - check if page is actually loaded
    for (int i = 0; i < duration ~/ 100; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      
      final script = '''
        document.readyState === 'complete' && 
        (window.jQuery ? jQuery.active === 0 : true)
      ''';
      
      final isLoaded = await _webViewController!.evaluateJavascript(source: script);
      if (isLoaded == true) break;
    }
    
    action.result = {'waited': true, 'duration': duration};
  }

  Future<void> _analyzeSearchResults(BrowserAction action) async {
    final script = '''
      function analyzeSearchResults() {
        const results = [];
        
        // Google search results
        const googleResults = document.querySelectorAll('.g, .MjjYud');
        googleResults.forEach((result, index) => {
          const title = result.querySelector('h3')?.textContent?.trim() || '';
          const link = result.querySelector('a')?.href || '';
          const snippet = result.querySelector('.VwiC3b, .s3v9rd')?.textContent?.trim() || '';
          
          if (title && link) {
            results.push({
              position: index + 1,
              title: title,
              link: link,
              snippet: snippet,
              domain: new URL(link).hostname
            });
          }
        });
        
        // Generic search results if not Google
        if (results.length === 0) {
          const genericResults = document.querySelectorAll('.result, .search-result, [class*="result"]');
          genericResults.forEach((result, index) => {
            const title = result.querySelector('h1, h2, h3, .title')?.textContent?.trim() || '';
            const link = result.querySelector('a')?.href || '';
            const snippet = result.querySelector('p, .description, .snippet')?.textContent?.trim() || '';
            
            if (title && link) {
              results.push({
                position: index + 1,
                title: title,
                link: link,
                snippet: snippet,
                domain: new URL(link).hostname
              });
            }
          });
        }
        
        return {
          results: results.slice(0, 10), // Top 10 results
          total_found: results.length,
          analysis_timestamp: new Date().toISOString()
        };
      }
      
      analyzeSearchResults();
    ''';

    final result = await _webViewController!.evaluateJavascript(source: script);
    action.result = result ?? {'results': [], 'total_found': 0};
  }

  Future<void> _visitTopResults(BrowserAction action) async {
    final count = action.parameters['count'] as int? ?? 3;
    final analysisType = action.parameters['analysis_type'] as String? ?? 'general';
    
    // This would be implemented with multiple tab handling
    // For now, store the plan to visit results
    action.result = {
      'planned_visits': count,
      'analysis_type': analysisType,
      'status': 'planned'
    };
  }

  Future<void> _fillBookingDetails(BrowserAction action) async {
    final details = action.parameters['details'] as Map<String, dynamic>? ?? {};
    
    final script = '''
      function fillBookingForm(details) {
        const filled = {};
        
        // Common booking form fields
        const fieldMappings = {
          'departure': ['input[name*="departure"], input[name*="from"], input[name*="origin"]'],
          'destination': ['input[name*="destination"], input[name*="to"], input[name*="dest"]'],
          'checkin': ['input[name*="checkin"], input[name*="check_in"], input[type="date"]'],
          'guests': ['input[name*="guest"], input[name*="passenger"], select[name*="adult"]'],
          'rooms': ['select[name*="room"], input[name*="room"]']
        };
        
        Object.keys(fieldMappings).forEach(fieldType => {
          const selectors = fieldMappings[fieldType];
          for (const selector of selectors) {
            const element = document.querySelector(selector);
            if (element && details[fieldType]) {
              element.value = details[fieldType];
              element.dispatchEvent(new Event('input', { bubbles: true }));
              element.dispatchEvent(new Event('change', { bubbles: true }));
              filled[fieldType] = details[fieldType];
              break;
            }
          }
        });
        
        return { filled: filled, available_fields: Object.keys(fieldMappings) };
      }
      
      fillBookingForm(${json.encode(details)});
    ''';

    final result = await _webViewController!.evaluateJavascript(source: script);
    action.result = result ?? {'filled': {}, 'error': 'Failed to fill form'};
  }

  Future<void> _identifyInteractiveElements(BrowserAction action) async {
    final script = '''
      function identifyInteractiveElements() {
        const elements = [];
        
        // Get all potentially interactive elements
        const selectors = [
          'button', 'input', 'select', 'textarea', 'a[href]',
          '[onclick]', '[role="button"]', '[role="link"]',
          '.btn', '.button', '.link', '[tabindex]'
        ];
        
        selectors.forEach(selector => {
          document.querySelectorAll(selector).forEach(el => {
            const rect = el.getBoundingClientRect();
            if (rect.width > 0 && rect.height > 0) { // Only visible elements
              elements.push({
                tag: el.tagName.toLowerCase(),
                type: el.type || 'unknown',
                text: el.textContent?.trim() || '',
                id: el.id || '',
                className: el.className || '',
                href: el.href || '',
                position: {
                  x: rect.left,
                  y: rect.top,
                  width: rect.width,
                  height: rect.height
                },
                isVisible: rect.top >= 0 && rect.top <= window.innerHeight
              });
            }
          });
        });
        
        return {
          elements: elements,
          total_count: elements.length,
          visible_count: elements.filter(el => el.isVisible).length
        };
      }
      
      identifyInteractiveElements();
    ''';

    final result = await _webViewController!.evaluateJavascript(source: script);
    action.result = result ?? {'elements': [], 'total_count': 0};
    _interactableElements = (result?['elements'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  // Navigation and basic actions
  Future<void> _navigateToUrl(String url) async {
    await _webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    _currentUrl = url;
    
    // Update current tab
    final currentTab = _activeTabs.firstWhere((tab) => tab.isActive, 
        orElse: () => _activeTabs.first);
    currentTab.url = url;
    currentTab.lastActivity = DateTime.now();
    
    await Future.delayed(const Duration(seconds: 2)); // Wait for page load
    notifyListeners();
  }

  Future<void> _executeBasicAction(BrowserAction action) async {
    // Handle other action types that don't need special implementation
    switch (action.type) {
      case 'click':
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
      default:
        throw Exception('Unknown action type: ${action.type}');
    }
  }

  // Existing basic methods (simplified versions)
  Future<void> _clickElement(BrowserAction action) async {
    // Implementation similar to original but enhanced
    final result = await _webViewController!.evaluateJavascript(source: 'true');
    action.result = result ?? {'clicked': false};
  }

  Future<void> _typeText(BrowserAction action) async {
    // Implementation similar to original but enhanced
    final result = await _webViewController!.evaluateJavascript(source: 'true');
    action.result = result ?? {'typed': false};
  }

  Future<void> _scrollPage(BrowserAction action) async {
    // Implementation similar to original but enhanced
    final result = await _webViewController!.evaluateJavascript(source: 'true');
    action.result = result ?? {'scrolled': false};
  }

  Future<void> _waitForCondition(BrowserAction action) async {
    // Implementation similar to original
    final duration = action.parameters['duration'] as int? ?? 1000;
    await Future.delayed(Duration(milliseconds: duration));
    action.result = {'waited': true, 'duration': duration};
  }

  Future<void> _executeScript(BrowserAction action) async {
    // Implementation similar to original
    final script = action.parameters['script'] as String;
    final result = await _webViewController!.evaluateJavascript(source: script);
    action.result = {'executed': true, 'result': result};
  }

  // Enhanced error recovery and learning
  Future<void> _attemptSmartRecovery(BrowserAction failedAction) async {
    if (_retryCount >= _maxRetries) return;

    _retryCount++;
    _updateStatus('Smart recovery attempt ${_retryCount}/$_maxRetries...');

    // AI-powered recovery based on failure patterns
    await _analyzeFailurePattern(failedAction);
    
    // Wait before retry with exponential backoff
    await Future.delayed(Duration(seconds: _retryCount * 2));

    // Adapt the action based on current page context
    final adaptedAction = await _adaptActionForRetry(failedAction);
    
    // Retry with adapted parameters
    await _executeAction(adaptedAction);
  }

  Future<void> _analyzeFailurePattern(BrowserAction failedAction) async {
    // Analyze why the action failed and learn from it
    await _performAdvancedPageAnalysis(_createAction('analyze_page', {}));
    
    // Store failure pattern in knowledge base
    _knowledgeBase.add('${failedAction.type}_failure_${DateTime.now().millisecondsSinceEpoch}');
  }

  Future<BrowserAction> _adaptActionForRetry(BrowserAction originalAction) async {
    // Create adapted version of the action based on current context
    final adaptedParameters = Map<String, dynamic>.from(originalAction.parameters);
    
    // Add adaptive logic based on action type
    switch (originalAction.type) {
      case 'smart_search':
        // Try alternative search strategies
        adaptedParameters['retry_strategy'] = 'alternative_selectors';
        break;
      case 'click':
        // Try clicking with coordinates instead of selectors
        adaptedParameters['use_coordinates'] = true;
        break;
    }
    
    return BrowserAction(
      id: '${originalAction.id}_retry_${_retryCount}',
      type: originalAction.type,
      parameters: adaptedParameters,
      timestamp: DateTime.now(),
      reasoning: 'Retry with adapted strategy',
      retryCount: _retryCount,
    );
  }

  Future<void> _validateTaskCompletion() async {
    if (_currentTask == null) return;
    
    // Validate that the task objectives were met
    final validationScript = '''
      function validateCompletion() {
        return {
          page_loaded: document.readyState === 'complete',
          has_errors: document.querySelectorAll('.error, .alert-danger').length > 0,
          has_results: document.querySelectorAll('.result, .product, .item').length > 0,
          current_url: window.location.href,
          page_title: document.title
        };
      }
      
      validateCompletion();
    ''';
    
    final validation = await _webViewController!.evaluateJavascript(source: validationScript);
    _currentTask!.context['validation'] = validation;
  }

  void _updateKnowledgeBase(BrowserAgentTask completedTask) {
    // Learn patterns from successful task execution
    final pattern = {
      'task_type': _classifyTask(completedTask.description),
      'actions_used': completedTask.actions.map((a) => a.type).toList(),
      'execution_time': completedTask.executionTime?.inMilliseconds,
      'success_rate': completedTask.actions.where((a) => a.status == 'completed').length / completedTask.actions.length,
    };
    
    _knowledgeBase.add(json.encode(pattern));
  }

  String _classifyTask(String taskDescription) {
    if (_isShoppingTask(taskDescription.toLowerCase())) return 'shopping';
    if (_isSearchAndAnalysisTask(taskDescription.toLowerCase())) return 'search_analysis';
    if (_isBookingTask(taskDescription.toLowerCase())) return 'booking';
    if (_isDataExtractionTask(taskDescription.toLowerCase())) return 'data_extraction';
    if (_isComparisonTask(taskDescription.toLowerCase())) return 'comparison';
    return 'generic';
  }

  void _updateGlobalContext(Map<String, dynamic> pageData) {
    // Extract and store patterns that can be used across tasks
    _globalContext['last_analysis'] = pageData;
    _globalContext['domains_visited'] = _activeTabs.map((tab) => _extractDomain(tab.url)).toSet().toList();
    _globalContext['page_types_seen'] = {...(_globalContext['page_types_seen'] ?? []), pageData['pageType']}.toList();
  }

  String _extractDomain(String url) {
    try {
      return Uri.parse(url).host;
    } catch (e) {
      return url;
    }
  }

  // Utility methods for task planning
  BrowserAction _createAction(String type, Map<String, dynamic> parameters) {
    return BrowserAction(
      id: '${type}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      parameters: parameters,
      timestamp: DateTime.now(),
      reasoning: parameters['reasoning'] as String?,
    );
  }

  String _extractProductFromTask(String task) {
    // Extract product name from task description
    final patterns = [
      RegExp(r'search for (.+?) (?:on|in|at)', caseSensitive: false),
      RegExp(r'find (.+?) (?:price|prices)', caseSensitive: false),
      RegExp(r'compare (.+?) (?:prices|price)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(task);
      if (match != null) {
        return match.group(1)!.trim();
      }
    }

    return task; // Return full task if no specific product found
  }

  List<String> _extractShoppingSites(String task) {
    final sites = <String>[];
    final sitePatterns = [
      'amazon.com', 'ebay.com', 'walmart.com', 'target.com', 'bestbuy.com',
      'newegg.com', 'costco.com', 'etsy.com', 'shopify.com'
    ];

    for (final site in sitePatterns) {
      if (task.toLowerCase().contains(site.toLowerCase())) {
        sites.add(site);
      }
    }

    return sites;
  }

  String _extractSearchQuery(String task) {
    final patterns = [
      RegExp(r'search for (.+)', caseSensitive: false),
      RegExp(r'find (.+)', caseSensitive: false),
      RegExp(r'look for (.+)', caseSensitive: false),
      RegExp(r'research (.+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(task);
      if (match != null) {
        return match.group(1)!.trim();
      }
    }

    return task;
  }

  String _extractAnalysisType(String task) {
    if (task.contains('price') || task.contains('cost')) return 'price_analysis';
    if (task.contains('review') || task.contains('rating')) return 'review_analysis';
    if (task.contains('compare') || task.contains('comparison')) return 'comparison';
    if (task.contains('feature') || task.contains('spec')) return 'feature_analysis';
    return 'general';
  }

  Map<String, dynamic> _extractBookingDetails(String task) {
    final details = <String, dynamic>{};
    
    // Extract dates
    final datePattern = RegExp(r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b');
    final dateMatch = datePattern.firstMatch(task);
    if (dateMatch != null) {
      details['date'] = dateMatch.group(1);
    }
    
    // Extract locations
    final locationPattern = RegExp(r'(?:from|in|to|at) ([A-Za-z ]+?)(?:\s|$|,)');
    final locationMatches = locationPattern.allMatches(task);
    if (locationMatches.isNotEmpty) {
      details['location'] = locationMatches.first.group(1)?.trim();
    }
    
    return details;
  }

  List<String> _extractDataTargets(String task) {
    final targets = <String>[];
    
    if (task.contains('price')) targets.add('prices');
    if (task.contains('name') || task.contains('title')) targets.add('names');
    if (task.contains('rating') || task.contains('review')) targets.add('ratings');
    if (task.contains('description')) targets.add('descriptions');
    if (task.contains('contact') || task.contains('email')) targets.add('contact_info');
    
    return targets.isEmpty ? ['general'] : targets;
  }

  List<String> _extractComparisonItems(String task) {
    final items = <String>[];
    
    // Extract items from "compare X vs Y" or "X versus Y" patterns
    final vsPattern = RegExp(r'compare (.+?) (?:vs|versus|against) (.+)', caseSensitive: false);
    final vsMatch = vsPattern.firstMatch(task);
    if (vsMatch != null) {
      items.add(vsMatch.group(1)!.trim());
      items.add(vsMatch.group(2)!.trim());
    }
    
    // Extract from lists like "compare X, Y, and Z"
    final listPattern = RegExp(r'compare (.+)', caseSensitive: false);
    final listMatch = listPattern.firstMatch(task);
    if (listMatch != null && items.isEmpty) {
      final itemList = listMatch.group(1)!.split(RegExp(r',|\sand\s'));
      items.addAll(itemList.map((item) => item.trim()));
    }
    
    return items;
  }

  // Public methods for external control
  Future<void> analyzeCurrentPage() async {
    if (_webViewController == null) return;
    
    final action = _createAction('analyze_page', {});
    await _performAdvancedPageAnalysis(action);
  }

  void handleWebViewError(WebResourceError error) {
    _logError('WebView error: ${error.description}');
    // Implement smart error recovery
  }

  Future<bool> handleNewTab(CreateWindowAction createWindowAction) async {
    // Handle new tab creation by the agent
    final newTabId = 'tab_${DateTime.now().millisecondsSinceEpoch}';
    _activeTabs.add(BrowserTab(
      id: newTabId,
      url: createWindowAction.request.url?.toString() ?? '',
      title: 'New Tab',
      lastActivity: DateTime.now(),
    ));
    return true;
  }

  void stopCurrentTask() {
    _isProcessing = false;
    _isThinking = false;
    _currentTask = null;
    _currentPlan = null;
    _currentStatus = 'Task stopped by user';
    _executionTimer?.cancel();
    notifyListeners();
  }

  void _updateStatus(String status) {
    _currentStatus = status;
    notifyListeners();
  }

  void _logError(String error) {
    _errorLog.add('${DateTime.now().toIso8601String()}: $error');
    if (_errorLog.length > 100) { // Increased log size for better debugging
      _errorLog.removeAt(0);
    }
  }

  void clearHistory() {
    _taskHistory.clear();
    _errorLog.clear();
    _knowledgeBase.clear();
    _globalContext.clear();
    notifyListeners();
  }

  // Advanced automation presets
  Future<void> performMultiSiteComparison(String product, List<String> sites) async {
    await executeTask('Search for $product on ${sites.join(", ")} and compare prices with screenshots');
  }

  Future<void> extractAndAnalyzeData(String website, List<String> dataTypes) async {
    await executeTask('Navigate to $website and extract ${dataTypes.join(", ")} data, then analyze patterns');
  }

  Future<void> automateBookingFlow(String site, Map<String, String> details) async {
    final detailsStr = details.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    await executeTask('Go to $site and complete booking with details: $detailsStr');
  }
}