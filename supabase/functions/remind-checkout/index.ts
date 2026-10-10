import { json, serviceClient } from "../_shared/auth.ts";
import {
  firebaseProjectId,
  googleAccessToken,
  sendToTokens,
} from "../_shared/fcm.ts";

type EventRow = {
  id: string;
  name: string;
  event_date: string;
  start_time: string;
  end_time: string;
  status: string;
  requires_check_out: boolean;
};

type AttendanceRow = {
  id: string;
  profile_id: string;
  check_in_at: string;
  events: EventRow | EventRow[] | null;
};

const closed = new Set(["draft", "cancelled", "completed"]);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return json({ ok: true });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const header = req.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!serviceKey || token !== serviceKey) {
    return json({ error: "Not allowed" }, 401);
  }

  try {
    const admin = serviceClient();
    const accessToken = await googleAccessToken();
    const projectId = firebaseProjectId();
    const now = new Date();
    const { data, error } = await admin
      .from("attendance_records")
      .select(
        "id, profile_id, check_in_at, events!inner(id, name, event_date, start_time, end_time, status, requires_check_out)",
      )
      .is("check_out_at", null)
      .not("check_in_at", "is", null)
      .is("checkout_reminder_sent_at", null);
    if (error) {
      throw error;
    }

    let sent = 0;
    const skipped: string[] = [];
    for (const row of (data ?? []) as AttendanceRow[]) {
      const event = Array.isArray(row.events) ? row.events[0] : row.events;
      if (!event || !event.requires_check_out || closed.has(event.status)) {
        skipped.push(`${row.id}: event does not need an open check-out`);
        continue;
      }
      const window = eventWindow(event);
      if (!window) {
        skipped.push(`${row.id}: event time could not be read`);
        continue;
      }
      const remindAt = reminderInstant(window.start, window.end);
      if (!remindAt || now < remindAt || now >= window.end) {
        skipped.push(
          `${event.name}: reminder is ${remindAt?.toISOString() ?? "unset"}, now is ${now.toISOString()}, ends ${window.end.toISOString()}`,
        );
        continue;
      }

      const { data: devices, error: deviceError } = await admin
        .from("devices")
        .select("fcm_token")
        .eq("profile_id", row.profile_id)
        .eq("is_active", true)
        .not("fcm_token", "is", null);
      if (deviceError) {
        throw deviceError;
      }
      const tokens = [
        ...new Set(
          (devices ?? [])
            .map((device) =>
              typeof device.fcm_token === "string" ? device.fcm_token.trim() : ""
            )
            .filter((value) => value.length > 0),
        ),
      ];
      const title = "Check-out still needed";
      const body =
        `You checked in to ${event.name}. Check out before this event ends.`;
      if (tokens.length === 0) {
        skipped.push(`${event.name}: no phone token saved`);
        continue;
      }
      const delivered = await sendToTokens(
        accessToken,
        projectId,
        tokens,
        title,
        body,
        {
          kind: "checkOutReminder",
          event_id: event.id,
          notification_id: `checkout-reminder-${event.id}`,
        },
      );
      if (delivered === 0) {
        skipped.push(`${event.name}: Firebase did not accept the reminder`);
        continue;
      }
      sent += delivered;
      const { error: markError } = await admin
        .from("attendance_records")
        .update({ checkout_reminder_sent_at: now.toISOString() })
        .eq("id", row.id)
        .is("check_out_at", null)
        .is("checkout_reminder_sent_at", null);
      if (markError) {
        throw markError;
      }
    }
    console.log("remind-checkout", JSON.stringify({ sent, skipped }));
    return json({ sent, skipped });
  } catch (error) {
    console.error(
      "remind-checkout failed",
      error instanceof Error ? error.message : error,
    );
    return json(
      { error: error instanceof Error ? error.message : "Could not send reminders" },
      500,
    );
  }
});

function eventWindow(event: EventRow): { start: Date; end: Date } | null {
  const start = manilaTime(event.event_date, event.start_time);
  let end = manilaTime(event.event_date, event.end_time);
  if (start == null || end == null) {
    return null;
  }
  if (end.getTime() <= start.getTime()) {
    end = new Date(end.getTime() + 24 * 60 * 60 * 1000);
  }
  return { start, end };
}

function reminderInstant(start: Date, end: Date): Date | null {
  let preferred = new Date(end.getTime() - 30 * 60 * 1000);
  if (preferred.getTime() <= start.getTime()) {
    preferred = new Date(start.getTime() + (end.getTime() - start.getTime()) / 2);
  }
  if (preferred.getTime() <= start.getTime() || preferred.getTime() >= end.getTime()) {
    return null;
  }
  return preferred;
}

function manilaTime(date: string, time: string): Date | null {
  const day = date.slice(0, 10);
  const clock = time.length === 5 ? `${time}:00` : time.slice(0, 8);
  const parsed = new Date(`${day}T${clock}+08:00`);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }
  return parsed;
}
