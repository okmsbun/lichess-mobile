import 'dart:math';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/broadcast/broadcast.dart';
import 'package:lichess_mobile/src/model/broadcast/broadcast_providers.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/theme.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/view/broadcast/broadcast_player_results_screen.dart';
import 'package:lichess_mobile/src/view/broadcast/broadcast_player_widget.dart';
import 'package:lichess_mobile/src/widgets/progression_widget.dart';

/// A tab that displays the players participating in a broadcast tournament.
class BroadcastPlayersTab extends ConsumerWidget {
  const BroadcastPlayersTab({required this.tournamentId});

  final BroadcastTournamentId tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = ref.watch(broadcastPlayersProvider(tournamentId));

    return switch (players) {
      AsyncData(value: final players) => PlayersList(players, tournamentId),
      AsyncError(:final error) => Center(child: Text('Cannot load players data: $error')),
      _ => const Center(child: CircularProgressIndicator.adaptive()),
    };
  }
}

enum _SortingTypes { player, elo, score }

const _kTableRowVerticalPadding = 12.0;
const _kTableRowHorizontalPadding = 8.0;
const _kTableRowPadding = EdgeInsets.symmetric(
  horizontal: _kTableRowHorizontalPadding,
  vertical: _kTableRowVerticalPadding,
);
const _kHeaderTextStyle = TextStyle(fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis);

class PlayersList extends ConsumerStatefulWidget {
  const PlayersList(this.players, this.tournamentId);

  final IList<BroadcastPlayerWithOverallResult> players;
  final BroadcastTournamentId tournamentId;

  @override
  ConsumerState<PlayersList> createState() => _PlayersListState();
}

class _PlayersListState extends ConsumerState<PlayersList> {
  late IList<BroadcastPlayerWithOverallResult> players;
  late _SortingTypes currentSort;
  bool reverse = false;

  @override
  void initState() {
    super.initState();
    players = widget.players;
    currentSort = players.firstOrNull?.score != null ? _SortingTypes.score : _SortingTypes.elo;
    sort(currentSort);
  }

  @override
  void didUpdateWidget(PlayersList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.players != widget.players) {
      players = widget.players;
      currentSort = players.firstOrNull?.score != null ? _SortingTypes.score : _SortingTypes.elo;
      sort(currentSort);
    }
  }

  void sort(_SortingTypes newSort, {bool toggleReverse = false}) {
    final compare = switch (newSort) {
      _SortingTypes.player =>
        (BroadcastPlayerWithOverallResult a, BroadcastPlayerWithOverallResult b) =>
            a.player.name.compareTo(b.player.name),
      _SortingTypes.elo => (
        BroadcastPlayerWithOverallResult a,
        BroadcastPlayerWithOverallResult b,
      ) {
        if (a.player.rating == null) return 1;
        if (b.player.rating == null) return -1;
        return b.player.rating!.compareTo(a.player.rating!);
      },
      _SortingTypes.score => (
        BroadcastPlayerWithOverallResult a,
        BroadcastPlayerWithOverallResult b,
      ) {
        if (a.score == null) return 1;
        if (b.score == null) return -1;

        final value = b.score!.compareTo(a.score!);
        if (value == 0) {
          return a.played.compareTo(b.played);
        } else {
          return value;
        }
      },
    };

    setState(() {
      if (currentSort != newSort) {
        reverse = false;
      } else {
        reverse = toggleReverse ? !reverse : reverse;
      }
      currentSort = newSort;
      players = reverse ? players.sortReversed(compare) : players.sort(compare);
    });
  }

  @override
  Widget build(BuildContext context) {
    final double eloWidth = max(MediaQuery.sizeOf(context).width * 0.2, 100);
    final double scoreWidth = max(MediaQuery.sizeOf(context).width * 0.15, 90);

    final firstPlayer = players.firstOrNull;

    return ListView.builder(
      itemCount: players.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return ColoredBox(
            color: ColorScheme.of(context).surfaceDim,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _TableTitleCell(
                    title: Text(context.l10n.player, style: _kHeaderTextStyle),
                    onTap:
                        () => sort(
                          _SortingTypes.player,
                          toggleReverse: currentSort == _SortingTypes.player,
                        ),
                    sortIcon:
                        (currentSort == _SortingTypes.player)
                            ? (reverse ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down)
                            : null,
                  ),
                ),
                SizedBox(
                  width: eloWidth,
                  child: _TableTitleCell(
                    title: const Text('Elo', style: _kHeaderTextStyle),
                    onTap:
                        () => sort(
                          _SortingTypes.elo,
                          toggleReverse: currentSort == _SortingTypes.elo,
                        ),
                    sortIcon:
                        (currentSort == _SortingTypes.elo)
                            ? (reverse ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down)
                            : null,
                  ),
                ),
                SizedBox(
                  width: scoreWidth,
                  child: _TableTitleCell(
                    title: Text(
                      firstPlayer?.score != null ? context.l10n.broadcastScore : context.l10n.games,
                      style: _kHeaderTextStyle,
                    ),
                    onTap:
                        () => sort(
                          _SortingTypes.score,
                          toggleReverse: currentSort == _SortingTypes.score,
                        ),
                    sortIcon:
                        (currentSort == _SortingTypes.score)
                            ? (reverse ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down)
                            : null,
                  ),
                ),
              ],
            ),
          );
        } else {
          final BroadcastPlayerWithOverallResult(:player, :ratingDiff, :score, :played) =
              players[index - 1];
          final rating = player.rating;

          return GestureDetector(
            onTap: () {
              Navigator.of(
                context,
              ).push(BroadcastPlayerResultsScreen.buildRoute(context, widget.tournamentId, player));
            },
            child: ColoredBox(
              color: index.isEven ? context.lichessTheme.rowEven : context.lichessTheme.rowOdd,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: _kTableRowPadding,
                      child: BroadcastPlayerWidget(player: player, showRating: false),
                    ),
                  ),
                  SizedBox(
                    width: eloWidth,
                    child: Padding(
                      padding: _kTableRowPadding,
                      child: Row(
                        children: [
                          if (rating != null) ...[
                            Text(rating.toString()),
                            const SizedBox(width: 5),
                            if (ratingDiff != null) ProgressionWidget(ratingDiff, fontSize: 14),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: scoreWidth,
                    child: Padding(
                      padding: _kTableRowPadding,
                      child:
                          (score != null)
                              ? Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${score.toStringAsFixed((score == score.roundToDouble()) ? 0 : 1)} / $played',
                                ),
                              )
                              : Align(
                                alignment: Alignment.centerRight,
                                child: Text(played.toString()),
                              ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}

class _TableTitleCell extends StatelessWidget {
  const _TableTitleCell({required this.title, required this.onTap, this.sortIcon});

  final Widget title;
  final void Function() onTap;
  final IconData? sortIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: _kTableRowPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: title),
              if (sortIcon != null)
                Text(
                  String.fromCharCode(sortIcon!.codePoint),
                  style: _kHeaderTextStyle.copyWith(fontSize: 16, fontFamily: sortIcon!.fontFamily),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
