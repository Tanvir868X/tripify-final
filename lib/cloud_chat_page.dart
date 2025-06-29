import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CloudChatPage extends StatefulWidget {
  const CloudChatPage({Key? key}) : super(key: key);

  @override
  State<CloudChatPage> createState() => _CloudChatPageState();
}

class _CloudChatPageState extends State<CloudChatPage> {
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  String? _selectedChatId;
  String? _selectedOtherEmail;
  String? _selectedOtherPhotoUrl;

  User? get _user => FirebaseAuth.instance.currentUser;
  String? get _userEmail => _user?.email;
  String? get _userPhotoUrl => _user?.photoURL;

  @override
  void dispose() {
    _newEmailController.dispose();
    _messageController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  String getChatId(String email1, String email2) {
    final emails = [email1, email2]..sort();
    return emails.join('_');
  }

  Future<void> _startNewChat() async {
    final otherEmail = _newEmailController.text.trim();
    if (otherEmail.isEmpty || !otherEmail.contains('@gmail.com') || otherEmail == _userEmail) return;
    final chatId = getChatId(_userEmail!, otherEmail);
    setState(() {
      _selectedChatId = chatId;
      _selectedOtherEmail = otherEmail;
      _selectedOtherPhotoUrl = null; // Reset photo
    });
    _newEmailController.clear();
  }

  void _selectChat(String chatId, String otherEmail, [String? otherPhotoUrl]) {
    setState(() {
      _selectedChatId = chatId;
      _selectedOtherEmail = otherEmail;
      _selectedOtherPhotoUrl = otherPhotoUrl;
    });
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _selectedChatId == null || _user == null || _selectedOtherEmail == null) return;
    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(_selectedChatId)
        .collection('messages');
    await chatRef.add({
      'text': message,
      'timestamp': FieldValue.serverTimestamp(),
      'from': _user!.email,
      'fromPhoto': _userPhotoUrl,
      'to': _selectedOtherEmail,
    });
    _messageController.clear();
    // Scroll to bottom after sending
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? _chatStream() {
    if (_selectedChatId == null) return null;
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(_selectedChatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }

  Stream<List<Map<String, String>>>? _userChatsStream() {
    if (_userEmail == null) return null;
    return FirebaseFirestore.instance.collection('chats').snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) => doc.id.contains(_userEmail!))
          .map((doc) {
            final emails = doc.id.split('_');
            final otherEmail = emails.firstWhere((e) => e != _userEmail, orElse: () => '');
            return {'chatId': doc.id, 'otherEmail': otherEmail};
          })
          .where((chat) => chat['otherEmail'] != '')
          .toList();
    });
  }

  Widget _buildAvatar(String? photoUrl, String email) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(photoUrl));
    } else {
      final initials = email.isNotEmpty ? email[0].toUpperCase() : '?';
      return CircleAvatar(child: Text(initials));
    }
  }

  void _autoScrollToBottom() {
    if (_chatScrollController.hasClients) {
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            // Left: List of chats (narrower)
            Container(
              width: isWide ? 180 : 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newEmailController,
                          decoration: const InputDecoration(
                            labelText: 'Start chat with Gmail',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _startNewChat(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _startNewChat,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Your Chats', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  Expanded(
                    child: StreamBuilder<List<Map<String, String>>>(
                      stream: _userChatsStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final chats = snapshot.data ?? [];
                        if (chats.isEmpty) {
                          return const Center(child: Text('No chats yet.'));
                        }
                        return ListView.builder(
                          itemCount: chats.length,
                          itemBuilder: (context, index) {
                            final chat = chats[index];
                            return ListTile(
                              leading: _buildAvatar(null, chat['otherEmail'] ?? ''),
                              title: Text(chat['otherEmail'] ?? '', overflow: TextOverflow.ellipsis),
                              selected: _selectedChatId == chat['chatId'],
                              onTap: () => _selectChat(chat['chatId']!, chat['otherEmail']!),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 16),
            // Right: Chat area (wider)
            Expanded(
              flex: isWide ? 4 : 2,
              child: _selectedChatId == null
                  ? const Center(child: Text('Select or start a chat'))
                  : Column(
                      children: [
                        if (_selectedOtherEmail != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                _buildAvatar(_selectedOtherPhotoUrl, _selectedOtherEmail!),
                                const SizedBox(width: 12),
                                Text(_selectedOtherEmail!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              ],
                            ),
                          ),
                        const Divider(),
                        // Chat history
                        Expanded(
                          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _chatStream(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              final messages = snapshot.data?.docs ?? [];
                              // Auto-scroll to bottom when messages change
                              WidgetsBinding.instance.addPostFrameCallback((_) => _autoScrollToBottom());
                              return ListView.builder(
                                controller: _chatScrollController,
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final msg = messages[index].data();
                                  final isMe = msg['from'] == _user?.email;
                                  final fromPhoto = msg['fromPhoto'] as String?;
                                  return Row(
                                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                    children: [
                                      if (!isMe) ...[
                                        _buildAvatar(fromPhoto, msg['from'] ?? ''),
                                        const SizedBox(width: 8),
                                      ],
                                      Flexible(
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isMe ? Colors.teal[100] : Colors.grey[200],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                msg['from'] ?? '',
                                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(msg['text'] ?? ''),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 8),
                                        _buildAvatar(fromPhoto, msg['from'] ?? ''),
                                      ],
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  decoration: const InputDecoration(
                                    labelText: 'Type a message',
                                    border: OutlineInputBorder(),
                                  ),
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.send, color: Colors.teal),
                                onPressed: _sendMessage,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
} 