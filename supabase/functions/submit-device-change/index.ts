import {
  corsHeaders,
  json,
  readDeviceChangeTicket,
  serviceClient,
} from "../_shared/auth.ts";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const body = await request.json();
    const ticket = typeof body.ticket === "string" ? body.ticket.trim() : "";
    const reason = typeof body.reason === "string" && body.reason.trim()
      ? body.reason.trim()
      : "I need to use a new phone for attendance.";

    const claims = await readDeviceChangeTicket(ticket);
    if (!claims) {
      return json({
        error: "Verify the email code again, then submit the device-change request.",
      }, 401);
    }

    const admin = serviceClient();
    const { data: active } = await admin
      .from("devices")
      .select("id")
      .eq("profile_id", claims.profile_id)
      .eq("is_active", true)
      .maybeSingle();

    const { error } = await admin.from("device_change_requests").insert({
      profile_id: claims.profile_id,
      current_device_id: active?.id ?? null,
      new_device_uid: claims.device_uid,
      new_device_name: claims.device_name,
      new_platform: claims.platform,
      reason,
      status: "pending",
    });
    if (error) {
      if (error.code === "23505") {
        return json({
          error: "A device-change request is already pending for this account.",
        }, 409);
      }
      console.error(error);
      return json({ error: "Could not submit the device-change request." }, 400);
    }

    return json({ submitted: true });
  } catch (error) {
    console.error(error);
    return json({ error: "Could not submit the device-change request." }, 500);
  }
});
