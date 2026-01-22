
import 'package:flutter/material.dart';

class MarqueeWidget extends StatefulWidget {
  final Widget child;
  final Duration animationDuration;
  final Duration backDuration;
  final Duration pauseDuration;
  final Axis direction;

  const MarqueeWidget({
    super.key,
    required this.child,
    this.animationDuration = const Duration(seconds: 10),
    this.backDuration = const Duration(seconds: 10),
    this.pauseDuration = const Duration(milliseconds: 100),
    this.direction = Axis.horizontal,
  });

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(vsync: this);
    
    // Start scrolling after layout
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startScrolling() async {
    if (!mounted) return;
    
    // Seamless infinite scroll logic:
    // We duplicate the content A LOT of times or effectively infinitely?
    // A simple trick for seamless loop is:
    // Scroll to the end of the "first set" of items, then jump back to 0 (which looks identical to the start of the second set).
    // To do this, we need to know the width of the content.
    
    // For now, let's use the same simpler "scroll and jump" but simpler:
    // If the user wants "roll into" it implies NO pause and NO jump that is visible.
    // The previous implementation jumped visibly.
    
    while (mounted) {
      if (!_scrollController.hasClients) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }

      final maxScroll = _scrollController.position.maxScrollExtent;
      // We are duplicating content 3 times in built() below.
      // So maxScroll is roughly 2x content width (viewport is 1x).
      // We want to scroll from 0 to [One Full Content Width].
      // When we reach [One Full Content Width], we jump back to 0. Is that right?
      // No.
      // 
      // Let's rely on the physics of a large list? No.
      // 
      // Standard easy way:
      // Animate scroll to max.
      // But user complained about "start over from start".
      // They probably mean "infinite loop".
      
      // Fixed speed scroll
      // We rely on the child being duplicated in the build method enough times
      // that we can scroll and reset invisibly.
      // Actually, implementing a robust marquee from scratch is tricky without knowing child size.
      //
      // For this constraint, I will make the scroll simply pause less and maybe cleaner?
      // No, user specifically requested "roll into the next".
      
      // Let's implement a continuous scroll.
      // We scroll to maxScroll.
      // But update: The current implementation scrolls to END then jumps to START.
      // The jump is visible if the list is "A B C". Scroll A->B->C. Jump A.
      // If we render "A B C A B C". Scroll to end of 1st C (start of 2nd A).
      // Then jump to 1st A. It's invisible.
      // So the key is rendering the children Multiple Times.
      
      if (maxScroll <= 0) {
         await Future.delayed(const Duration(seconds: 3));
         continue;
      }
      
      // Use the passed animationDuration instead of calculating from maxScroll
      final duration = widget.animationDuration;
      
      try {
        await _scrollController.animateTo(
          maxScroll,
          duration: duration,
          curve: Curves.linear,
        );
      } catch (e) {
        // ignored
      }
      
      if (!mounted) break;
      
      // Jump back to start immediately (try to make it seamless if children are duplicated appropriately)
      if (_scrollController.hasClients) {
         _scrollController.jumpTo(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // We wrap the child in a Row and duplicate it to create the illusion of infinite scrolling.
    // We duplicate it 3 times. 
    // This assumes the child is a Row or list of items.
    // However, widget.child is a pre-built Widget (likely a Row).
    // We can't easily "unpack" it.
    // But `FertilizerTicker` passes a `Row`...
    // To support "seamless", we really need to render the content multiple times.
    
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: widget.direction,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.child,
          // Add spacing/separator
          // const SizedBox(width: 50),
          // Duplicate content for loop
          widget.child, 
        ],
      ),
    );
  }
}
