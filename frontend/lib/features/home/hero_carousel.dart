import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/cms_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/brand_logo.dart';
import '../../models/gallery.dart';
import '../../repositories/cms_repository.dart';
import '../../repositories/gallery_repository.dart';
import '../../services/api/api_response.dart';

/// The homepage hero: five slides, all editable through the CMS.
///
/// Two things this had to get right.
///
/// First, it must look finished on day one. The image slots are empty until the
/// Media Team attaches approved photographs of Ekoli-Yeden, so a slide with no
/// image draws a branded panel in the community's own colours rather than a
/// grey box or a broken-image icon. The page improves as real photographs
/// arrive; it is never embarrassing before they do.
///
/// Second, autoplay must not fight the visitor. It pauses on hover, pauses on
/// focus, stops permanently once someone uses the arrows or dots, and never
/// starts at all when the operating system asks for reduced motion.
class HeroCarousel extends StatefulWidget {
  const HeroCarousel({super.key});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;
  bool _paused = false;

  /// Set once the visitor operates the carousel themselves. Autoplay never
  /// resumes after that — taking control back would be rude.
  bool _userTookControl = false;

  static const Duration _interval = Duration(seconds: 7);

  /// Photographs drawn from the archive to stand behind slides that have no
  /// image of their own.
  ///
  /// ---------------------------------------------------------------------
  /// WHY THE ARCHIVE'S OWN PICTURES, CHOSEN AT RANDOM
  /// ---------------------------------------------------------------------
  ///
  /// The hero slots were meant to be filled by the Media Team one at a time,
  /// and until they are the homepage shows five coloured panels. Meanwhile the
  /// archive fills up with photographs nobody sees on the front page.
  ///
  /// So the front page borrows from what is already published. It changes as
  /// the community contributes, which is the honest impression to give — this
  /// is a living archive, and the homepage should look like one.
  ///
  /// SHUFFLED ONCE PER VISIT, not per rebuild. A carousel whose backgrounds
  /// changed every time Flutter repainted would be unusable.
  List<Photograph> _pool = const <Photograph>[];
  bool _poolRequested = false;

