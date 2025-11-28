import 'package:flutter/material.dart';

String stripFormatting(String input) {
  // Case 1: symbol-only segments should remain unchanged
  if (RegExp(r'^[*_]+$').hasMatch(input.trim())) {
    return input;
  }

  // Handle combined bold + italic: **__text__** or __**text**__
  input = input.replaceAllMapped(
    RegExp(r'\*\*__(.*?)__\*\*'),
    (match) => match.group(1)!,
  );

  input = input.replaceAllMapped(
    RegExp(r'__\*\*(.*?)\*\*__'),
    (match) => match.group(1)!,
  );

  // Handle bold only
  input = input.replaceAllMapped(
    RegExp(r'\*\*(.*?)\*\*'),
    (match) => match.group(1)!,
  );

  // Handle italics only
  input = input.replaceAllMapped(
    RegExp(r'__(.*?)__'),
    (match) => match.group(1)!,
  );

  return input;
}


InlineSpan parseMessage(String message, TextStyle baseStyle) {
  final List<InlineSpan> spans = [];

  // Regex to capture any of the patterns: **text**, __text__, or combined
  final pattern = RegExp(r'(\*\*__.*?__\*\*|__\*\*.*?\*\*__|\*\*.*?\*\*|__.*?__)');

  int currentIndex = 0;

  Iterable<RegExpMatch> matches = pattern.allMatches(message);

  for (final match in matches) {
    // Add normal text before the match
    if (match.start > currentIndex) {
      spans.add(TextSpan(
        text: message.substring(currentIndex, match.start),
        style: baseStyle,
      ));
    }

    final raw = match.group(0)!;

    // Check if it's only symbols → return raw
    final isOnlySymbols = RegExp(r'^[*_]+$').hasMatch(raw);
    if (isOnlySymbols) {
      spans.add(TextSpan(text: raw, style: baseStyle));
    } else {
      // Determine style
      bool isBold = raw.startsWith('**') && raw.endsWith('**');
      bool isItalic = raw.startsWith('__') && raw.endsWith('__');

      // Nested case: **__text__** or __**text**__
      if (raw.startsWith('**__') && raw.endsWith('__**')) {
        isBold = true;
        isItalic = true;
      } else if (raw.startsWith('__**') && raw.endsWith('**__')) {
        isBold = true;
        isItalic = true;
      }

      // Extract inner text
      String inner = raw;

      if (raw.startsWith('**__') && raw.endsWith('__**')) {
        inner = raw.substring(4, raw.length - 4);
      } else if (raw.startsWith('__**') && raw.endsWith('**__')) {
        inner = raw.substring(4, raw.length - 4);
      } else if (isBold) {
        inner = raw.substring(2, raw.length - 2);
      } else if (isItalic) {
        inner = raw.substring(2, raw.length - 2);
      }

      spans.add(TextSpan(
        text: inner,
        style: baseStyle.copyWith(
          fontWeight: isBold ? FontWeight.bold : null,
          fontStyle: isItalic ? FontStyle.italic : null,
        ),
      ));
    }

    currentIndex = match.end;
  }

  // Add the remaining text
  if (currentIndex < message.length) {
    spans.add(TextSpan(
      text: message.substring(currentIndex),
      style: baseStyle,
    ));
  }

  return TextSpan(children: spans);
}
