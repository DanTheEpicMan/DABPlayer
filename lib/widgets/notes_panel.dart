import 'package:flutter/material.dart';
import '../main.dart';
import '../data/models/note.dart';
import '../theme.dart';

/// Displays the list of notes for the current book with inline edit/delete.
/// Also shows a one-tap voice note mic button (when supported).
class NotesPanel extends StatelessWidget {
  final List<Note> notes;
  final bool isLoading;
  final bool voiceSupported;
  final TextEditingController noteController;
  final VoidCallback onAdd;
  final VoidCallback onVoiceTap;
  final void Function(Note) onDelete;
  final void Function(Note) onEdit;

  const NotesPanel({
    super.key,
    required this.notes,
    required this.isLoading,
    required this.voiceSupported,
    required this.noteController,
    required this.onAdd,
    required this.onVoiceTap,
    required this.onDelete,
    required this.onEdit,
  });

  void _showOptions(BuildContext ctx, Note note) {
    showModalBottomSheet(
      context: ctx,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Note'),
              onTap: () {
                Navigator.pop(ctx);
                onEdit(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Note',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete(note);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Text('Notes',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (voiceSupported)
                Tooltip(
                  message: 'Record voice note',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onVoiceTap,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.mic_none,
                          color: kPrimaryColor, size: 26),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Text input row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: noteController,
                decoration: InputDecoration(
                  hintText: 'Add a note…',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                onSubmitted: isLoading ? null : (_) => onAdd(),
                textInputAction: TextInputAction.done,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: isLoading ? null : onAdd,
              tooltip: 'Add Note',
              style: IconButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Notes list
        Expanded(
          child: notes.isEmpty
              ? Center(
                  child: Text(
                    'No notes yet.\nTap "Add" or the mic to add one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : ListView.separated(
                  itemCount: notes.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16),
                  itemBuilder: (ctx, i) {
                    final note = notes[i];
                    return ListTile(
                      dense: true,
                      title: Text(
                        note.label,
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Edit',
                            onPressed: () => onEdit(note),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: Colors.redAccent),
                            tooltip: 'Delete',
                            onPressed: () => onDelete(note),
                          ),
                        ],
                      ),
                      onLongPress: () => _showOptions(ctx, note),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
