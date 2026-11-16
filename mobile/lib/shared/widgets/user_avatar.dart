import 'package:flutter/material.dart';

import '../../data/models/user_model.dart';

/// Avatar com as iniciais do usuário.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.radius = 28});

  final UserModel user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Avatar de ${user.name}',
      image: true,
      excludeSemantics: true,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Text(
          user.initials,
          style: TextStyle(fontSize: radius * 0.7, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
