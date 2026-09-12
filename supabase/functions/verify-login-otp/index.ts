import {
  corsHeaders,
  employeeFromProfile,
  findActiveEmployee,
  json,
  normalizeEmployeeNumber,
  serviceClient,
  signDeviceChangeTicket,
  userClient,
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
    const employeeNumber = normalizeEmployeeNumber(body.employee_number);
    const token = typeof body.token === "string" ? body.token.trim() : "";
    const deviceUid = typeof body.device_uid === "string"
      ? body.device_uid.trim()
      : "";
    const deviceName = typeof body.device_name === "string"
      ? body.device_name
      : "This device";
    const platform = body.platform === "ios" ? "ios" : "android";

    if (!employeeNumber || !token || !deviceUid) {
      return json({ error: "Employee ID, code, and device are required." }, 400);
    }

    const admin = serviceClient();
    const profile = await findActiveEmployee(admin, employeeNumber);
    const email = typeof profile?.email === "string" ? profile.email.trim() : "";
    if (!profile || !email.includes("@")) {
      return json({
        error: "This Employee ID is not on file. Ask HRMDO to create your account.",
      }, 404);
    }

    const { data: otp, error: otpError } = await admin.auth.verifyOtp({
      email,
      token,
      type: "email",
    });
    if (otpError || !otp.session) {
      return json({
        error: "That code is incorrect or has expired. Try again.",
      }, 401);
    }

    const { data: bound, error: bindError } = await userClient(
      otp.session.access_token,
    ).rpc("bind_employee_device", {
      p_device_uid: deviceUid,
      p_device_name: deviceName,
      p_platform: platform,
    });

    if (bindError?.message?.includes("DEVICE_BOUND_ELSEWHERE")) {
      return json({
        authenticated: false,
        code: "device_bound_elsewhere",
        change_ticket: await signDeviceChangeTicket({
          profile_id: String(profile.id),
          device_uid: deviceUid,
          device_name: deviceName,
          platform,
        }),
        message:
          "This account is already bound to another phone. Submit a device-change request for HR approval.",
      });
    }
    if (bindError) {
      console.error("bind_employee_device", bindError);
      return json({ error: "Could not bind this phone." }, 400);
    }

    const device = bound as { device_uid?: string; device_name?: string } | null;
    return json({
      authenticated: true,
      access_token: otp.session.access_token,
      refresh_token: otp.session.refresh_token,
      employee: employeeFromProfile(
        profile as Record<string, unknown>,
        device?.device_uid ?? deviceUid,
        device?.device_name ?? deviceName,
      ),
    });
  } catch (error) {
    console.error(error);
    return json({ error: "Could not verify the email code." }, 500);
  }
});
