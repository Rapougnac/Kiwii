import 'package:get_it/get_it.dart';
import 'package:nyxx/nyxx.dart';

import '../../../database.dart' hide Guild;
import '../../../plugins/localization.dart';
import '../../models/case.dart';
import 'create_case.dart';

Future<Case> deleteCase(DeleteCase deleteCase, Guild guild, {bool shouldSkip = false, bool isManual = false}) async {
  final db = GetIt.I.get<AppDatabase>();
  final t = guild.t;
  Case? ccase;
  var localReason = deleteCase.reason;

  if (deleteCase.targetId != null) {
    ccase = await (db.cases.select()
          ..where(
            (tbl) =>
                tbl.targetId.equalsValue(deleteCase.targetId!) &
                tbl.guildId.equalsValue(deleteCase.guildId) &
                tbl.action.equalsValue(deleteCase.action ?? CaseAction.ban),
          )
          ..orderBy(
            [
              (u) => OrderingTerm.desc(u.createdAt),
            ],
          )
          ..limit(1))
        .getSingle();
  }

  if (deleteCase.targetId == null) {
    ccase = await db.getCase(deleteCase.caseId!, deleteCase.guildId);
  }

  if (ccase?.action == CaseAction.role) {
    await (db.cases.update()..where((tbl) => tbl.guildId.equalsValue(deleteCase.guildId) & tbl.caseId.equals(ccase!.caseId))).write(
      CasesCompanion(
        actionProcessed: Value(true),
      ),
    );

    if (isManual == true) {
      localReason = t.moderation.logs.cases.unroleDeleteManual;
    } else {
      localReason = t.moderation.logs.cases.unroleDeleteAuto;
    }
  }

  if (ccase?.action == CaseAction.timeout) {
    await (db.cases.update()..where((tbl) => tbl.guildId.equalsValue(deleteCase.guildId) & tbl.caseId.equals(ccase!.caseId))).write(
      CasesCompanion(
        actionProcessed: Value(true),
      ),
    );

    if (isManual) {
      localReason = t.moderation.logs.cases.timeoutDeleteManual;
    } else {
      localReason = t.moderation.logs.cases.timeoutDeleteAuto;
    }
  }

  final caseAction = ccase?.action ?? CaseAction.ban;

  return createCase(
    guild,
    CreateCase(
      guildId: guild.id,
      action: caseAction == CaseAction.ban
          ? CaseAction.unban
          : caseAction == CaseAction.role
              ? CaseAction.unrole
              : CaseAction.timeoutEnd,
      targetId: ccase?.targetId ?? deleteCase.targetId!,
      targetTag: ccase?.targetTag ?? deleteCase.targetTag!,
      appealRefId: deleteCase.appealRefId,
      reportRefId: deleteCase.reportRefId,
      refId: ccase?.caseId,
      reason: localReason,
      modId: deleteCase.modId,
      modTag: deleteCase.modTag,
    ),
    skip: shouldSkip,
  );
}