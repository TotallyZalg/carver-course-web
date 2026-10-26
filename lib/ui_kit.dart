import 'package:flutter/material.dart';

import 'api_service.dart';
import 'theme.dart';

/// Turns any error into text a person can read.
String errorText(Object e) =>
    e is ApiException ? e.message : 'Something went wrong. Try again.';

/// The cream gradient area on the right side of every page.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child, this.scroll = true});

  final Widget child;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBF3E2), Color(0xFFF1E3CC), Color(0xFFE6D2C4)],
        ),
      ),
      child: scroll
          ? SingleChildScrollView(padding: const EdgeInsets.all(14), child: child)
          : Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

/// Cream card. Material + InkWell so the tap ripple shows on top of the color.
class CardBox extends StatelessWidget {
  const CardBox({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardCream,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class LoadingBox extends StatelessWidget {
  const LoadingBox({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator(color: AppColors.sidebar)),
    );
  }
}

class CenteredMessage extends StatelessWidget {
  const CenteredMessage(this.message, {super.key, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.sans(size: 12, color: Colors.black87),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                child: Text('Try again', style: AppText.sans(size: 11, color: AppColors.label)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Themed dropdown. Use '' as the "none" value instead of null.
class SelectBox<T> extends StatelessWidget {
  const SelectBox({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF6B5B4B)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items,
          style: AppText.sans(size: 12, color: AppColors.darkBrown),
          dropdownColor: AppColors.inputFill,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

InputDecoration fieldDecoration(String hint) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(6)),
    borderSide: BorderSide(color: Color(0xFF6B5B4B)),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: AppText.sans(size: 11, color: Colors.grey.shade500),
    filled: true,
    fillColor: AppColors.inputFill,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: border,
    enabledBorder: border,
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(6)),
      borderSide: BorderSide(color: AppColors.label, width: 1.5),
    ),
  );
}

Widget inputField(
  TextEditingController controller,
  String hint, {
  bool obscure = false,
  int minLines = 1,
  int maxLines = 1,
  ValueChanged<String>? onSubmitted,
}) {
  return TextField(
    controller: controller,
    obscureText: obscure,
    minLines: obscure ? 1 : minLines,
    maxLines: obscure ? 1 : maxLines,
    style: AppText.sans(size: 12, color: AppColors.darkBrown),
    onSubmitted: onSubmitted,
    decoration: fieldDecoration(hint),
  );
}

Widget fieldLabel(String text) => Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 3, top: 10),
      child: Text(text, style: AppText.sans(size: 10.5, color: AppColors.label)),
    );

Widget pageTitle(String text) =>
    Text(text, style: AppText.serif(size: 22, color: AppColors.title));

Widget primaryButton({
  required String label,
  required VoidCallback? onPressed,
  bool loading = false,
}) {
  return SizedBox(
    height: 34,
    child: FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.darkBrown,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
      ),
      child: loading
          ? const SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label, style: AppText.sans(size: 11, color: Colors.white)),
    ),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cardCream,
      title: Text(title, style: AppText.serif(size: 16, color: AppColors.title)),
      content: Text(message, style: AppText.sans(size: 12, color: Colors.black87)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: AppText.sans(size: 11, color: AppColors.label)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.darkBrown),
          child: Text(confirmLabel, style: AppText.sans(size: 11, color: Colors.white)),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: AppText.sans(size: 12, color: AppColors.cream)),
        backgroundColor: AppColors.darkBrown,
      ),
    );
}

/// Pop if there is a page to go back to (normal navigation),
/// otherwise open the fallback page (e.g. after a browser refresh).
void goBack(BuildContext context, String fallback) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  } else {
    navigator.pushReplacementNamed(fallback);
  }
}