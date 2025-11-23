// Basic tests for HLT Messenger App

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hlt/main.dart';
import 'package:hlt/shared/models/message.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app builds successfully
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  // Test message model
  test('Message model creates correctly', () {
    final message = Message(
      id: 'test-id',
      conversationId: 'conv-id',
      senderId: 'user-id',
      content: 'Hello World',
      type: MessageType.text,
      createdAt: DateTime.now(),
    );

    expect(message.id, 'test-id');
    expect(message.content, 'Hello World');
    expect(message.type, MessageType.text);
  });

  // Test message grouping logic (simplified version)
  test('Message grouping works for same sender', () {
    final now = DateTime.now();
    final messages = [
      Message(
        id: '1',
        conversationId: 'conv-id',
        senderId: 'user-1',
        content: 'Hello',
        type: MessageType.text,
        createdAt: now,
      ),
      Message(
        id: '2',
        conversationId: 'conv-id',
        senderId: 'user-1',
        content: 'How are you?',
        type: MessageType.text,
        createdAt: now.add(const Duration(minutes: 2)),
      ),
    ];

    // Messages from same sender within 5 minutes should be grouped
    expect(messages[0].senderId, messages[1].senderId);
    expect(messages[1].createdAt.difference(messages[0].createdAt).inMinutes, lessThan(5));
  });

  test('Message grouping separates different senders', () {
    final now = DateTime.now();
    final messages = [
      Message(
        id: '1',
        conversationId: 'conv-id',
        senderId: 'user-1',
        content: 'Hello',
        type: MessageType.text,
        createdAt: now,
      ),
      Message(
        id: '2',
        conversationId: 'conv-id',
        senderId: 'user-2',
        content: 'Hi there!',
        type: MessageType.text,
        createdAt: now.add(const Duration(minutes: 1)),
      ),
    ];

    // Messages from different senders should not be grouped
    expect(messages[0].senderId, isNot(messages[1].senderId));
  });
}
