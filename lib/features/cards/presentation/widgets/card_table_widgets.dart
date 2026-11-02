import 'package:flutter/material.dart';

class PokerFeltTable extends StatelessWidget {
  final List<Map> seats;
  final Object? board;
  final Object? pot;
  final Object? turnUid;
  final String myUid;
  final String street;

  const PokerFeltTable({
    super.key,
    required this.seats,
    required this.board,
    required this.pot,
    required this.turnUid,
    required this.myUid,
    required this.street,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const RadialGradient(
        colors: [Color(0xff17624b), Color(0xff0b3429), Color(0xff071d18)],
      ),
      borderRadius: BorderRadius.circular(90),
      border: Border.all(color: const Color(0xffc89d43), width: 4),
      boxShadow: const [
        BoxShadow(color: Colors.black87, blurRadius: 20, offset: Offset(0, 8)),
      ],
    ),
    child: Column(
      children: [
        Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final seat in seats)
              Container(
                constraints: const BoxConstraints(minWidth: 94),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xdd0b0e14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: seat['uid'] == turnUid
                        ? const Color(0xffffc174)
                        : const Color(0xff534434),
                    width: seat['uid'] == turnUid ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      seat['isBot'] == true ? Icons.smart_toy : Icons.person,
                      color: seat['uid'] == myUid
                          ? const Color(0xffffc174)
                          : const Color(0xffd8c3ad),
                      size: 19,
                    ),
                    Text(
                      '${seat['nickname'] ?? seat['uid'] ?? 'Ghế'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xffe1e2eb),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${seat['stack'] ?? '—'} TX',
                      style: const TextStyle(
                        color: Color(0xffffc174),
                        fontSize: 10,
                      ),
                    ),
                    if (seat['uid'] == turnUid)
                      const Text(
                        'ĐẾN LƯỢT',
                        style: TextStyle(
                          color: Color(0xff56e5a9),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xcc0b0e14),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xffc89d43)),
          ),
          child: Text(
            'POT  ${pot ?? 0} TX',
            style: const TextStyle(
              color: Color(0xffffc174),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          street.toUpperCase(),
          style: const TextStyle(
            color: Color(0xffd8c3ad),
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        cardFaces(board),
      ],
    ),
  );
}

List<Map> cardSeats(Map<String, dynamic> table) {
  final raw = table['seats'];
  return raw is List ? raw.whereType<Map>().toList() : const [];
}

Widget cardFaces(Object? value) {
  final cards = value is List ? value : const [];
  if (cards.isEmpty) return const Text('Chưa có bài được công bố.');
  return Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [for (final card in cards) Chip(label: Text(_cardLabel(card)))],
  );
}

String _cardLabel(Object? value) {
  if (value is! String || !RegExp(r'^(10|[2-9TJQKA])[CDHS]$').hasMatch(value)) {
    return '🂠';
  }
  final suit = const {
    'C': '♣',
    'D': '♦',
    'H': '♥',
    'S': '♠',
  }[value.substring(value.length - 1)];
  final rank = value.substring(0, value.length - 1);
  return '${rank == 'T' ? '10' : rank}$suit';
}

String cardWinners(Object? value) {
  if (value is List) {
    if (value.isEmpty) return 'Chưa có';
    return value
        .map((winner) {
          if (winner is Map) {
            return '${winner['nickname'] ?? winner['uid'] ?? 'Người chơi'}';
          }
          return '$winner';
        })
        .join(', ');
  }
  if (value is Map) {
    if (value.isEmpty) return 'Chưa có';
    return value.keys.join(', ');
  }
  return 'Chưa có';
}
