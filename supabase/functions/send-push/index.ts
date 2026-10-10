import { corsHeaders, json, serviceClient, userClient } from "../_shared/auth.ts";
import {
  firebaseProjectId,
  googleAccessToken,
  sendToTokens,
} from "../_shared/fcm.ts";

type PushRequest = {
  kind?: string;
  event_id?: string;
  request_id?: string;
  reason?: string;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    console.log("send-push POST");
    const authorized = await authorizeStaff(req);
    if (!authorized) {
      console.log("send-push denied: not staff");
      return json({ error: "Staff authentication is required" }, 401);
    }

    const body = (await req.json()) as PushRequest;
    console.log("send-push body", JSON.stringify(body));
    const admin = serviceClient();
    const accessToken = await googleAccessToken();
    const projectId = firebaseProjectId();

    if (body.kind === "device_change" || body.request_id) {
      const sent = await notifyDeviceChange(
        admin,
        accessToken,
        projectId,
        body.request_id ?? "",
      );
      console.log("send-push device_change sent", sent);
      return json({ sent });
    }

    const eventId = body.event_id?.trim();
    if (!eventId) {
      return json({ error: "event_id or request_id is required" }, 400);
    }
    const sent = await notifyEvent(
      admin,
      accessToken,
      projectId,
      eventId,
      body.reason === "updated",
    );
    console.log("send-push event sent", sent);
    return json({ sent });
  } catch (error) {
    console.error(
      "send-push failed",
      error instanceof Error ? error.message : error,
    );
    return json(
      { error: error instanceof Error ? error.message : "Could not send push" },
      500,
    );
  }
});

async function authorizeStaff(req: Request): Promise<boolean> {
  const header = req.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!token) {
    return false;
  }
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (serviceKey && token === serviceKey) {
    return true;
  }
  try {
    const client = userClient(token);
    const { data, error } = await client.auth.getUser(token);
    if (error || !data.user) {
      return false;
    }
    const admin = serviceClient();
    const { data: profile } = await admin
      .from("profiles")
      .select("role")
      .eq("id", data.user.id)
      .maybeSingle();
    return (
      profile?.role === "hr_administrator" ||
      profile?.role === "system_administrator"
    );
  } catch {
    return false;
  }
}

async function notifyEvent(
  admin: ReturnType<typeof serviceClient>,
  accessToken: string,
  projectId: string,
  eventId: string,
  updated: boolean,
): Promise<number> {
  const { data: event, error } = await admin
    .from("events")
    .select("id, name, venue, status, is_open_to_all")
    .eq("id", eventId)
    .maybeSingle();
  if (error) {
    throw error;
  }
  if (!event || (event.status !== "published" && event.status !== "ongoing")) {
    return 0;
  }

  const { data: devices, error: deviceError } = await admin
    .from("devices")
    .select("fcm_token, profile_id")
    .eq("is_active", true)
    .not("fcm_token", "is", null);
  if (deviceError) {
    throw deviceError;
  }

  const profileIds = [
    ...new Set((devices ?? []).map((row) => row.profile_id).filter(Boolean)),
  ];
  if (profileIds.length === 0) {
    return 0;
  }

  const { data: employees, error: employeeError } = await admin
    .from("profiles")
    .select("id")
    .eq("is_active", true)
    .eq("role", "employee")
    .in("id", profileIds);
  if (employeeError) {
    throw employeeError;
  }
  let allowed = new Set((employees ?? []).map((row) => row.id));

  if (event.is_open_to_all !== true) {
    const { data: participants, error: participantError } = await admin
      .from("event_participants")
      .select("profile_id")
      .eq("event_id", eventId);
    if (participantError) {
      throw participantError;
    }
    const participantIds = new Set(
      (participants ?? []).map((row) => row.profile_id),
    );
    allowed = new Set([...allowed].filter((id) => participantIds.has(id)));
  }

  const title = updated ? "Event updated" : "New event published";
  const body = updated
    ? `${event.name} was updated. Open PEAM for the latest schedule and venue.`
    : `${event.name} is scheduled at ${event.venue}.`;
  const notificationId = updated
    ? `event-updated-${event.id}`
    : `event-published-${event.id}`;

  return sendToTokens(
    accessToken,
    projectId,
    uniqueTokens(
      (devices ?? []).filter((row) => allowed.has(row.profile_id)),
    ),
    title,
    body,
    {
      kind: "eventPublished",
      event_id: event.id,
      notification_id: notificationId,
    },
  );
}

async function notifyDeviceChange(
  admin: ReturnType<typeof serviceClient>,
  accessToken: string,
  projectId: string,
  requestId: string,
): Promise<number> {
  if (!requestId) {
    return 0;
  }
  const { data: request, error } = await admin
    .from("device_change_requests")
    .select("id, profile_id, status")
    .eq("id", requestId)
    .maybeSingle();
  if (error) {
    throw error;
  }
  if (
    !request ||
    (request.status !== "approved" && request.status !== "rejected")
  ) {
    return 0;
  }

  const { data: devices, error: deviceError } = await admin
    .from("devices")
    .select("fcm_token")
    .eq("profile_id", request.profile_id)
    .not("fcm_token", "is", null);
  if (deviceError) {
    throw deviceError;
  }

  const approved = request.status === "approved";
  return sendToTokens(
    accessToken,
    projectId,
    uniqueTokens(devices ?? []),
    approved
      ? "Device-change request approved"
      : "Device-change request not approved",
    approved
      ? "PHRMO approved your request. You can use the new phone for attendance after you sign in."
      : "PHRMO did not approve using a new phone.",
    {
      kind: "deviceChangeUpdate",
      notification_id: `device-change-${request.id}-${request.status}`,
    },
  );
}

function uniqueTokens(rows: Array<{ fcm_token?: string | null }>): string[] {
  return [
    ...new Set(
      rows
        .map((row) => row.fcm_token?.trim())
        .filter((token): token is string => Boolean(token)),
    ),
  ];
}
