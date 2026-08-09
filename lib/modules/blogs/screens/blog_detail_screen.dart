import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:snore_clinics/core/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/blog_model.dart';
import '../services/blog_service.dart';
import '../../../core/providers/theme_provider.dart';
import 'package:intl/intl.dart';

class BlogDetailScreen extends StatefulWidget {
  final BlogModel blog;
  const BlogDetailScreen({super.key, required this.blog});

  @override
  State<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends State<BlogDetailScreen> {
  late bool isLiked;
  late bool isBookmarked;
  late int likesCount;
  late int bookmarksCount;
  
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    isLiked = widget.blog.likes.contains(_uid);
    isBookmarked = widget.blog.bookmarks.contains(_uid);
    likesCount = widget.blog.likes.length;
    bookmarksCount = widget.blog.bookmarks.length;
  }

  Future<void> _toggleReaction(String field) async {
    if (_uid.isEmpty) return;
    
    setState(() {
      if (field == 'likes') {
        if (isLiked) {
          likesCount--;
          isLiked = false;
        } else {
          likesCount++;
          isLiked = true;
        }
      } else {
        if (isBookmarked) {
          bookmarksCount--;
          isBookmarked = false;
        } else {
          bookmarksCount++;
          isBookmarked = true;
        }
      }
    });
    
    await BlogService.toggleReaction(widget.blog.id, field);
  }

  /// Converts plain Word-pasted text into proper Markdown for rendering.
  static String _convertToMarkdown(String raw) {
    if (raw.trim().isEmpty) return raw;

    String text = raw;

    // Step 1: Normalize all bullet variants (•, ·, ▪, ●, etc.) surrounded by
    // optional whitespace into a newline + markdown list marker.
    // This handles both " • item" and "• item" patterns.
    text = text.replaceAllMapped(
      RegExp(r'\s*[•·▪▸●○◦‣➤]\s*'),
      (_) => '\n- ',
    );

    // Step 2: Add paragraph breaks.
    // When a sentence ends with . ! ? and is immediately followed by a capital
    // letter (or a digit starting a new sentence), insert a blank line.
    text = text.replaceAllMapped(
      RegExp(r'([.!?])\s+(?=[A-Z0-9])'),
      (m) => '${m[1]}\n\n',
    );

    // Step 3: Split into lines and detect headings.
    // A heading is a line that:
    //   - Is ≤ 80 characters
    //   - Starts with a capital letter
    //   - Does NOT end with . , ; or )
    //   - Is not a list item
    //   - Has a blank line before or after it (common heading pattern)
    final lines = text.split('\n');
    final out = <String>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty) {
        out.add('');
        continue;
      }

      if (line.startsWith('- ')) {
        // Already a list item — keep as-is
        out.add(line);
        continue;
      }

      final isShort = line.length <= 80;
      final startsWithCapital = RegExp(r'^[A-Z]').hasMatch(line);
      final endsWithPunct = RegExp(r'[.,;:?!)]$').hasMatch(line);
      final prevBlank = i == 0 || out.isNotEmpty && out.last.trim().isEmpty;
      final nextBlank = (i + 1 < lines.length) && lines[i + 1].trim().isEmpty;
      final nextIsList = (i + 1 < lines.length) && lines[i + 1].trim().startsWith('- ');

      if (isShort && startsWithCapital && !endsWithPunct && (prevBlank || nextBlank || nextIsList)) {
        out.add('## $line');
      } else {
        out.add(line);
      }
    }

    // Step 4: Collapse 3+ consecutive blank lines down to 2.
    final collapsed = <String>[];
    int blankCount = 0;
    for (final line in out) {
      if (line.trim().isEmpty) {
        blankCount++;
        if (blankCount <= 2) collapsed.add('');
      } else {
        blankCount = 0;
        collapsed.add(line);
      }
    }

    return collapsed.join('\n');
  }


  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg = isLight ? AppTheme.backgroundLight : AppTheme.background;
    final textPrimary = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final textSecondary = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
    final surfaceElevated = isLight ? AppTheme.surfaceLight : AppTheme.surfaceElevated;
    final cardBorder = isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── App Bar with Hero Image ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: bg,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                    onPressed: () {
                      Share.share('Check out "${widget.blog.title}" on Sleep Astra! Download the app: https://play.google.com/store/apps/details?id=com.snoreclinics.app');
                    },
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: widget.blog.coverImageUrl.isNotEmpty
                  ? Image.network(
                      widget.blog.coverImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
          ),

          // ── Blog Content ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta Info
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.blog.category.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.primaryIndigo,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.schedule_rounded, color: textSecondary, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.blog.readTimeMinutes} min read',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    widget.blog.title,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Author & Date
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: surfaceElevated,
                        radius: 20,
                        child: Icon(Icons.person, color: textSecondary),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.blog.author,
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            DateFormat.yMMMd().format(widget.blog.createdAt),
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(color: cardBorder),
                  const SizedBox(height: 24),
                  
                  // Markdown Content
                  MarkdownBody(
                    data: _convertToMarkdown(widget.blog.content),
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(color: textPrimary, fontSize: 16, height: 1.8),
                      h1: TextStyle(
                        color: textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 2.0,
                      ),
                      h2: TextStyle(
                        color: textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 2.0,
                      ),
                      h3: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 2.0,
                      ),
                      listBullet: TextStyle(color: AppTheme.primaryIndigo, fontSize: 16, height: 1.8),
                      listIndent: 20,
                      blockSpacing: 16,
                      pPadding: const EdgeInsets.only(bottom: 8),
                      h2Padding: const EdgeInsets.only(top: 16, bottom: 8),
                      h3Padding: const EdgeInsets.only(top: 12, bottom: 4),
                      strong: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      em: TextStyle(
                        color: textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      blockquote: TextStyle(
                        color: textSecondary,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        height: 1.6,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: AppTheme.primaryIndigo, width: 4),
                        ),
                        color: surfaceElevated,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      horizontalRuleDecoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: cardBorder, width: 1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: surfaceElevated,
          border: Border(top: BorderSide(color: cardBorder)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ReactionButton(
              icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              label: '$likesCount',
              color: isLiked ? Colors.redAccent : textSecondary,
              onTap: () => _toggleReaction('likes'),
            ),
            _ReactionButton(
              icon: isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              label: '$bookmarksCount',
              color: isBookmarked ? AppTheme.primaryIndigo : textSecondary,
              onTap: () => _toggleReaction('bookmarks'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
      child: const Center(
        child: Icon(Icons.image_outlined, color: AppTheme.primaryIndigo, size: 64),
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
