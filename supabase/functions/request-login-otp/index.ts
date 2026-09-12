import {
  corsHeaders,
  describeOtpSendError,
  findActiveEmployee,
  json,
  maskEmail,
  normalizeEmployeeNumber,
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
    const employeeNumber = normalizeEmployeeNumber(body.employee_number);
    if (!employeeNumber) {
      return json({ found: false });
    }

    const admin = serviceClient();
    const profile = await findActiveEmployee(admin, employeeNumber);
    const email = typeof profile?.email === "string" ? profile.email.trim() : "";
    if (!profile || !email.includes("@")) {
      return json({ found: false });
    }

    const { error } = await admin.auth.signInWithOtp({
      email,
      options: { shouldCreateUser: false },
    });
    if (error) {
      console.error("signInWithOtp", error);
      return json({ error: describeOtpSendError(error) }, 400);
    }

    return json({
      found: true,
      employee_number: profile.employee_number,
      masked_email: maskEmail(email),
    });
  } catch (error) {
    console.error(error);
    return json({ error: "We could not email your verification code. Try again in a moment." }, 500);
  }
});
