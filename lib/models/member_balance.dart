class MemberBalance {
  final String name;
  final String initials;
  final double balance;

  const MemberBalance({
    required this.name,
    required this.initials,
    required this.balance,
  });

  bool get isCreditor => balance > 0;
}