  Future<void> _loadPool() async {
    if (_poolRequested) return;
    _poolRequested = true;

    try {
      final PaginatedResult<Photograph> result =
          await context.read<GalleryRepository>().photographs(perPage: 24);

      // Stills only. A video frame cannot be used as a background image, and
      // asking a browser to decode one behind text on a phone is worse still.
      final List<Photograph> stills =
          result.items.where((Photograph p) => !p.isVideo).toList();
      stills.shuffle();

      if (mounted) setState(() => _pool = stills);
    } catch (_) {
      // A hero that cannot reach the archive falls back to the branded panels,
      // which is exactly what it did before. Never an error on the front page.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoplay(int slideCount) {
    _timer?.cancel();
    if (slideCount < 2 || _userTookControl) return;

    _timer = Timer.periodic(_interval, (_) {
      if (!mounted || _paused) return;
      final int next = (_index + 1) % slideCount;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _goTo(int index, int slideCount) {
    setState(() {
      _userTookControl = true;
      _timer?.cancel();
    });
    _controller.animateToPage(
      (index + slideCount) % slideCount,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final CmsController cms = context.watch<CmsController>();
    final List<HeroSlide> slides = cms.heroSlides.isEmpty ? _fallbackSlides : cms.heroSlides;

    // Deferred: `context.read` is not safe during build itself.
    if (!_poolRequested) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPool());
    }

    // The platform's own accessibility setting wins over our animation.
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!reduceMotion && _timer == null && !_userTookControl) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoplay(slides.length));
    }

    final double height = context.responsive<double>(
      mobile: 520,
      tablet: 560,
      laptop: 600,
      desktop: 640,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _paused = true),
      onExit: (_) => setState(() => _paused = false),
      child: FocusableActionDetector(
        // Pausing on focus matters for keyboard users: a slide changing under
        // them while they tab through its buttons would be disorienting.
        onFocusChange: (bool focused) => setState(() => _paused = focused),
        child: Semantics(
          label: 'Featured highlights from the Ekoli Yeden Digital Home',
          container: true,
          child: SizedBox(
            height: height,
            child: Stack(
              children: <Widget>[
                PageView.builder(
                  controller: _controller,
                  itemCount: slides.length,
                  onPageChanged: (int index) => setState(() => _index = index),
                  itemBuilder: (BuildContext context, int index) => _Slide(
                    slide: slides[index],
                    position: index,
                    // A slide keeps its own image where the Media Team set
                    // one. The archive only fills the empty slots.
                    borrowedImageUrl: slides[index].hasImage || _pool.isEmpty
                        ? null
                        : _pool[index % _pool.length].url,
                  ),
                ),
                if (slides.length > 1) ...<Widget>[
                  _ArrowButton(
                    alignment: Alignment.centerLeft,
                    icon: Icons.chevron_left,
                    tooltip: 'Previous slide',
                    onPressed: () => _goTo(_index - 1, slides.length),
                  ),
                  _ArrowButton(
                    alignment: Alignment.centerRight,
                    icon: Icons.chevron_right,
                    tooltip: 'Next slide',
                    onPressed: () => _goTo(_index + 1, slides.length),
                  ),
                  Positioned(
                    bottom: AppSpacing.xl,
                    left: 0,
                    right: 0,
                    child: _Indicators(
                      count: slides.length,
                      current: _index,
                      onSelected: (int index) => _goTo(index, slides.length),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown before the CMS has loaded, or if it cannot be reached.
///
/// The homepage must never render an empty hero, so these mirror the five
/// slides seeded by the migration.
const List<HeroSlide> _fallbackSlides = <HeroSlide>[
  HeroSlide(
    slideNumber: 1,
    eyebrow: 'Welcome to',
    title: 'EKOLI YEDEN DIGITAL HOME',
    description: 'Preserving Our Past. Celebrating Our Present. Building Our Future.',
    primaryButtonLabel: 'Explore Our Heritage',
    primaryButtonPath: '/history',
    secondaryButtonLabel: 'Contribute to Ekoli-Yeden',
    secondaryButtonPath: '/contribute',
  ),
  HeroSlide(
    slideNumber: 2,
    eyebrow: 'Our story',
    title: 'Our History',
    description:
        'The origins, migrations, institutions and events that made this community — recorded '
        'with their sources and checked before they are published.',
    primaryButtonLabel: 'Read our history',
    primaryButtonPath: '/history',
  ),
  HeroSlide(
    slideNumber: 3,
    eyebrow: 'How we live',
    title: 'Our Culture',
    description:
        'Traditions, festivals, food, dress, farming, proverbs and the practices carried from '
        'one generation to the next.',
    primaryButtonLabel: 'Explore our culture',
    primaryButtonPath: '/culture',
  ),
  HeroSlide(
    slideNumber: 4,
    eyebrow: 'Who we are',
    title: 'Our People',
    description:
        'Scholars, farmers, professionals, artists and community builders — at home and across '
        'the world.',
    primaryButtonLabel: 'Meet our people',
    primaryButtonPath: '/people',
  ),
  HeroSlide(
    slideNumber: 5,
    eyebrow: 'What comes next',
    title: 'Our Future',
    description:
        'What we preserve today is what our children will inherit. Help us record it while it '
        'can still be recorded.',
    primaryButtonLabel: 'Contribute Materials',
    primaryButtonPath: '/contribute',
    secondaryButtonLabel: 'Join the Preservation Team',
    secondaryButtonPath: '/preservation-team',
  ),
];

class _Slide extends StatelessWidget {
  const _Slide({
    required this.slide,
    required this.position,
    this.borrowedImageUrl,
  });

  final HeroSlide slide;
  final int position;

  /// A photograph borrowed from the archive because this slide has none of its
  /// own. Unknown brightness and unknown composition, which is why the scrim
  /// below is heavier when one is in use.
  final String? borrowedImageUrl;

  bool get _hasAnyImage => slide.hasImage || borrowedImageUrl != null;

  /// Each slide gets its own gradient from the brand palette, so the carousel
  /// reads as five distinct panels rather than one repeated background while
  /// the photographs are still being collected.
  static const List<List<Color>> _gradients = <List<Color>>[
    <Color>[AppColors.navyDark, AppColors.navy],
    <Color>[AppColors.navy, AppColors.navyLight],
    <Color>[AppColors.greenDark, AppColors.green],
    <Color>[AppColors.navy, AppColors.greenDark],
    <Color>[AppColors.goldDark, AppColors.navy],
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool mobile = context.isMobile;
    final List<Color> gradient = _gradients[position % _gradients.length];

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (_hasAnyImage)
          Image.network(
            slide.imageUrl ?? borrowedImageUrl!,
            fit: BoxFit.cover,
            semanticLabel: slide.imageAltText ?? slide.title,
            errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                _GradientPanel(colors: gradient),
            loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? progress) =>
                progress == null ? child : _GradientPanel(colors: gradient),
          )
        else
          _GradientPanel(colors: gradient),

        // SCRIM — two layers, because the text has to stay readable over a
        // photograph nobody chose for this purpose.
        //
        // A slide the Media Team set can be trusted: they picked it knowing
        // words would sit on it. One borrowed at random from the archive
        // cannot — it may be a bright sky, a white shirt, a pale wall. So the
        // borrowed case gets a heavier wash and a floor underneath it, and
        // legibility wins over seeing the picture perfectly.
        if (_hasAnyImage)
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: borrowedImageUrl != null ? 0.28 : 0.0),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                Colors.black.withValues(
                  alpha: !_hasAnyImage ? 0.30 : (borrowedImageUrl != null ? 0.82 : 0.72),
                ),
                Colors.black.withValues(
                  alpha: !_hasAnyImage ? 0.05 : (borrowedImageUrl != null ? 0.45 : 0.35),
                ),
              ],
            ),
          ),
        ),

        PageWidthContainer(
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (position == 0) ...<Widget>[
                    const BrandLogo(size: 84, onDarkBackground: true),
                    const Gap.xl(),
                  ],
                  if (slide.eyebrow != null) ...<Widget>[
                    Text(
                      slide.eyebrow!.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.goldLight,
                        letterSpacing: 2.4,
                      ),
                    ),
                    const Gap.md(),
                  ],
                  Text(
                    slide.title,
                    style: (mobile ? theme.textTheme.displaySmall : theme.textTheme.displayLarge)
                        ?.copyWith(color: Colors.white, height: 1.05),
                  ),
                  if (slide.description != null) ...<Widget>[
                    const Gap.lg(),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Text(
                        slide.description!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.94),
                          fontSize: mobile ? 16 : 19,
                        ),
                      ),
                    ),
                  ],
                  if (slide.hasPrimaryButton || slide.hasSecondaryButton) ...<Widget>[
                    const Gap.xxl(),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: <Widget>[
                        if (slide.hasPrimaryButton)
                          FilledButton(
                            onPressed: () => context.go(slide.primaryButtonPath!),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(slide.primaryButtonLabel!),
                          ),
                        if (slide.hasSecondaryButton)
                          OutlinedButton(
                            onPressed: () => context.go(slide.secondaryButtonPath!),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white70),
                            ),
                            child: Text(slide.secondaryButtonLabel!),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientPanel extends StatelessWidget {
  const _GradientPanel({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.alignment,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Alignment alignment;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Material(
          color: Colors.black.withValues(alpha: 0.32),
          shape: const CircleBorder(),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            tooltip: tooltip,
            onPressed: onPressed,
            // A comfortable target on a phone.
            iconSize: 28,
            padding: const EdgeInsets.all(AppSpacing.sm),
          ),
        ),
      ),
    );
  }
}

class _Indicators extends StatelessWidget {
  const _Indicators({
    required this.count,
    required this.current,
    required this.onSelected,
  });

  final int count;
  final int current;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(count, (int index) {
        final bool active = index == current;
        return Semantics(
          button: true,
          selected: active,
          label: 'Slide ${index + 1} of $count',
          child: InkWell(
            onTap: () => onSelected(index),
            borderRadius: AppRadius.pillAll,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: active ? 32 : 10,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? AppColors.gold : Colors.white.withValues(alpha: 0.55),
                  borderRadius: AppRadius.pillAll,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
