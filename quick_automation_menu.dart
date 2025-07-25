import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'browser_agent_service.dart';

class QuickAutomationMenu extends StatefulWidget {
  final BrowserAgentService agentService;

  const QuickAutomationMenu({
    super.key,
    required this.agentService,
  });

  @override
  State<QuickAutomationMenu> createState() => _QuickAutomationMenuState();
}

class _QuickAutomationMenuState extends State<QuickAutomationMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void showQuickMenu(BuildContext context) {
    _controller.forward();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildQuickMenu(),
    ).then((_) => _controller.reverse());
  }

  Widget _buildQuickMenu() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFF4F3F0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC4C4C4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.flash_on,
                        color: const Color(0xFF000000),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Quick Automation',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF000000),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Categories
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildCategory('🎫 Entertainment', [
                          AutomationTemplate(
                            'Movie Tickets',
                            'Search and book movie tickets',
                            'Navigate to fandango.com and search for latest Marvel movies',
                            Icons.movie,
                          ),
                          AutomationTemplate(
                            'Concert Tickets',
                            'Find concert tickets',
                            'Go to ticketmaster.com and search for upcoming concerts in my area',
                            Icons.music_note,
                          ),
                          AutomationTemplate(
                            'Event Discovery',
                            'Discover local events',
                            'Open eventbrite.com and browse events happening this weekend',
                            Icons.event,
                          ),
                        ]),

                        _buildCategory('✈️ Travel', [
                          AutomationTemplate(
                            'Flight Search',
                            'Compare flight prices',
                            'Navigate to google.com/flights and search for round-trip flights from NYC to LA',
                            Icons.flight,
                          ),
                          AutomationTemplate(
                            'Hotel Booking',
                            'Find and book hotels',
                            'Go to booking.com and search for 4+ star hotels in Paris for next weekend',
                            Icons.hotel,
                          ),
                          AutomationTemplate(
                            'Car Rental',
                            'Compare car rental prices',
                            'Open kayak.com and search for car rentals at LAX airport',
                            Icons.car_rental,
                          ),
                        ]),

                        _buildCategory('🛍️ Shopping', [
                          AutomationTemplate(
                            'Price Comparison',
                            'Compare product prices',
                            'Search for iPhone 15 Pro on amazon.com and compare prices',
                            Icons.shopping_cart,
                          ),
                          AutomationTemplate(
                            'Deal Hunting',
                            'Find best deals',
                            'Navigate to slickdeals.com and browse today\'s hottest deals',
                            Icons.local_offer,
                          ),
                          AutomationTemplate(
                            'Product Reviews',
                            'Read product reviews',
                            'Go to reddit.com and search for reviews of the latest MacBook',
                            Icons.rate_review,
                          ),
                        ]),

                        _buildCategory('💼 Professional', [
                          AutomationTemplate(
                            'Job Search',
                            'Find job opportunities',
                            'Navigate to linkedin.com and search for software engineer jobs with remote options',
                            Icons.work,
                          ),
                          AutomationTemplate(
                            'LinkedIn Networking',
                            'Expand professional network',
                            'Go to linkedin.com and browse people in my industry',
                            Icons.people,
                          ),
                          AutomationTemplate(
                            'Market Research',
                            'Research competitors',
                            'Search for tech startups in AI space and analyze their offerings',
                            Icons.analytics,
                          ),
                        ]),

                        _buildCategory('📚 Learning', [
                          AutomationTemplate(
                            'Course Discovery',
                            'Find online courses',
                            'Navigate to coursera.org and browse machine learning courses',
                            Icons.school,
                          ),
                          AutomationTemplate(
                            'Tutorial Search',
                            'Find programming tutorials',
                            'Go to youtube.com and search for Flutter app development tutorials',
                            Icons.play_circle,
                          ),
                          AutomationTemplate(
                            'Documentation',
                            'Access technical docs',
                            'Navigate to flutter.dev and browse the latest documentation',
                            Icons.description,
                          ),
                        ]),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategory(String title, List<AutomationTemplate> templates) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF000000),
            ),
          ),
        ),
        ...templates.map((template) => _buildTemplateCard(template)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTemplateCard(AutomationTemplate template) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _executeTemplate(template),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F3F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    template.icon,
                    color: const Color(0xFF000000),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF000000),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        template.description,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: const Color(0xFFE5E7EB),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _executeTemplate(AutomationTemplate template) {
    Navigator.pop(context);
    
    // Activate browser agent if not active
    if (!widget.agentService.isAgentActive) {
      widget.agentService.toggleAgent();
    }

    // Execute the automation task
    widget.agentService.executeTask(template.command);
    
    // Provide haptic feedback
    HapticFeedback.mediumImpact();
  }
}

class AutomationTemplate {
  final String title;
  final String description;
  final String command;
  final IconData icon;

  AutomationTemplate(this.title, this.description, this.command, this.icon);
}

// Enhanced floating button that can trigger quick menu
class SmartBrowserAgentToggle extends StatefulWidget {
  final BrowserAgentService agentService;

  const SmartBrowserAgentToggle({
    super.key,
    required this.agentService,
  });

  @override
  State<SmartBrowserAgentToggle> createState() => _SmartBrowserAgentToggleState();
}

class _SmartBrowserAgentToggleState extends State<SmartBrowserAgentToggle>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    widget.agentService.addListener(_onAgentServiceChanged);
    
    if (widget.agentService.isProcessing) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    widget.agentService.removeListener(_onAgentServiceChanged);
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onAgentServiceChanged() {
    if (mounted) {
      setState(() {});
      if (widget.agentService.isProcessing) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 100,
      child: Column(
        children: [
          // Quick menu button
          if (widget.agentService.isAgentActive)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  final quickMenu = QuickAutomationMenu(agentService: widget.agentService);
                  quickMenu.showQuickMenu(context);
                  HapticFeedback.lightImpact();
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.flash_on,
                    color: Color(0xFF6B7280),
                    size: 22,
                  ),
                ),
              ),
            ),

          // Main toggle button
          GestureDetector(
            onTapDown: (_) => _controller.forward(),
            onTapUp: (_) => _controller.reverse(),
            onTapCancel: () => _controller.reverse(),
            onTap: () {
              widget.agentService.toggleAgent();
              HapticFeedback.mediumImpact();
            },
            child: AnimatedBuilder(
              animation: Listenable.merge([_scaleAnimation, _pulseAnimation]),
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value * 
                         (widget.agentService.isProcessing ? _pulseAnimation.value : 1.0),
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
        ],
      ),
    );
  }
}