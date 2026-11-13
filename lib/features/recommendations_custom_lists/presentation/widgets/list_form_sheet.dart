import 'package:flutter/material.dart';

import '../../domain/list_rules.dart';
import '../../domain/models/custom_list.dart';

class ListFormResult {
  const ListFormResult(this.name, this.description, this.isPublic);
  final String name;
  final String description;
  final bool isPublic;
}

/// Create ([initial] null) or edit a list. [otherNames]: names already used.
Future<ListFormResult?> showListFormSheet(
  BuildContext context, {
  required Iterable<String> otherNames,
  CustomList? initial,
}) {
  return showModalBottomSheet<ListFormResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) =>
        _ListFormSheet(otherNames: otherNames.toList(), initial: initial),
  );
}

class _ListFormSheet extends StatefulWidget {
  const _ListFormSheet({required this.otherNames, this.initial});

  final List<String> otherNames;
  final CustomList? initial;

  @override
  State<_ListFormSheet> createState() => _ListFormSheetState();
}

class _ListFormSheetState extends State<_ListFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.initial?.description,
  );
  late bool _isPublic = widget.initial?.isPublic ?? false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      ListFormResult(_name.text.trim(), _description.text.trim(), _isPublic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editing ? 'Edit list' : 'New list',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              autofocus: !editing,
              maxLength: ListRules.nameMax,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Weekend sci-fi',
                prefixIcon: Icon(Icons.drive_file_rename_outline),
              ),
              validator: (v) =>
                  ListRules.validateName(v ?? '', widget.otherNames),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _description,
              maxLength: ListRules.descriptionMax,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                prefixIcon: Icon(Icons.notes),
              ),
              validator: (v) => ListRules.validateDescription(v ?? ''),
            ),
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
                secondary: Icon(_isPublic ? Icons.public : Icons.lock_outline),
                title: Text(_isPublic ? 'Public' : 'Private'),
                subtitle: Text(
                  _isPublic
                      ? 'Visible in Community lists. Only you can edit it.'
                      : 'Only you can see this list.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(editing ? 'Save' : 'Create list'),
            ),
          ],
        ),
      ),
    );
  }
}
