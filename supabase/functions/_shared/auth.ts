import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

export function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function describeOtpSendError(error: { message?: string } | null): string {
  const message = (error?.message ?? "").toLowerCase();
  if (
    message.includes("rate limit") ||
    message.includes("too many") ||
    message.includes("after")
  ) {
    return "A code was already sent. Wait a minute, then try again.";
  }
  if (
    message.includes("signups not allowed") ||
    message.includes("user not found")
  ) {
    return "This Employee ID is not ready for sign-in. Ask HRMDO to create your account.";
  }
  if (
    message.includes("not authorized") ||
    message.includes("not authorised") ||
    message.includes("smtp") ||
    message.includes("sending") ||
    message.includes("mail") ||
    message.includes("deliver")
  ) {
    return "We could not email your verification code. Check your work email, then try again.";
  }
  return "We could not email your verification code. Try again in a moment.";
}

export function serviceClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) {
    throw new Error("Supabase service credentials are not configured");
  }
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export function maskEmail(email: string): string {
  const trimmed = email.trim();
  const at = trimmed.indexOf("@");
  if (at <= 0 || at === trimmed.length - 1) {
    return "••••@••••";
  }
  const local = trimmed.slice(0, at);
  const domain = trimmed.slice(at + 1);
  if (local.length === 1) {
    return `${local}••••@${domain}`;
  }
  const hidden = local.length <= 2 ? 2 : local.length - 2;
  return `${local[0]}${"•".repeat(hidden)}${local[local.length - 1]}@${domain}`;
}

export function userClient(accessToken: string): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon) {
    throw new Error("Supabase anon credentials are not configured");
  }
  return createClient(url, anon, {
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export function normalizeEmployeeNumber(value: unknown): string {
  if (typeof value !== "string") {
    return "";
  }
  const trimmed = value.trim();
  if (!trimmed || /[%_]/.test(trimmed)) {
    return "";
  }
  return trimmed;
}

async function hmacHex(secret: string, value: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(signature))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export async function signDeviceChangeTicket(payload: {
  profile_id: string;
  device_uid: string;
  device_name: string;
  platform: string;
}): Promise<string> {
  const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!secret) {
    throw new Error("Supabase service credentials are not configured");
  }
  const body = btoa(
    JSON.stringify({ ...payload, exp: Date.now() + 15 * 60 * 1000 }),
  );
  return `${body}.${await hmacHex(secret, body)}`;
}

export async function readDeviceChangeTicket(ticket: string): Promise<{
  profile_id: string;
  device_uid: string;
  device_name: string;
  platform: string;
} | null> {
  const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!secret) {
    return null;
  }
  const dot = ticket.lastIndexOf(".");
  if (dot <= 0) {
    return null;
  }
  const body = ticket.slice(0, dot);
  const signature = ticket.slice(dot + 1);
  if (signature !== await hmacHex(secret, body)) {
    return null;
  }
  try {
    const parsed = JSON.parse(atob(body)) as {
      profile_id?: string;
      device_uid?: string;
      device_name?: string;
      platform?: string;
      exp?: number;
    };
    if (!parsed.profile_id || !parsed.device_uid || !parsed.exp) {
      return null;
    }
    if (parsed.exp < Date.now()) {
      return null;
    }
    return {
      profile_id: parsed.profile_id,
      device_uid: parsed.device_uid,
      device_name: parsed.device_name ?? "This device",
      platform: parsed.platform === "ios" ? "ios" : "android",
    };
  } catch {
    return null;
  }
}

export async function findActiveEmployee(
  admin: SupabaseClient,
  employeeNumber: string,
) {
  const { data, error } = await admin
    .from("profiles")
    .select(
      "id, employee_number, full_name, email, phone, is_active, role, department_id, departments(name, code)",
    )
    .eq("employee_number", employeeNumber)
    .eq("is_active", true)
    .maybeSingle();

  if (error) {
    throw error;
  }
  return data;
}

export function employeeFromProfile(
  profile: Record<string, unknown>,
  deviceUid: string | null,
  deviceName: string | null,
) {
  const department = profile.departments as
    | { name?: string; code?: string }
    | null
    | undefined;
  return {
    employee_number: profile.employee_number,
    full_name: profile.full_name,
    email: profile.email,
    phone: profile.phone,
    department_name: department?.name ?? "Unassigned",
    department_code: department?.code ?? "—",
    device_uid: deviceUid,
    device_name: deviceName ?? "This device",
  };
}
