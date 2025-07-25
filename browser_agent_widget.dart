import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'browser_agent_service.dart';

class BrowserAgentWindow extends StatefulWidget {
  final BrowserAgentService agentService;

  const BrowserAgentWindow({
    super.key,
    required this.agentService,
  });

  @override
  State<BrowserAgentWindow> createState() => _BrowserAgentWindowState();
}

class _BrowserAgentWindowState extends State<BrowserAgentWindow>
    with TickerProviderStateMixin {
  InAppWebViewController? _webViewController;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  bool _isMinimized = false;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    widget.agentService.addListener(_onAgentServiceChanged);

    if (widget.agentService.isAgentActive) {
      _slideController.forward();
    }
  }

  @override
  void dispose() {
    widget.agentService.removeListener(_onAgentServiceChanged);
    _slideController.dispose();
    _pulseController.dispose();
    _taskController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _onAgentServiceChanged() {
    if (mounted) {
      setState(() {});

      if (widget.agentService.isAgentActive) {
        _slideController.forward();
        if (widget.agentService.isProcessing) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.reset();
        }
      } else {
        _slideController.reverse();
        _pulseController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.agentService.isAgentActive) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        height: _isMinimized ? 60 : MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F3F0),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildTitleBar(),
            if (!_isMinimized) ...[
              _buildStatusBar(),
              _buildControlPanel(),
              Expanded(child: _buildBrowserView()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar() {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Color(0xFFEAE9E5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          
          // Agent status indicator
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.agentService.isProcessing 
                    ? 1.0 + (_pulseAnimation.value * 0.2)
                    : 1.0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: widget.agentService.isProcessing
                        ? const Color(0xFF10B981)
                        : const Color(0xFF6B7280),
                    shape: BoxShape.circle,
                    boxShadow: widget.agentService.isProcessing
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(width: 12),
          
          // Title and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Browser Agent',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF000000),
                  ),
                ),
                if (widget.agentService.currentStatus.isNotEmpty)
                  Text(
                    widget.agentService.currentStatus,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          
          // Control buttons
          IconButton(
            onPressed: () {
              setState(() {
                _isMinimized = !_isMinimized;
              });
            },
            icon: Icon(
              _isMinimized ? Icons.expand_less : Icons.expand_more,
              color: const Color(0xFF6B7280),
            ),
          ),
          
          IconButton(
            onPressed: widget.agentService.toggleAgent,
            icon: const Icon(
              Icons.close,
              color: Color(0xFF6B7280),
            ),
          ),
          
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFFF4F3F0),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          
          // Current URL
          Expanded(
            child: Text(
              widget.agentService.currentUrl.isEmpty 
                  ? 'Ready to browse...' 
                  : widget.agentService.currentUrl,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF6B7280),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Task count indicator
          if (widget.agentService.taskHistory.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF000000).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${widget.agentService.taskHistory.length} tasks',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF000000),
                ),
              ),
            ),
          
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F3F0),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Column(
        children: [
          // URL input
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: TextField(
                    controller: _urlController,
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter website URL...',
                      hintStyle: GoogleFonts.inter(
                        color: const Color(0xFF9CA3AF),
                      ),
                      prefixIcon: const Icon(
                        Icons.language,
                        color: Color(0xFF6B7280),
                        size: 18,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (url) => _navigateToUrl(url),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.navigation,
                onPressed: () => _navigateToUrl(_urlController.text),
                tooltip: 'Navigate',
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Task input
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: TextField(
                    controller: _taskController,
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Tell the agent what to do...',
                      hintStyle: GoogleFonts.inter(
                        color: const Color(0xFF9CA3AF),
                      ),
                      prefixIcon: const Icon(
                        Icons.auto_awesome,
                        color: Color(0xFF6B7280),
                        size: 18,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (task) => _executeTask(task),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.play_arrow,
                onPressed: widget.agentService.isProcessing 
                    ? null 
                    : () => _executeTask(_taskController.text),
                tooltip: 'Execute Task',
                isPrimary: true,
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Quick actions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickAction('Screenshot', Icons.camera_alt, () {
                  _executeTask('Take a screenshot');
                }),
                _buildQuickAction('Analyze Page', Icons.analytics, () {
                  _executeTask('Analyze this page');
                }),
                _buildQuickAction('Find Forms', Icons.description, () {
                  _executeTask('Find and analyze forms on this page');
                }),
                _buildQuickAction('Scroll Down', Icons.keyboard_arrow_down, () {
                  _executeTask('Scroll down');
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    bool isPrimary = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFF000000) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary ? const Color(0xFF000000) : const Color(0xFFE5E7EB),
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: isPrimary ? Colors.white : const Color(0xFF6B7280),
          size: 18,
        ),
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildQuickAction(String label, IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: const Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrowserView() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri('https://www.google.com'),
          ),
          initialSettings: InAppWebViewSettings(
            useShouldOverrideUrlLoading: false,
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            iframeAllow: "camera; microphone",
            iframeAllowFullscreen: true,
          ),
          onWebViewCreated: (controller) {
            _webViewController = controller;
            widget.agentService.setWebViewController(controller);
          },
          onLoadStart: (controller, url) {
            if (mounted) {
              setState(() {});
            }
          },
          onProgressChanged: (controller, progress) {
            if (mounted) {
              setState(() {});
            }
          },
          onLoadStop: (controller, url) async {
            if (mounted) {
              setState(() {});
            }
          },
          onReceivedError: (controller, request, error) {
            print('WebView error: ${error.description}');
          },
          onConsoleMessage: (controller, consoleMessage) {
            print('Console: ${consoleMessage.message}');
          },
        ),
      ),
    );
  }

  void _navigateToUrl(String url) {
    if (url.trim().isEmpty) return;
    
    String formattedUrl = url.trim();
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }
    
    _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(formattedUrl)),
    );
    
    _urlController.clear();
  }

  void _executeTask(String task) {
    if (task.trim().isEmpty || widget.agentService.isProcessing) return;
    
    widget.agentService.executeTask(task.trim());
    _taskController.clear();
    
    // Give haptic feedback
    HapticFeedback.lightImpact();
  }
}

// Floating Agent Toggle Button
class BrowserAgentToggle extends StatefulWidget {
  final BrowserAgentService agentService;

  const BrowserAgentToggle({
    super.key,
    required this.agentService,
  });

  @override
  State<BrowserAgentToggle> createState() => _BrowserAgentToggleState();
}

class _BrowserAgentToggleState extends State<BrowserAgentToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    widget.agentService.addListener(_onAgentServiceChanged);
  }

  @override
  void dispose() {
    widget.agentService.removeListener(_onAgentServiceChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onAgentServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 100,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: () {
          widget.agentService.toggleAgent();
          HapticFeedback.mediumImpact();
        },
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: widget.agentService.isAgentActive
                      ? const Color(0xFF000000)
                      : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  border: Border.all(
                    color: widget.agentService.isAgentActive
                        ? const Color(0xFF000000)
                        : const Color(0xFFE5E7EB),
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.smart_toy_outlined,
                        color: widget.agentService.isAgentActive
                            ? Colors.white
                            : const Color(0xFF6B7280),
                        size: 28,
                      ),
                    ),
                    if (widget.agentService.isProcessing)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withOpacity(0.6),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}