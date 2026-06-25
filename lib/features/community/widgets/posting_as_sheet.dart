// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/utils/globals.dart';
import '../../../services/anonymous_id_service.dart';
import '../../../models/user_profile.dart';
import '../board_theme.dart';

/// Result returned from [showPostingAsSheet] when the user makes a choice.
class AliasSelection {
  final String alias;
  final bool hasCustomAlias;
  final bool remember;
  final bool isAnonymous;

  const AliasSelection({
    required this.alias,
    required this.hasCustomAlias,
    required this.remember,
    required this.isAnonymous,
  });
}

/// Shared "Posting as" alias bottom sheet used by both the post composer
/// and the comment composer.
///
/// Returns `null` if the sheet was dismissed without choosing.
Future<dynamic> showPostingAsSheet(
  BuildContext context, {
  required String currentAlias,
  required bool hasCustomAlias,
  UserProfile? userProfile,
  bool initialIsAnonymous = true,
}) {
  final controller = TextEditingController(
    text: (hasCustomAlias && userProfile?.username != currentAlias) ? currentAlias : '',
  );
  bool rememberOnDevice = true;
  bool isAnonymousSelected = userProfile == null ? true : initialIsAnonymous;

  return showModalBottomSheet<dynamic>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final isRegistered = userProfile != null;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: BoardColors.paper,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle indicator
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: BoardColors.line,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Posting Identity', style: BoardText.roomTitle),
                  const SizedBox(height: 6),
                  Text(
                    isRegistered
                        ? 'Select whether to use your verified profile or stay anonymous.'
                        : 'This is public display text only. It is not an account.',
                    style: BoardText.body.copyWith(color: BoardColors.muted),
                  ),
                  if (!isRegistered) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        Navigator.of(context).pop('show_auth');
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FaIcon(
                            FontAwesomeIcons.circleUser,
                            size: 13,
                            color: BoardColors.sky,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Sign in or register to lock in a username and earn reputation',
                            style: BoardText.meta.copyWith(
                              color: BoardColors.sky,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),

                  if (isRegistered) ...[
                    // Option 1: Registered Profile
                    InkWell(
                      onTap: () {
                        setSheetState(() {
                          isAnonymousSelected = false;
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: !isAnonymousSelected
                              ? BoardColors.green.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: !isAnonymousSelected
                                ? BoardColors.green
                                : BoardColors.line,
                            width: !isAnonymousSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Radio<bool>(
                              value: false,
                              groupValue: isAnonymousSelected,
                              activeColor: BoardColors.green,
                              onChanged: (_) {
                                setSheetState(() {
                                  isAnonymousSelected = false;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        userProfile.username,
                                        style: BoardText.body.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const FaIcon(
                                        FontAwesomeIcons.circleCheck,
                                        size: 13,
                                        color: BoardColors.sky,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        userProfile.levelInfo.emoji,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Earns reputation points and builds community trust. Unlocks higher vote weights.',
                                    style: BoardText.meta,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Option 2: Anonymous Mode
                  InkWell(
                    onTap: isRegistered
                        ? () {
                            setSheetState(() {
                              isAnonymousSelected = true;
                            });
                          }
                        : null,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: isRegistered ? const EdgeInsets.all(14) : EdgeInsets.zero,
                      decoration: isRegistered
                          ? BoxDecoration(
                              color: isAnonymousSelected
                                  ? BoardColors.green.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isAnonymousSelected
                                    ? BoardColors.green
                                    : BoardColors.line,
                                width: isAnonymousSelected ? 2 : 1,
                              ),
                            )
                          : null,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isRegistered) ...[
                            Radio<bool>(
                              value: true,
                              groupValue: isAnonymousSelected,
                              activeColor: BoardColors.green,
                              onChanged: (_) {
                                setSheetState(() {
                                  isAnonymousSelected = true;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isRegistered) ...[
                                  Text(
                                    'Post Anonymously',
                                    style: BoardText.body.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Keeps this post private and untraceable. No reputation points are awarded.',
                                    style: BoardText.meta,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (!isRegistered || isAnonymousSelected) ...[
                                  TextField(
                                    controller: controller,
                                    maxLength: 24,
                                    decoration: InputDecoration(
                                      labelText: 'Anonymous display name (optional)',
                                      hintText: AnonymousIdService.defaultDisplayName,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFF303229),
                                      labelStyle: const TextStyle(color: BoardColors.muted),
                                      hintStyle: const TextStyle(color: BoardColors.muted),
                                      counterText: '',
                                    ),
                                    style: BoardText.body,
                                  ),
                                  const SizedBox(height: 8),
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: rememberOnDevice,
                                    activeColor: BoardColors.green,
                                    title: Text(
                                      'Remember this handle on this device',
                                      style: BoardText.body.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Clearing browser/app data will reset it.',
                                      style: BoardText.meta,
                                    ),
                                    onChanged: (value) {
                                      setSheetState(() {
                                        rememberOnDevice = value ?? true;
                                      });
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BoardColors.green,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            if (isAnonymousSelected) {
                              final sanitized = sanitizeInput(controller.text);
                              final normalized =
                                  AnonymousIdService.normalizeDisplayName(
                                sanitized,
                              );
                              Navigator.of(context).pop(
                                AliasSelection(
                                  alias: normalized.isEmpty
                                      ? AnonymousIdService.defaultDisplayName
                                      : normalized,
                                  hasCustomAlias: normalized.isNotEmpty,
                                  remember: rememberOnDevice && normalized.isNotEmpty,
                                  isAnonymous: true,
                                ),
                              );
                            } else {
                              Navigator.of(context).pop(
                                AliasSelection(
                                  alias: userProfile!.username,
                                  hasCustomAlias: true,
                                  remember: false,
                                  isAnonymous: false,
                                ),
                              );
                            }
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(controller.dispose);
}
