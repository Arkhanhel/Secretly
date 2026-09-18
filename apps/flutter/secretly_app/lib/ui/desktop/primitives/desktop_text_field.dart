// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';

class DesktopTextField extends StatefulWidget {
  const DesktopTextField({
    super.key,
    this.controller,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.textInputAction,
    this.obscureText = false,
    this.focusNode,
  });

  /// Свой узел фокуса — чтобы владелец поля мог поставить в него курсор
  /// сам, а не надеяться на [autofocus]. Тот срабатывает, только если в
  /// области фокуса ещё ничего не выбрано, а в окне фокус держит оболочка.
  /// `null` — поле заводит узел само.
  final FocusNode? focusNode;

  final TextEditingController? controller;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;

  /// Masks the input. Needed for the lock-password dialogs — a password
  /// field that renders its own value in the clear is a leak to anyone
  /// standing behind the screen.
  final bool obscureText;

  @override
  State<DesktopTextField> createState() => _DesktopTextFieldState();
}

class _DesktopTextFieldState extends State<DesktopTextField> {
  bool _focused = false;
  FocusNode? _own;

  FocusNode get _focus => widget.focusNode ?? (_own ??= FocusNode());

  void _onFocus() => setState(() => _focused = _focus.hasFocus);

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant DesktopTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _own)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
      _focused = _focus.hasFocus;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final border = _focused ? c.accentPrimary : c.borderSubtle;
    return AnimatedContainer(
      duration: DMotion.fast,
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(DRadii.sm),
        border: Border.all(color: border, width: _focused ? 1.5 : 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: DSpace.m, vertical: DSpace.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.prefixIcon != null) ...[
            Icon(widget.prefixIcon, size: 16, color: c.textSecondary),
            const SizedBox(width: DSpace.s),
          ],
          Expanded(
            child: TextField(
              controller: widget.controller,
      obscureText: widget.obscureText,
              focusNode: _focus,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              maxLines: widget.maxLines,
              minLines: widget.minLines,
              maxLength: widget.maxLength,
              inputFormatters: widget.inputFormatters,
              textInputAction: widget.textInputAction,
              style: DType.body.copyWith(color: c.textPrimary),
              cursorColor: c.accentPrimary,
              cursorWidth: 1.5,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: DType.body.copyWith(color: c.textSecondary),
                counterText: '',
              ),
            ),
          ),
          if (widget.suffixIcon != null) ...[
            const SizedBox(width: DSpace.s),
            widget.suffixIcon!,
          ],
        ],
      ),
    );
  }
}
