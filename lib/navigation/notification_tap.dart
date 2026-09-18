import '../models/app_notification.dart';
import '../models/models.dart';
import '../screens/check_in_screen.dart';
import '../screens/main_shell.dart';
import '../state/session_controller.dart';

Future<void> openInboxNotification({
  required SessionController session,
  required AppNotification item,
}) {
  return openNotificationTarget(
    session: session,
    kind: item.kind,
    eventId: item.eventId,
    notificationId: item.id,
  );
}

Future<void> openNotificationPayload({
  required SessionController session,
  required String payload,
}) async {
  final parsed = NotificationPayload.tryParse(payload);
  if (parsed == null) {
    return;
  }
  await openNotificationTarget(
    session: session,
    kind: parsed.kind,
    eventId: parsed.eventId,
    notificationId: parsed.notificationId,
  );
}

Future<void> flushPendingNotificationTap(SessionController session) async {
  final payload = session.consumePendingOsPayload();
  if (payload == null) {
    return;
  }
  await openNotificationPayload(session: session, payload: payload);
}

Future<void> openNotificationTarget({
  required SessionController session,
  required NotificationKind kind,
  String? eventId,
  String? notificationId,
}) async {
  if (session.employee == null) {
    session.holdNotificationPayload(
      NotificationPayload(
        kind: kind,
        eventId: eventId,
        notificationId: notificationId,
      ).encode(),
    );
    return;
  }

  if (notificationId != null) {
    session.markNotificationRead(notificationId);
  }

  ProvincialEvent? event;
  if (eventId != null) {
    event = session.eventById(eventId);
    if (event == null) {
      await session.refreshEvents();
      event = session.eventById(eventId);
    }
  }

  final destination = notificationDestination(kind);
  switch (destination) {
    case NotificationDestination.checkIn:
      session.selectShellTab(0);
      if (event != null) {
        session.selectEvent(event);
      }
    case NotificationDestination.history:
      session.selectShellTab(1);
    case NotificationDestination.profile:
      session.selectShellTab(2);
    case NotificationDestination.inbox:
      return;
  }

  final nav = session.navigatorKey.currentState;
  if (nav == null) {
    return;
  }

  nav.popUntil(
    (route) => route.isFirst || route.settings.name == MainShell.routeName,
  );

  if (destination == NotificationDestination.checkIn && event != null) {
    nav.pushNamed(CheckInScreen.routeName, arguments: event);
  }
}
